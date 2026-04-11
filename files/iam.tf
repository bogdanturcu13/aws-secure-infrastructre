# ============================================================================
# IAM ROLES Y POLICIES - SERVIDOR PRIVADO
# ============================================================================

# Rol IAM para la instancia privada
resource "aws_iam_role" "private_server" {
  name              = "${var.project_name}-private-server-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-private-server-role"
  }
}

# Adjuntar política administrada para SSM (Systems Manager)
resource "aws_iam_role_policy_attachment" "private_server_ssm" {
  role       = aws_iam_role.private_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Política personalizada para descifrar volúmenes EBS con KMS
resource "aws_iam_role_policy" "private_server_kms" {
  name   = "${var.project_name}-private-server-kms-policy"
  role   = aws_iam_role.private_server.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowKMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.ebs.arn
      }
    ]
  })
}

# Política para acceso a CloudWatch Logs (para SSM session logging)
resource "aws_iam_role_policy" "private_server_cloudwatch" {
  name   = "${var.project_name}-private-server-cloudwatch-policy"
  role   = aws_iam_role.private_server.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${data.aws_caller_identity.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ssm/private-server/*"
      }
    ]
  })
}

# Política para acceso a S3 de CloudTrail logs (lectura para auditoría)
resource "aws_iam_role_policy" "private_server_s3_cloudtrail" {
  name   = "${var.project_name}-private-server-s3-cloudtrail-policy"
  role   = aws_iam_role.private_server.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowReadCloudTrailLogs"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.cloudtrail.arn,
          "${aws_s3_bucket.cloudtrail.arn}/*"
        ]
      }
    ]
  })
}

# Instance Profile para la instancia privada
resource "aws_iam_instance_profile" "private_server" {
  name = "${var.project_name}-private-server-profile"
  role = aws_iam_role.private_server.name
}

# ============================================================================
# IAM ROLES Y POLICIES - CLOUDTRAIL
# ============================================================================

# Rol para CloudTrail (si es necesario para análisis adicional)
resource "aws_iam_role" "cloudtrail_analysis" {
  name              = "${var.project_name}-cloudtrail-analysis-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-cloudtrail-analysis-role"
  }
}

# Política para que Lambda pueda leer logs de CloudTrail
resource "aws_iam_role_policy" "cloudtrail_read" {
  name   = "${var.project_name}-cloudtrail-read-policy"
  role   = aws_iam_role.cloudtrail_analysis.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadCloudTrailLogs"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.cloudtrail.arn,
          "${aws_s3_bucket.cloudtrail.arn}/*"
        ]
      }
    ]
  })
}

# ============================================================================
# IAM USER PARA ACCESO (EJEMPLO)
# ============================================================================

# Crear un ejemplo de usuario IAM que puede acceder a la instancia privada mediante SSM
# Descomentar y personalizar según necesidad
/*
resource "aws_iam_user" "ssm_user" {
  name = "${var.project_name}-ssm-user"
  
  tags = {
    Name = "${var.project_name}-ssm-user"
  }
}

resource "aws_iam_user_policy" "ssm_access" {
  name   = "${var.project_name}-ssm-access"
  user   = aws_iam_user.ssm_user.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSSMAccess"
        Effect = "Allow"
        Action = [
          "ssm:StartSession",
          "ssm:TerminateSession",
          "ssm:GetConnectionStatus",
          "ssm:DescribeSessions",
          "ssm:DescribeInstanceInformation"
        ]
        Resource = [
          "arn:aws:ec2:${data.aws_caller_identity.current.region}:${data.aws_caller_identity.current.account_id}:instance/*",
          "arn:aws:ssm:${data.aws_caller_identity.current.region}:${data.aws_caller_identity.current.account_id}:session/*"
        ]
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/Project" = var.project_name
          }
        }
      }
    ]
  })
}
*/
