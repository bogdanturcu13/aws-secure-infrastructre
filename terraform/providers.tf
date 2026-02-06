terraform{
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 6.0"
        }
    }
}

provider "aws" {
    region = "eu-west-2"

    default_tags {
      tags = {
        "Project" = "Secure AWS Infrastructure"
        "ManagedBy" = "Terraform"
        "Owner" = "Bogdan Turcu"
      }
    }
}