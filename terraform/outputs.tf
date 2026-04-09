output "nat_public_ip" {
  description = "IP pública (elástica) de la instancia NAT"
  value       = aws_eip.nat.public_ip
}

output "nat_instance_id" {
  description = "ID de la instancia NAT"
  value       = aws_instance.nat_instance.id
}

output "private_instance_id" {
  description = "ID de la instancia privada"
  value       = aws_instance.private_instance.id
}

output "ssm_connect_command" {
  description = "Comando para conectarse al servidor privado por SSM (sin SSH)"
  value       = "aws ssm start-session --target ${aws_instance.private_instance.id} --region ${var.region}"
}

output "kms_key_arn" {
  description = "ARN de la CMK usada para EBS, EFS y CloudTrail"
  value       = aws_kms_key.main.arn
}

output "efs_id" {
  description = "ID del sistema de archivos EFS (montado en /mnt/efs)"
  value       = aws_efs_file_system.main.id
}

output "cloudtrail_bucket" {
  description = "Bucket S3 con los logs de CloudTrail"
  value       = aws_s3_bucket.cloudtrail.id
}
