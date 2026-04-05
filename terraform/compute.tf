# Última AMI de Amazon Linux 2023 (se resuelve de forma dinámica)
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Instancia pública (NAT)
resource "aws_instance" "nat_instance" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.public_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name # Administración por SSM, sin SSH
  associate_public_ip_address = true
  source_dest_check           = false # PERMITE QUE REENVÍE TRÁFICO DE OTROS

  # IP forwarding + masquerading de la subred privada
  user_data = replace(templatefile("${path.module}/scripts/nat_setup.sh.tftpl", {
    private_subnet_cidr = var.private_subnet_cidr
  }), "\r\n", "\n") # normaliza saltos de línea de Windows
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required" # IMDSv2
  }

  root_block_device {
    volume_size = var.nat_volume_size
    volume_type = "gp3"
    encrypted   = true
    kms_key_id  = aws_kms_key.main.arn
  }

  # Evita que una AMI nueva fuerce a recrear la instancia
  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "${var.project_name}-nat-instance"
  }
}

# IP elástica: la NAT conserva su IP pública si se para y se arranca
resource "aws_eip" "nat" {
  domain     = "vpc"
  instance   = aws_instance.nat_instance.id
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

# Instancia privada (sistema crítico, sin IP pública ni SSH)
resource "aws_instance" "private_instance" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name # PERMITE CONEXIÓN POR SSM

  # Instala el cliente EFS y monta el sistema de archivos en /mnt/efs
  user_data = replace(templatefile("${path.module}/scripts/private_setup.sh.tftpl", {
    efs_id = aws_efs_file_system.main.id
  }), "\r\n", "\n")
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required" # IMDSv2
  }

  # Volumen raíz cifrado con la CMK
  root_block_device {
    volume_size = var.private_volume_size
    volume_type = "gp3"
    encrypted   = true
    kms_key_id  = aws_kms_key.main.arn
  }

  # Necesita la ruta por la NAT y el punto de montaje EFS antes de arrancar
  depends_on = [
    aws_route.private_nat,
    aws_efs_mount_target.private,
  ]

  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "${var.project_name}-private-instance"
  }
}
