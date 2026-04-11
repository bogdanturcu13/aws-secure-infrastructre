variable "aws_region" {
  description = "Región de AWS donde se desplegará la infraestructura"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Nombre del proyecto para tags y nombrado de recursos"
  type        = string
  default     = "secure-cloud-arch"
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
  default     = "production"
  
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "El entorno debe ser development, staging o production."
  }
}

variable "vpc_cidr" {
  description = "CIDR block para la VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr debe ser un CIDR válido."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR block para la subred pública"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block para la subred privada"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Zona de disponibilidad para los recursos"
  type        = string
  default     = "eu-west-1a"
}

variable "nat_instance_type" {
  description = "Tipo de instancia para el servidor NAT"
  type        = string
  default     = "t3.micro"
  
  validation {
    condition     = can(regex("^t[2-4]\\.(nano|micro|small|medium)", var.nat_instance_type))
    error_message = "Se recomienda usar instancias t3/t4 cost-effective para NAT."
  }
}

variable "private_instance_type" {
  description = "Tipo de instancia para el servidor privado"
  type        = string
  default     = "t3.micro"
}

variable "enable_nat_metrics" {
  description = "Habilitar CloudWatch detailed monitoring para NAT"
  type        = bool
  default     = false
}

variable "kms_key_deletion_window" {
  description = "Ventana de días para eliminar la clave KMS (7-30 días)"
  type        = number
  default     = 7
  
  validation {
    condition     = var.kms_key_deletion_window >= 7 && var.kms_key_deletion_window <= 30
    error_message = "La ventana de eliminación debe estar entre 7 y 30 días."
  }
}

variable "enable_cloudtrail" {
  description = "Habilitar CloudTrail para auditoría"
  type        = bool
  default     = true
}

variable "cloudtrail_s3_retention_days" {
  description = "Días de retención de logs de CloudTrail en S3"
  type        = number
  default     = 90
}

variable "ssm_session_recording_enabled" {
  description = "Habilitar grabación de sesiones SSM"
  type        = bool
  default     = true
}

variable "enable_vpc_flow_logs" {
  description = "Habilitar VPC Flow Logs para análisis de tráfico"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags adicionales para todos los recursos"
  type        = map(string)
  default = {
    Owner       = "CloudTeam"
    CostCenter  = "Engineering"
  }
}
