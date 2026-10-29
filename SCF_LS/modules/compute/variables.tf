variable "name_prefix" {
  description = "Short name prefix."
  type        = string
}

variable "tiers" {
  description = "One object per server group. role selects the security group, the subnet tier, and the boot script."
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

variable "subnet_ids_by_tier" {
  description = "Subnet IDs keyed by public, mz, and data. dmz_web uses public."
  type        = map(list(string))
}

variable "security_group_ids_by_role" {
  description = "Security group ID keyed by role."
  type        = map(string)
}

variable "ami_id" {
  description = "AMI to launch. The root passes either the caller override or the Amazon Linux 2023 SSM lookup."
  type        = string
}

variable "instance_profile_name" {
  description = "Instance profile name. Required by the root precondition."
  type        = string
}

variable "nginx_image" {
  description = "Nginx image, including a tag. No default."
  type        = string
}

variable "placeholder_image" {
  description = "Placeholder image for app and reporting. No default. Not a Veefin build."
  type        = string
}

variable "rabbitmq_image" {
  description = "RabbitMQ image, including a tag. No default."
  type        = string
}

variable "redis_image" {
  description = "Redis image, including a tag. No default."
  type        = string
}

variable "mysql_image" {
  description = "MySQL image, including a tag. No default."
  type        = string
}

variable "rabbitmq_tls" {
  description = "When true, the boot script exits. This stack does not provision RabbitMQ TLS certificates."
  type        = bool
}

variable "rabbitmq_client_port" {
  type = number
}

variable "rabbitmq_management_port" {
  type = number
}

variable "redis_port" {
  type = number
}

variable "mysql_port" {
  type = number
}

variable "tags" {
  description = "Extra tags. Name, Owner, Team, Environment, and ManagedBy are set explicitly."
  type        = map(string)
  default     = {}
}

variable "owner" {
  type = string
}

variable "team" {
  type = string
}

variable "environment" {
  type = string
}
