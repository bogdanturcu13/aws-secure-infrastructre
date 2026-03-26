variable "region" {
  description = "Región de AWS donde se despliega la infraestructura"
  type        = string
  default     = "eu-west-2" # Londres
}

variable "project_name" {
  description = "Nombre del proyecto para etiquetar los recursos"
  type        = string
  default     = "secure-cloud-aws"
}

variable "vpc_cidr" {
  description = "Rango de IPs para la VPC"
  type        = string
  default     = "10.0.0.0/24"
}

variable "public_subnet_cidr" {
  description = "CIDR para la subred pública"
  type        = string
  default     = "10.0.0.0/25"
}

variable "private_subnet_cidr" {
  description = "CIDR para la subred privada"
  type        = string
  default     = "10.0.0.128/25"
}

variable "instance_type" {
  description = "Tipo de instancia para nuestros servidores"
  type        = string
  default     = "t2.micro"
}

variable "owner" {
  description = "Autor del proyecto"
  type        = string
  default     = "Bogdan Turcu"
}

variable "nat_volume_size" {
  description = "Tamaño (GiB) del volumen raíz de la instancia NAT"
  type        = number
  default     = 20
}

variable "private_volume_size" {
  description = "Tamaño (GiB) del volumen raíz de la instancia privada"
  type        = number
  default     = 15
}

variable "kms_deletion_window" {
  description = "Días de espera antes de borrar definitivamente la clave KMS (7-30)"
  type        = number
  default     = 7
}

variable "cloudtrail_retention_days" {
  description = "Días que se conservan los logs de CloudTrail en S3"
  type        = number
  default     = 90
}
