# ============================================================================
# GRUPOS DE SEGURIDAD
# ============================================================================

# Security Group para la instancia NAT
resource "aws_security_group" "nat" {
  name        = "${var.project_name}-nat-sg"
  description = "Security group para la instancia NAT. Permite tráfico desde la subred privada hacia internet"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-nat-sg"
  }
}

# Regla de entrada: Tráfico HTTP desde la subred privada
resource "aws_vpc_security_group_ingress_rule" "nat_http_from_private" {
  security_group_id = aws_security_group.nat.id
  description       = "HTTP desde subred privada"

  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = var.private_subnet_cidr
}

# Regla de entrada: Tráfico HTTPS desde la subred privada
resource "aws_vpc_security_group_ingress_rule" "nat_https_from_private" {
  security_group_id = aws_security_group.nat.id
  description       = "HTTPS desde subred privada"

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = var.private_subnet_cidr
}

# Regla de salida: Acceso a internet (HTTP)
resource "aws_vpc_security_group_egress_rule" "nat_http_to_internet" {
  security_group_id = aws_security_group.nat.id
  description       = "HTTP hacia internet"

  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

# Regla de salida: Acceso a internet (HTTPS)
resource "aws_vpc_security_group_egress_rule" "nat_https_to_internet" {
  security_group_id = aws_security_group.nat.id
  description       = "HTTPS hacia internet"

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

# Regla de salida: DNS (necesario para resolver nombres)
resource "aws_vpc_security_group_egress_rule" "nat_dns" {
  security_group_id = aws_security_group.nat.id
  description       = "DNS hacia internet"

  from_port   = 53
  to_port     = 53
  ip_protocol = "udp"
  cidr_ipv4   = "0.0.0.0/0"
}

# ============================================================================
# Security Group para el servidor privado Ubuntu
# ============================================================================

resource "aws_security_group" "private_server" {
  name        = "${var.project_name}-private-server-sg"
  description = "Security group para el servidor privado. Zero inbound rules. SSM + NAT para salida"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-private-server-sg"
  }
}

# Regla de salida: HTTPS hacia NAT (para comunicación con AWS Systems Manager)
resource "aws_vpc_security_group_egress_rule" "private_https_to_nat" {
  security_group_id = aws_security_group.private_server.id
  description       = "HTTPS hacia NAT (SSM y actualizaciones)"

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = var.public_subnet_cidr
}

# Regla de salida: HTTP hacia NAT (actualizaciones de paquetes)
resource "aws_vpc_security_group_egress_rule" "private_http_to_nat" {
  security_group_id = aws_security_group.private_server.id
  description       = "HTTP hacia NAT (actualizaciones)"

  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = var.public_subnet_cidr
}

# Regla de salida: DNS hacia NAT
resource "aws_vpc_security_group_egress_rule" "private_dns_to_nat" {
  security_group_id = aws_security_group.private_server.id
  description       = "DNS hacia NAT"

  from_port   = 53
  to_port     = 53
  ip_protocol = "udp"
  cidr_ipv4   = var.public_subnet_cidr
}

# Nota: No hay reglas de entrada (zero inbound rules)
# El acceso se realiza únicamente mediante AWS Session Manager (SSM)
