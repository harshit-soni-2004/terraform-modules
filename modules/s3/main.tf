# The bucket is created in whatever region the caller configured on the AWS
# provider. This data source reads that region so the module can output it
# without taking a region variable of its own.
data "aws_region" "current" {}

locals {
  tags = merge(var.additional_tags, {
    Owner       = var.owner
    Team        = var.team
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name

  # Empty buckets can be destroyed. A bucket that still has objects fails
  # destroy instead of being emptied.
  force_destroy = false

  tags = local.tags
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}
