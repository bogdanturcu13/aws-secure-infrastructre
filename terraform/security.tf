# ---------------------------------------------------------------------------
# Grupos de seguridad
# Las reglas se definen como recursos independientes para poder referenciar
# unos grupos desde otros sin dependencias circulares.
# ---------------------------------------------------------------------------

# SG de la instancia pública (NAT)
resource "aws_security_group" "public_sg" {
  name        = "${var.project_name}-public-sg"
  description = "Instancia NAT: HTTP/HTTPS solo desde el servidor privado"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project_name}-public-sg" }
}

# SG de la instancia privada
resource "aws_security_group" "private_sg" {
  name        = "${var.project_name}-private-sg"
  description = "Servidor privado: sin entrada, salida HTTPS y NFS"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project_name}-private-sg" }
}

# SG del sistema de archivos EFS
resource "aws_security_group" "efs_sg" {
  name        = "${var.project_name}-efs-sg"
  description = "EFS: NFS solo desde el servidor privado"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project_name}-efs-sg" }
}

# --- NAT: entrada HTTP/HTTPS únicamente desde el servidor privado ---
resource "aws_vpc_security_group_ingress_rule" "nat_http_from_private" {
  security_group_id            = aws_security_group.public_sg.id
  referenced_security_group_id = aws_security_group.private_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  description                  = "HTTP desde el servidor privado"
}

resource "aws_vpc_security_group_ingress_rule" "nat_https_from_private" {
  security_group_id            = aws_security_group.public_sg.id
  referenced_security_group_id = aws_security_group.private_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS desde el servidor privado"
}

# --- NAT: salida libre a Internet (es su función de puente) ---
resource "aws_vpc_security_group_egress_rule" "nat_all_out" {
  security_group_id = aws_security_group.public_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Salida a Internet"
}

# --- Servidor privado: cero reglas de entrada (acceso solo por SSM) ---

# Salida HTTPS (SSM, actualizaciones de paquetes) hacia la NAT
resource "aws_vpc_security_group_egress_rule" "private_https_out" {
  security_group_id = aws_security_group.private_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS saliente via NAT"
}

# Salida NFS hacia EFS
resource "aws_vpc_security_group_egress_rule" "private_nfs_out" {
  security_group_id            = aws_security_group.private_sg.id
  referenced_security_group_id = aws_security_group.efs_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  description                  = "NFS hacia EFS"
}

# --- EFS: NFS (2049) solo desde el servidor privado ---
resource "aws_vpc_security_group_ingress_rule" "efs_nfs_from_private" {
  security_group_id            = aws_security_group.efs_sg.id
  referenced_security_group_id = aws_security_group.private_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  description                  = "NFS desde el servidor privado"
}

# ---------------------------------------------------------------------------
# Rol IAM para SSM (permite que AWS gestione la instancia sin SSH)
# ---------------------------------------------------------------------------
resource "aws_iam_role" "ssm_role" {
  name = "${var.project_name}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Política oficial de Amazon para SSM
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Perfil de instancia (lo que realmente se asocia a la EC2)
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${var.project_name}-ssm-profile"
  role = aws_iam_role.ssm_role.name
}
