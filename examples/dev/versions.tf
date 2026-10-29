terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider configuration stays in this example, not in the reusable modules.
# Credentials come from the standard AWS chain (environment, shared config,
# or SSO). Nothing here hardcodes a key.
provider "aws" {
  region = var.aws_region
}
