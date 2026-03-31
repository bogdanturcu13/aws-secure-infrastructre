# Clave gestionada por el cliente (CMK) para cifrar en reposo:
# volúmenes EBS, sistema de archivos EFS y logs de CloudTrail.
locals {
  trail_name = "${var.project_name}-trail"
}

resource "aws_kms_key" "main" {
  description             = "CMK de ${var.project_name}: EBS, EFS y CloudTrail"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # La cuenta (y por delegación IAM) administra la clave
        Sid       = "AdministracionCuenta"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        # CloudTrail cifra sus ficheros de log con esta clave
        Sid       = "PermitirCloudTrailCifrar"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "kms:GenerateDataKey*"
        Resource  = "*"
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:aws:cloudtrail:${var.region}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"
          }
          StringLike = {
            "kms:EncryptionContext:aws:cloudtrail:arn" = "arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"
          }
        }
      },
      {
        Sid       = "PermitirCloudTrailDescribeKey"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "kms:DescribeKey"
        Resource  = "*"
      }
    ]
  })

  tags = { Name = "${var.project_name}-cmk" }
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}"
  target_key_id = aws_kms_key.main.key_id
}
