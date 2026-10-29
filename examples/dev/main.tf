# Personal-account composition. This file only passes configuration into the
# reusable modules. It does not define EC2, S3, or RDS resources itself.
#
# Copy terraform.tfvars.example to terraform.tfvars and edit that file.
# terraform plan reads terraform.tfvars automatically and should not prompt
# for these values.

module "ec2" {
  source = "../../modules/ec2"

  name               = var.ec2_name
  subnet_id          = var.subnet_id
  security_group_ids = var.security_group_ids

  team        = var.team
  owner       = var.owner
  environment = var.environment

  ami_type         = var.ami_type
  instance_type    = var.instance_type
  key_name         = var.key_name
  root_volume_size = var.root_volume_size
  root_volume_type = var.root_volume_type
  additional_tags  = var.additional_tags
}

module "s3" {
  source = "../../modules/s3"

  bucket_name        = var.bucket_name
  versioning_enabled = var.versioning_enabled

  team            = var.team
  owner           = var.owner
  environment     = var.environment
  additional_tags = var.additional_tags
}

# Off unless create_rds is true. count = 0 keeps every RDS resource out of
# the plan, including the DB subnet group and the Secrets Manager secret.
module "rds" {
  count  = var.create_rds ? 1 : 0
  source = "../../modules/rds"

  identifier         = "${var.team}-${var.environment}-db"
  engine_version     = var.rds_engine_version
  subnet_ids         = var.rds_subnet_ids
  security_group_ids = var.security_group_ids
  team               = var.team
  owner              = var.owner
  environment        = var.environment
  additional_tags    = var.additional_tags
}
