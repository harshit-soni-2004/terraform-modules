variable "aws_region" {
  description = "Required. AWS region for this stack. No default."
  type        = string

  validation {
    condition     = length(var.aws_region) > 0
    error_message = "aws_region is required."
  }
}

variable "allowed_account_ids" {
  description = "Required. Account IDs this stack may run in. The AWS provider rejects any other account."
  type        = list(string)

  validation {
    condition     = length(var.allowed_account_ids) > 0 && alltrue([for id in var.allowed_account_ids : can(regex("^[0-9]{12}$", id))])
    error_message = "allowed_account_ids must contain at least one 12-digit account ID."
  }
}

variable "name_prefix" {
  description = "Required. Short prefix. Lowercase letters, digits, and hyphens. 1-12 characters so load balancer and target group names fit."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,10}[a-z0-9]$", var.name_prefix)) || can(regex("^[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 1-12 characters, lowercase letters, digits, and hyphens, and must not start or end with a hyphen."
  }
}

variable "owner" {
  description = "Required. Owner tag. Same value is sent to the S3 module."
  type        = string

  validation {
    condition     = length(var.owner) > 0
    error_message = "owner is required."
  }
}

variable "team" {
  description = "Required. Team tag. Lowercase letters, digits, and hyphens."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.team))
    error_message = "team must contain only lowercase letters, digits, and hyphens."
  }
}

variable "environment" {
  description = "Required. One of dev, staging, prod. The shared S3 module rejects any other value. SIT maps to dev, UAT maps to staging, Prod-DC maps to prod. Prod-DR is out of scope."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "additional_tags" {
  description = "Optional extra tags. Name, Owner, Team, Environment, and ManagedBy are set by this stack and win on a conflict."
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "Required. VPC CIDR. Must not overlap on-premises or other VPCs. With subnet_newbits 8, use a /16 so each subnet is a /24."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR."
  }
}

variable "subnet_newbits" {
  description = "Bits added to the VPC prefix. Default 8. Eight subnets are carved, so this must be large enough for index 7."
  type        = number
  default     = 8

  validation {
    condition     = var.subnet_newbits >= 3 && var.subnet_newbits <= 12
    error_message = "subnet_newbits must be from 3 to 12."
  }
}

variable "availability_zones" {
  description = "Required. Exactly two Availability Zone names, in order. This stack does not look them up."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2 && var.availability_zones[0] != var.availability_zones[1]
    error_message = "availability_zones must be two different zone names."
  }
}

variable "enable_data_nat_route" {
  description = "Default true. Data subnets use the NAT Gateway as their default route so first boot can pull images. Set false after bootstrap. That also removes the SSM path, because this stack creates no SSM VPC endpoints."
  type        = bool
  default     = true
}

variable "alb_ingress_cidrs" {
  description = "Required. Who may connect to the external ALB. No 0.0.0.0/0 default."
  type        = list(string)

  validation {
    condition     = length(var.alb_ingress_cidrs) > 0 && alltrue([for cidr in var.alb_ingress_cidrs : can(cidrhost(cidr, 0))])
    error_message = "alb_ingress_cidrs must contain at least one IPv4 CIDR."
  }
}

variable "bank_staff_cidrs" {
  description = "Optional. Who may connect to MZ web. Default is an empty list, which creates no ingress rule."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.bank_staff_cidrs : can(cidrhost(cidr, 0))])
    error_message = "bank_staff_cidrs entries must be IPv4 CIDRs."
  }
}

variable "external_certificate_arn" {
  description = "ACM certificate ARN for the external ALB. Null creates no HTTPS listener on that load balancer."
  type        = string
  default     = null
}

variable "internal_certificate_arn" {
  description = "ACM certificate ARN for the internal ALB. Null creates no HTTPS listener on that load balancer."
  type        = string
  default     = null
}

variable "allow_insecure_external_listener" {
  description = "TEST-ONLY. Default false. HTTP listener on the external ALB. Each ALB still needs its own certificate or its own flag."
  type        = bool
  default     = false
}

variable "allow_insecure_internal_listener" {
  description = "TEST-ONLY. Default false. HTTP listener on the internal ALB. When true, DMZ and MZ web also get egress to that ALB on port 80."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "ALB deletion protection. Default false so a first attempt can be destroyed."
  type        = bool
  default     = false
}

variable "ami_id" {
  description = "Optional AMI override. Null uses the Amazon Linux 2023 SSM public parameter. That lookup runs on your plan, not in this module's defaults."
  type        = string
  default     = null
}

variable "create_instance_profile" {
  description = "Default false. When true, this stack creates an SSM instance role and profile. When false, existing_instance_profile_name is required."
  type        = bool
  default     = false
}

variable "existing_instance_profile_name" {
  description = "Name of an instance profile this stack does not create. Required when create_instance_profile is false."
  type        = string
  default     = null
}

variable "permissions_boundary_arn" {
  description = "Optional permissions boundary. Applied only when this stack creates the role."
  type        = string
  default     = null
}

variable "bucket_name" {
  description = "Required. Globally unique S3 bucket name. No underscores."
  type        = string
}

variable "tiers" {
  description = "Server groups. role is dmz_web, mz_web, app, reporting_app, rabbitmq, redis, or mysql. Counts and instance types have no defaults."
  type = map(object({
    role              = string
    count             = number
    instance_type     = string
    root_volume_gb    = number
    data_volume_gb    = optional(number, 0)
    container_port    = optional(number)
    health_check_path = optional(string, "/")
    path_patterns     = optional(list(string), [])
    default_target    = optional(bool, false)
  }))
}

variable "nginx_image" {
  description = "Required. Nginx image and tag. No default. Release line to choose from is 1.30.x."
  type        = string
}

variable "placeholder_image" {
  description = "Required. Image for the app and reporting placeholders. No default. Not a Veefin build. The health check expects HTTP 200 on /."
  type        = string
}

variable "rabbitmq_image" {
  description = "Required. RabbitMQ image and tag. No default. Release line to choose from is 4.3.x until that line stops receiving fixes."
  type        = string
}

variable "redis_image" {
  description = "Required. Redis image and tag. No default. Do not select a tag until legal decides the license. 7.2 is end of life."
  type        = string
}

variable "mysql_image" {
  description = "Required. MySQL image and tag. No default. Release line is 8.4 LTS."
  type        = string
}

variable "rabbitmq_tls" {
  description = "When true, first boot exits. This stack does not install RabbitMQ TLS certificates, so it must not publish 5671."
  type        = bool
}

variable "rabbitmq_client_port" {
  description = "Required. Host port published to container 5672. TDD TLS port is 5671, which this test boot does not serve."
  type        = number
}

variable "rabbitmq_management_port" {
  description = "Required. Host port published to container 15672. TDD TLS port is 15671."
  type        = number
}

variable "rabbitmq_cluster_ports" {
  description = "Required. Ports allowed between RabbitMQ instances. No default, because the cluster topology is not confirmed. Terraform does not form the cluster."
  type        = list(number)
}

variable "redis_port" {
  description = "Required. Redis client port."
  type        = number
}

variable "redis_cluster_ports" {
  description = "Required. Ports allowed between Redis instances. No default. Terraform does not configure replication."
  type        = list(number)
}

variable "mysql_port" {
  description = "Required. MySQL port."
  type        = number
}
