# COST: an RDS instance is billed for compute, storage, and backups while it
# exists, including when it is idle. Secrets Manager adds a small monthly
# charge for the managed master password. Destroy the instance after testing.

variable "identifier" {
  description = "Required. Unique DB instance identifier in this account and region. Lowercase letters, digits, and hyphens, starting with a letter. The module does not invent one."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,62}$", var.identifier))
    error_message = "identifier must start with a letter and contain only lowercase letters, digits, and hyphens (1-63 characters)."
  }
}

variable "security_group_ids" {
  description = "Required. VPC security groups for the database. The module does not create one."
  type        = list(string)

  validation {
    condition     = length(var.security_group_ids) > 0
    error_message = "Provide at least one security group ID."
  }
}

variable "subnet_ids" {
  description = "Optional. At least two subnet IDs in different Availability Zones. When set, the module creates a DB subnet group (no hourly charge) and ignores db_subnet_group_name. RDS will not start in a single subnet."
  type        = list(string)
  default     = null

  validation {
    condition     = var.subnet_ids == null || length(var.subnet_ids) >= 2
    error_message = "subnet_ids must contain at least two subnet IDs in different Availability Zones."
  }
}

variable "db_subnet_group_name" {
  description = "Optional. Name of an existing DB subnet group. Set this or subnet_ids, not both. Use this when the platform already created the subnet group."
  type        = string
  default     = null
}

variable "engine" {
  description = "Optional. Database engine. Defaults to postgres. This is a low-cost starting point, not a company standard. mysql is the other engine with a built-in default port. Set port yourself for any other engine."
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "Required. Exact engine version, for example a current PostgreSQL version such as 16.8. There is no default: selecting latest at plan time would make the next deployment a different version, and a version hardcoded in this module can be retired. Verify a supported version in your region before use."
  type        = string
}

variable "instance_class" {
  description = "Optional. RDS instance class. Defaults to db.t3.micro. Free Tier eligibility depends on the account, region, and current AWS offer, and is not guaranteed."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Optional. Storage in GiB. Defaults to 20, the minimum RDS allows for PostgreSQL and MySQL on gp3. You are billed for the allocated size."
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20
    error_message = "allocated_storage must be at least 20 GiB for PostgreSQL and MySQL on gp2 or gp3."
  }
}

variable "storage_type" {
  description = "Optional. Storage type. Defaults to gp3. gp2 is allowed. Provisioned IOPS (io1) is not accepted."
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp2", "gp3"], var.storage_type)
    error_message = "storage_type must be gp3 or gp2."
  }
}

variable "db_name" {
  description = "Optional. Application database to create with the instance. Null skips that extra database. PostgreSQL still provides its built-in postgres database."
  type        = string
  default     = null
}

variable "username" {
  description = "Optional. Master username. Defaults to dbadmin. The password is not accepted here; RDS stores it in Secrets Manager."
  type        = string
  default     = "dbadmin"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9]{0,15}$", var.username))
    error_message = "username must start with a letter and contain only letters and digits (1-16 characters)."
  }
}

variable "port" {
  description = "Optional. Database port. Null uses 5432 for postgres and 3306 for mysql. Any other engine must set port explicitly."
  type        = number
  default     = null

  validation {
    condition     = var.port == null || (var.port >= 1 && var.port <= 65535)
    error_message = "port must be between 1 and 65535."
  }
}

variable "backup_retention_period" {
  description = "Optional. Days of automated backups to retain. Defaults to 1 for a short-lived test. Backup storage can still incur a charge. The maximum RDS allows is 35."
  type        = number
  default     = 1

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "backup_retention_period must be between 0 and 35."
  }
}

variable "skip_final_snapshot" {
  description = "Optional. TEST-ONLY default: true, so destroy does not take a final snapshot. A final snapshot is extra storage you keep paying for, but skipping it deletes the data. The Platform team must decide the production value. Set this to false only together with final_snapshot_identifier."
  type        = bool
  default     = true
}

variable "final_snapshot_identifier" {
  description = "Optional. Snapshot name used on destroy when skip_final_snapshot is false. Leave null with the test default skip_final_snapshot = true."
  type        = string
  default     = null
}

variable "deletion_protection" {
  description = "Optional. TEST-ONLY default: false, so the instance can be destroyed after a personal-account test. The Platform team must decide whether production instances enable this. true blocks terraform destroy until you turn it off."
  type        = bool
  default     = false
}

variable "team" {
  description = "Required. Team code used in the Team tag. Lowercase letters, digits, and hyphens only, so the value is safe to reuse in names. Examples: los, scf."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.team))
    error_message = "team must contain only lowercase letters, digits, and hyphens."
  }
}

variable "owner" {
  description = "Required. Person or group accountable for this database. Stored in the Owner tag."
  type        = string
}

variable "environment" {
  description = "Optional. Deployment environment. Stored in the Environment tag."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "additional_tags" {
  description = "Optional. Extra tags. Owner, Team, Environment, and ManagedBy are applied afterwards and cannot be overridden."
  type        = map(string)
  default     = {}
}
