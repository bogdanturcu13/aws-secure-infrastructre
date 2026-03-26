terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      "Project"   = var.project_name
      "ManagedBy" = "Terraform"
      "Owner"     = var.owner
    }
  }
}

# Datos de la cuenta, usados en las políticas de KMS y S3
data "aws_caller_identity" "current" {}
