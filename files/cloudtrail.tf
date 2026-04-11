# ============================================================================
# S3 BUCKET PARA CLOUDTRAIL LOGS
# ============================================================================

# Bucket S3 para almacenar los logs de CloudTrail
resource "aws_s3_bucket" "cloudtrail" {
  bucket = "${var.project_name}-cloudtrail-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-cloudtrail-logs"
  }
}

# Bloquear acceso público al bucket
resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versionado habilitado para auditoría
resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encriptación en reposo usando KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.ebs.arn
    }
    bucket_key_enabled = true
  }
}

# Política de bucket para permitir que CloudTrail escriba logs
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Obtener ACL del bucket
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
      },
      # Escribir logs en el bucket
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      # Denegar acceso no encriptado
      {
        Sid    = "DenyUnencryptedObjectUploads"
        Effect = "Deny"
        Principal = "*"
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })
}

# Ciclo de vida: archivar después de 30 días, eliminar después de 90 días
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "ArchiveAndDeleteCloudTrailLogs"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = var.cloudtrail_s3_retention_days
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.cloudtrail_s3_retention_days
    }
  }
}

# ============================================================================
# IAM ROLE PARA CLOUDTRAIL
# ============================================================================

resource "aws_iam_role" "cloudtrail" {
  name = "${var.project_name}-cloudtrail-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-cloudtrail-role"
  }
}

# Política para que CloudTrail pueda escribir en CloudWatch Logs
resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  name   = "${var.project_name}-cloudtrail-cloudwatch-policy"
  role   = aws_iam_role.cloudtrail.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailCreateLogStream"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
      }
    ]
  })
}

# ============================================================================
# CLOUDWATCH LOG GROUP PARA CLOUDTRAIL
# ============================================================================

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.project_name}"
  retention_in_days = var.cloudtrail_s3_retention_days

  tags = {
    Name = "${var.project_name}-cloudtrail-logs"
  }
}

# ============================================================================
# CLOUDTRAIL TRAIL
# ============================================================================

resource "aws_cloudtrail" "main" {
  count                      = var.enable_cloudtrail ? 1 : 0
  name                       = "${var.project_name}-trail"
  s3_bucket_name             = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail      = true
  enable_log_file_validation = true
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail.arn
  kms_key_id                 = aws_kms_key.ebs.arn
  depends_on                 = [aws_s3_bucket_policy.cloudtrail]

  # Registrar eventos de datos para S3 y Lambda (opcional pero recomendado)
  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::*/"]
    }

    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda:*:*:function/*"]
    }
  }

  tags = {
    Name = "${var.project_name}-trail"
  }
}

# ============================================================================
# CLOUDWATCH METRIC ALARM PARA CAMBIOS EN LA SEGURIDAD
# ============================================================================

# Log group filter para detectar cambios en Security Groups
resource "aws_cloudwatch_log_group" "security_alerts" {
  name              = "/aws/cloudtrail/security-alerts/${var.project_name}"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-security-alerts"
  }
}

# Filtro de métrica para cambios en Security Groups
resource "aws_cloudwatch_log_group_metric_filter" "security_group_changes" {
  count          = var.enable_cloudtrail ? 1 : 0
  name           = "${var.project_name}-sg-changes"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  filter_pattern = "{ ($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = AuthorizeSecurityGroupEgress) || ($.eventName = RevokeSecurityGroupEgress) }"

  metric_transformation {
    name      = "${var.project_name}SGChanges"
    namespace = "${var.project_name}/Security"
    value     = "1"
  }
}

# Filtro de métrica para cambios en IAM
resource "aws_cloudwatch_log_group_metric_filter" "iam_changes" {
  count          = var.enable_cloudtrail ? 1 : 0
  name           = "${var.project_name}-iam-changes"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  filter_pattern = "{ ($.eventName = CreateUser) || ($.eventName = CreateAccessKey) || ($.eventName = AttachUserPolicy) || ($.eventName = DeleteUser) }"

  metric_transformation {
    name      = "${var.project_name}IAMChanges"
    namespace = "${var.project_name}/Security"
    value     = "1"
  }
}

# ============================================================================
# SALIDAS PARA CLOUDTRAIL
# ============================================================================

output "cloudtrail_bucket_name" {
  description = "Nombre del bucket S3 de CloudTrail"
  value       = aws_s3_bucket.cloudtrail.id
}

output "cloudtrail_log_group" {
  description = "Nombre del CloudWatch Log Group de CloudTrail"
  value       = aws_cloudwatch_log_group.cloudtrail.name
}

output "cloudtrail_arn" {
  description = "ARN del CloudTrail"
  value       = try(aws_cloudtrail.main[0].arn, null)
}
