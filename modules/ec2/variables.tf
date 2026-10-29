variable "name" {
  description = "Required. Name tag for the instance and its root volume. Not an AWS-generated hostname."
  type        = string

  validation {
    condition     = length(var.name) > 0
    error_message = "name must not be empty."
  }
}

variable "subnet_id" {
  description = "Required. Subnet for the instance. The module does not create a VPC or subnet, because those cannot be guessed safely."
  type        = string

  validation {
    condition     = can(regex("^subnet-([0-9a-f]{8}|[0-9a-f]{17})$", var.subnet_id))
    error_message = "subnet_id must look like a subnet ID (subnet- followed by 8 or 17 hexadecimal characters)."
  }
}

variable "security_group_ids" {
  description = "Required. Security groups to attach. The module does not create one."
  type        = list(string)

  validation {
    condition     = length(var.security_group_ids) > 0 && alltrue([for id in var.security_group_ids : can(regex("^sg-([0-9a-f]{8}|[0-9a-f]{17})$", id))])
    error_message = "Provide at least one security group ID. Each ID must look like sg- followed by 8 or 17 hexadecimal characters."
  }
}

variable "ami_type" {
  description = "Operating system for the EC2 instance. Supported values: amazon_linux, ubuntu. Default: amazon_linux. Both lookups return an x86_64 image in the caller region. The module resolves the AMI ID."
  type        = string
  default     = "amazon_linux"

  validation {
    condition     = contains(["amazon_linux", "ubuntu"], var.ami_type)
    error_message = "ami_type must be either amazon_linux or ubuntu."
  }
}

variable "instance_type" {
  description = "EC2 instance type. Default: t3.micro. Free Tier eligibility depends on the account, region, and current AWS offer, and is not guaranteed. Larger types cost more."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^[a-z0-9]+\\.[a-z0-9]+$", var.instance_type))
    error_message = "instance_type must look like a valid EC2 instance type, for example t3.micro."
  }
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB. Default: 8. You are billed for the provisioned size. Allowed range: 8 to 100."
  type        = number
  default     = 8

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 100
    error_message = "root_volume_size must be between 8 and 100 GiB."
  }
}

variable "root_volume_type" {
  description = "Root EBS volume type. Default: gp3. gp2 is allowed. Provisioned IOPS types (io1, io2) are not accepted."
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp2", "gp3"], var.root_volume_type)
    error_message = "root_volume_type must be gp3 or gp2."
  }
}

variable "key_name" {
  description = "Name of an existing EC2 key pair. Default: null, which launches without an SSH key. The module does not create a key pair or a private key."
  type        = string
  default     = null
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
  description = "Required. Person or group accountable for this instance. Stored in the Owner tag."
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

variable "additional_tags" {
  description = "Optional. Extra tags. Owner, Team, Environment, ManagedBy, and Name are applied afterwards and cannot be overridden."
  type        = map(string)
  default     = {}
}
