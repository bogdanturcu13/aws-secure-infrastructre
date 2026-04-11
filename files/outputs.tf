# ============================================================================
# OUTPUTS PRINCIPALES
# ============================================================================

output "vpc_id" {
  description = "ID de la VPC creada"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block de la VPC"
  value       = aws_vpc.main.cidr_block
}

# ============================================================================
# OUTPUTS DE SUBREDES
# ============================================================================

output "public_subnet_id" {
  description = "ID de la subred pública"
  value       = aws_subnet.public.id
}

output "public_subnet_cidr" {
  description = "CIDR de la subred pública"
  value       = aws_subnet.public.cidr_block
}

output "private_subnet_id" {
  description = "ID de la subred privada"
  value       = aws_subnet.private.id
}

output "private_subnet_cidr" {
  description = "CIDR de la subred privada"
  value       = aws_subnet.private.cidr_block
}

# ============================================================================
# OUTPUTS DE SEGURIDAD
# ============================================================================

output "nat_security_group_id" {
  description = "ID del Security Group de NAT"
  value       = aws_security_group.nat.id
}

output "private_server_security_group_id" {
  description = "ID del Security Group del servidor privado"
  value       = aws_security_group.private_server.id
}

# ============================================================================
# OUTPUTS DE INSTANCIAS
# ============================================================================

output "nat_instance_details" {
  description = "Detalles de la instancia NAT"
  value = {
    instance_id    = aws_instance.nat.id
    private_ip     = aws_instance.nat.private_ip
    public_ip      = aws_eip.nat.public_ip
    ami_id         = aws_instance.nat.ami
    instance_type  = aws_instance.nat.instance_type
  }
}

output "private_server_details" {
  description = "Detalles del servidor privado"
  value = {
    instance_id              = aws_instance.private_server.id
    private_ip               = aws_instance.private_server.private_ip
    ami_id                   = aws_instance.private_server.ami
    instance_type            = aws_instance.private_server.instance_type
    availability_zone        = aws_instance.private_server.availability_zone
    iam_instance_profile     = aws_instance.private_server.iam_instance_profile
  }
}

# ============================================================================
# OUTPUTS DE ACCESO
# ============================================================================

output "ssm_access_command" {
  description = "Comando para acceder a la instancia privada mediante SSM"
  value       = "aws ssm start-session --target ${aws_instance.private_server.id} --region ${data.aws_caller_identity.current.region}"
}

output "ssm_access_with_port_forwarding" {
  description = "Comando SSM con port forwarding (si fuera necesario)"
  value       = "aws ssm start-session --target ${aws_instance.private_server.id} --document-name AWS-StartPortForwardingSession --parameters 'localPortNumber=3306,portNumber=3306' --region ${data.aws_caller_identity.current.region}"
}

# ============================================================================
# OUTPUTS DE AUDITORÍA Y SEGURIDAD
# ============================================================================

output "cloudtrail_configuration" {
  description = "Configuración de CloudTrail"
  value = {
    trail_name      = try(aws_cloudtrail.main[0].name, "CloudTrail deshabilitado")
    s3_bucket       = aws_s3_bucket.cloudtrail.id
    log_group       = aws_cloudwatch_log_group.cloudtrail.name
    enabled         = var.enable_cloudtrail
    multi_region    = try(aws_cloudtrail.main[0].is_multi_region_trail, false)
  }
}

output "kms_configuration" {
  description = "Configuración de KMS para cifrado EBS"
  value = {
    key_id           = aws_kms_key.ebs.id
    key_arn          = aws_kms_key.ebs.arn
    alias            = aws_kms_alias.ebs.name
    rotation_enabled = aws_kms_key.ebs.enable_key_rotation
  }
}

output "iam_roles" {
  description = "Roles IAM creados"
  value = {
    private_server_role = aws_iam_role.private_server.arn
    cloudtrail_role     = aws_iam_role.cloudtrail.arn
  }
}

# ============================================================================
# OUTPUTS DE LOGGING
# ============================================================================

output "cloudwatch_log_groups" {
  description = "CloudWatch Log Groups creados"
  value = {
    ssm_sessions  = aws_cloudwatch_log_group.private_ssm_logs.name
    cloudtrail    = aws_cloudwatch_log_group.cloudtrail.name
    vpc_flow_logs = try(aws_cloudwatch_log_group.vpc_flow_logs[0].name, "Deshabilitado")
  }
}

# ============================================================================
# RESUMEN DE CONFIGURACIÓN
# ============================================================================

output "deployment_summary" {
  description = "Resumen de la configuración desplegada"
  value = <<-EOT
    ╔═══════════════════════════════════════════════════════════════════════╗
    ║          DESPLIEGUE SEGURO DE INFRAESTRUCTURA AWS - RESUMEN          ║
    ╚═══════════════════════════════════════════════════════════════════════╝
    
    🏗️  ARQUITECTURA:
        • Región: ${data.aws_caller_identity.current.region}
        • VPC CIDR: ${aws_vpc.main.cidr_block}
        • Subred Pública: ${aws_subnet.public.cidr_block}
        • Subred Privada: ${aws_subnet.private.cidr_block}
    
    🔐 SEGURIDAD:
        • Security Groups: Configurados con acceso mínimo
        • KMS: CMK habilitada para cifrado EBS
        • CloudTrail: Auditoría integral habilitada
        • VPC Flow Logs: ${var.enable_vpc_flow_logs ? "Habilitados" : "Deshabilitados"}
    
    🖥️  INSTANCIAS:
        • NAT Instance: ${aws_instance.nat.instance_type} (${aws_instance.nat.id})
        • Private Server: ${aws_instance.private_server.instance_type} (${aws_instance.private_server.id})
    
    🔑 ACCESO:
        • Método: AWS Session Manager (SSM)
        • Puerto SSH: Cerrado ❌
        • IAM-based: Habilitado ✅
    
    📊 LOGGING Y AUDITORÍA:
        • CloudTrail Logs: ${aws_s3_bucket.cloudtrail.id}
        • SSM Session Logs: ${aws_cloudwatch_log_group.private_ssm_logs.name}
        • CloudTrail Log Group: ${aws_cloudwatch_log_group.cloudtrail.name}
    
    💾 ALMACENAMIENTO:
        • EBS Volumes: Cifrados con KMS ✅
        • S3 CloudTrail: Versionado y encriptado ✅
    
    ═══════════════════════════════════════════════════════════════════════
    
    📝 PRÓXIMOS PASOS:
    
    1. Verificar que las instancias están en estado "running"
    2. Acceder a la instancia privada:
       ${aws_instance.private_server.id} mediante SSM (arriba)
    3. Verificar logs en CloudTrail
    4. Revisar las métricas de seguridad en CloudWatch
    
    ═══════════════════════════════════════════════════════════════════════
  EOT
}
