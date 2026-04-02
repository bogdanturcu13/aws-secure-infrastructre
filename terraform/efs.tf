# Almacenamiento persistente independiente del ciclo de vida de la instancia
resource "aws_efs_file_system" "main" {
  encrypted  = true
  kms_key_id = aws_kms_key.main.arn

  tags = { Name = "${var.project_name}-efs" }
}

# Punto de montaje en la subred privada (acceso solo desde el SG del servidor)
resource "aws_efs_mount_target" "private" {
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = aws_subnet.private.id
  security_groups = [aws_security_group.efs_sg.id]
}
