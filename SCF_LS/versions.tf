terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider configuration stays in this root, not in the modules.
# Credentials come from the standard AWS chain. Nothing here is a key.
provider "aws" {
  region              = var.aws_region
  allowed_account_ids = var.allowed_account_ids

  default_tags {
    tags = {
      Owner       = var.owner
      Team        = var.team
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
