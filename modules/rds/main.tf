locals {
  # postgres and mysql have well-known default ports. Other engines must
  # pass port so we do not guess wrong.
  default_ports = {
    postgres = 5432
    mysql    = 3306
  }

  port = var.port != null ? var.port : lookup(local.default_ports, var.engine, null)

  # Use the caller-supplied group when it is set. try avoids indexing the
  # subnet group resource when it was not created (count = 0).
  db_subnet_group_name = var.db_subnet_group_name != null ? var.db_subnet_group_name : try(aws_db_subnet_group.this[0].name, null)

  tags = merge(var.additional_tags, {
    Owner       = var.owner
    Team        = var.team
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_db_subnet_group" "this" {
  count = var.subnet_ids != null ? 1 : 0

  name       = "${var.identifier}-subnets"
  subnet_ids = var.subnet_ids

  tags = local.tags
}

resource "aws_db_instance" "this" {
  identifier     = var.identifier
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = var.storage_type
  storage_encrypted = true

  db_name  = var.db_name
  username = var.username
  port     = local.port

  # RDS creates the master password in Secrets Manager. There is no password
  # argument in this module. The secret ARN is still stored in Terraform state.
  manage_master_user_password = true

  db_subnet_group_name   = local.db_subnet_group_name
  vpc_security_group_ids = var.security_group_ids

  publicly_accessible = false
  multi_az            = false

  backup_retention_period   = var.backup_retention_period
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : var.final_snapshot_identifier
  deletion_protection       = var.deletion_protection

  performance_insights_enabled = false
  monitoring_interval          = 0

  lifecycle {
    precondition {
      condition     = (var.subnet_ids != null) != (var.db_subnet_group_name != null)
      error_message = "Set exactly one of subnet_ids or db_subnet_group_name. RDS needs subnets in at least two Availability Zones."
    }

    precondition {
      condition     = var.engine_version != null && length(var.engine_version) > 0
      error_message = "engine_version is required. Look up a supported version and pin it. This module does not select latest."
    }

    precondition {
      condition     = local.port != null
      error_message = "Set port when engine is not postgres or mysql."
    }

    precondition {
      condition     = var.skip_final_snapshot || (var.final_snapshot_identifier != null && length(var.final_snapshot_identifier) > 0)
      error_message = "Set final_snapshot_identifier when skip_final_snapshot is false."
    }
  }

  tags = local.tags
}
