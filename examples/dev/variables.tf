# Contract for examples/dev. Team-specific values belong in terraform.tfvars,
# not in this file. A variable with a default can be omitted from tfvars.

variable "aws_region" {
  description = "AWS region for this stack. Default: ap-south-1, from the original proof of concept, not a company standard. The selected operating system image is resolved in this region."
  type        = string
  default     = "ap-south-1"
}

variable "team" {
  description = "Required. Team code stored in the Team tag and safe to reuse in names. Lowercase letters, digits, and hyphens. Examples: los, scf."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.team))
    error_message = "team must contain only lowercase letters, digits, and hyphens."
  }
}

variable "owner" {
  description = "Required. Person or group accountable for these resources. Stored in the Owner tag. No default, because a name cannot be guessed safely."
  type        = string
}

variable "environment" {
  description = "Deployment environment stored in the Environment tag. Default: dev."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "ec2_name" {
  description = "Required. Name tag for the EC2 instance. No default, because the name is team-specific."
  type        = string

  validation {
    condition     = length(var.ec2_name) > 0
    error_message = "ec2_name must not be empty."
  }
}

variable "ami_type" {
  description = "Operating system for the EC2 instance. Supported values: amazon_linux, ubuntu. Default: amazon_linux."
  type        = string
  default     = "amazon_linux"

  validation {
    condition     = contains(["amazon_linux", "ubuntu"], var.ami_type)
    error_message = "ami_type must be either amazon_linux or ubuntu."
  }
}

variable "instance_type" {
  description = "EC2 instance type. Default: t3.micro."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^[a-z0-9]+\\.[a-z0-9]+$", var.instance_type))
    error_message = "instance_type must look like a valid EC2 instance type, for example t3.micro."
  }
}

variable "key_name" {
  description = "Name of an existing EC2 key pair. Default: null, which launches the instance without an SSH key. No key pair is created."
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB. Default: 8. Allowed range: 8 to 100."
  type        = number
  default     = 8

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 100
    error_message = "root_volume_size must be between 8 and 100 GiB."
  }
}

variable "root_volume_type" {
  description = "Root EBS volume type. Default: gp3."
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp2", "gp3"], var.root_volume_type)
    error_message = "root_volume_type must be gp3 or gp2."
  }
}

variable "subnet_id" {
  description = "Required. Existing subnet ID for the instance. No default, because a subnet cannot be guessed safely. The example does not create a VPC."
  type        = string

  validation {
    condition     = can(regex("^subnet-([0-9a-f]{8}|[0-9a-f]{17})$", var.subnet_id))
    error_message = "subnet_id must look like a subnet ID (subnet- followed by 8 or 17 hexadecimal characters)."
  }
}

variable "security_group_ids" {
  description = "Required. Existing security group IDs for the instance. No default. The example does not create a security group."
  type        = list(string)

  validation {
    condition     = length(var.security_group_ids) > 0 && alltrue([for id in var.security_group_ids : can(regex("^sg-([0-9a-f]{8}|[0-9a-f]{17})$", id))])
    error_message = "Provide at least one security group ID. Each ID must look like sg- followed by 8 or 17 hexadecimal characters."
  }
}

variable "bucket_name" {
  description = "Required. Globally unique S3 bucket name. No default. Underscores are rejected."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be 3-63 characters, start and end with a letter or digit, and contain only lowercase letters, digits, dots, and hyphens. Underscores are not allowed."
  }
}

variable "versioning_enabled" {
  description = "Keep previous S3 object versions. Default: true."
  type        = bool
  default     = true
}

variable "additional_tags" {
  description = "Extra tags merged under the platform tags. Default: {}."
  type        = map(string)
  default     = {}
}

variable "create_rds" {
  description = "Include the RDS module in this stack. Default: false, so a normal plan does not create a database."
  type        = bool
  default     = false
}

variable "rds_engine_version" {
  description = "Exact RDS engine version. Required only when create_rds is true. Default: null. Verify the version in aws_region before use."
  type        = string
  default     = null
}

variable "rds_subnet_ids" {
  description = "At least two subnet IDs in different Availability Zones. Required only when create_rds is true. Default: null."
  type        = list(string)
  default     = null
}
