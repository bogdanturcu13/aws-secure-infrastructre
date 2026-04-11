# ============================================================================
# AWS KMS - CUSTOMER MANAGED KEY PARA EBS
# ============================================================================

# Crear la clave KMS personalizada para cifrar volúmenes EBS
resource "aws_kms_key" "ebs" {
  description             = "Customer-managed key para cifrado de volúmenes EBS del proyecto ${var.project_name}"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-ebs-key"
  }
}

# Alias para la clave KMS (más fácil de identificar)
resource "aws_kms_alias" "ebs" {
  name          = "alias/${var.project_name}-ebs"
  target_key_id = aws_kms_key.ebs.key_id
}

# Política de la clave KMS para permitir que los servicios de AWS la utilicen
resource "aws_kms_key_policy" "ebs" {
  key_id = aws_kms_key.ebs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Permitir que AWS root pueda gestionar la clave
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      # Permitir que EC2 use la clave para cifrado de EBS
      {
        Sid    = "Allow EC2 to use the key for EBS"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      # Permitir que CloudTrail use la clave si es necesario
      {
        Sid    = "Allow CloudTrail to use the key"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:DecryptDataKey"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "kms:EncryptionContext:aws:cloudtrail:arn" = "arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"
          }
        }
      },
      # Permitir que CloudWatch Logs use la clave
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_caller_identity.current.region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_caller_identity.current.region}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      },
      # Permitir que la instancia privada descifre volúmenes
      {
        Sid    = "Allow EC2 instance to decrypt volumes"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.private_server.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# SALIDAS PARA KMS
# ============================================================================

output "kms_key_id" {
  description = "ID de la clave KMS para EBS"
  value       = aws_kms_key.ebs.id
}

output "kms_key_arn" {
  description = "ARN de la clave KMS para EBS"
  value       = aws_kms_key.ebs.arn
}

output "kms_key_alias" {
  description = "Alias de la clave KMS"
  value       = aws_kms_alias.ebs.name
}
