# ============================================================================
# INTERFAZ DE RED PARA NAT
# ============================================================================

resource "aws_network_interface" "nat" {
  subnet_id           = aws_subnet.public.id
  security_groups     = [aws_security_group.nat.id]
  source_dest_check   = false  # CRÍTICO: Permitir reenvío de paquetes IP

  tags = {
    Name = "${var.project_name}-nat-eni"
  }
}

# IP Elástica para NAT (necesaria para tráfico saliente desde instancia privada)
resource "aws_eip" "nat" {
  domain            = "vpc"
  network_interface = aws_network_interface.nat.id
  depends_on        = [aws_internet_gateway.main]

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

# ============================================================================
# INSTANCIA NAT (Ubuntu)
# ============================================================================

resource "aws_instance" "nat" {
  ami                = data.aws_ami.ubuntu.id
  instance_type     = var.nat_instance_type
  monitoring        = var.enable_nat_metrics

  # Usar la interfaz de red previamente creada
  network_interface {
    network_interface_id = aws_network_interface.nat.id
    device_index        = 0
  }

  # User data para habilitar NAT forwarding
  user_data = base64encode(templatefile("${path.module}/nat_setup.sh", {
    PRIVATE_SUBNET_CIDR = var.private_subnet_cidr
  }))

  # EBS Volume con cifrado KMS
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = aws_kms_key.ebs.arn

    tags = {
      Name = "${var.project_name}-nat-root-volume"
    }
  }

  # Tags
  tags = {
    Name = "${var.project_name}-nat"
    Role = "NAT"
  }

  depends_on = [aws_internet_gateway.main]
}

# ============================================================================
# INSTANCIA PRIVADA (Ubuntu)
# ============================================================================

resource "aws_instance" "private_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.private_instance_type
  
  # Usar Instance Profile para acceso a SSM y KMS
  iam_instance_profile = aws_iam_instance_profile.private_server.name

  # Subred privada
  subnet_id              = aws_subnet.private.id
  security_groups        = [aws_security_group.private_server.id]
  associate_public_ip_address = false

  # User data para configuración inicial
  user_data = base64encode(templatefile("${path.module}/private_setup.sh", {
    PROJECT_NAME = var.project_name
    LOG_GROUP    = aws_cloudwatch_log_group.private_ssm_logs.name
  }))

  # EBS Volume root con cifrado KMS
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = aws_kms_key.ebs.arn

    tags = {
      Name = "${var.project_name}-private-root-volume"
    }
  }

  # Volumen adicional para datos (opcional)
  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_type           = "gp3"
    volume_size           = 50
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = aws_kms_key.ebs.arn

    tags = {
      Name = "${var.project_name}-private-data-volume"
    }
  }

  # Habilitar monitoring detallado
  monitoring = true

  # Tags
  tags = {
    Name    = "${var.project_name}-private-server"
    Role    = "PrivateServer"
    Project = var.project_name
  }

  depends_on = [aws_instance.nat, aws_iam_instance_profile.private_server]
}

# ============================================================================
# CLOUDWATCH LOG GROUP PARA SSM SESSIONS
# ============================================================================

resource "aws_cloudwatch_log_group" "private_ssm_logs" {
  name              = "/aws/ssm/${var.project_name}"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-ssm-logs"
  }
}

# ============================================================================
# DOCUMENTO SSM PARA CONFIGURACIÓN DE SESIONES
# ============================================================================

resource "aws_ssm_document" "session_manager_prefs" {
  name            = "${var.project_name}-session-manager-prefs"
  document_type   = "Session"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Session Manager preferences para ${var.project_name}"
    sessionType    = "Standard_Stream"
    inputs = {
      s3BucketName               = ""
      s3EncryptionEnabled        = false
      cloudWatchLogGroupName     = aws_cloudwatch_log_group.private_ssm_logs.name
      cloudWatchEncryptionEnabled = true
      idleSessionTimeout         = "20"
      cloudWatchStreamingEnabled = var.ssm_session_recording_enabled
      kmsKeyId                   = aws_kms_key.ebs.id
    }
  })

  tags = {
    Name = "${var.project_name}-session-manager-prefs"
  }
}

# ============================================================================
# SALIDAS PARA INSTANCIAS
# ============================================================================

output "nat_instance_id" {
  description = "ID de la instancia NAT"
  value       = aws_instance.nat.id
}

output "nat_instance_public_ip" {
  description = "IP pública de la instancia NAT"
  value       = aws_eip.nat.public_ip
}

output "nat_instance_private_ip" {
  description = "IP privada de la instancia NAT"
  value       = aws_instance.nat.private_ip
}

output "private_server_instance_id" {
  description = "ID de la instancia privada"
  value       = aws_instance.private_server.id
}

output "private_server_private_ip" {
  description = "IP privada de la instancia privada"
  value       = aws_instance.private_server.private_ip
}

output "private_server_availability_zone" {
  description = "Zona de disponibilidad del servidor privado"
  value       = aws_instance.private_server.availability_zone
}

output "ssm_log_group" {
  description = "CloudWatch Log Group para sesiones SSM"
  value       = aws_cloudwatch_log_group.private_ssm_logs.name
}
