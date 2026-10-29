variable "name_prefix" {
  description = "Short name prefix."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID. This module does not create a VPC."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR. DNS egress is limited to this range."
  type        = string
}

variable "alb_ingress_cidrs" {
  description = "Who may open the external ALB. No default. Not 0.0.0.0/0 unless the caller sets that on purpose."
  type        = list(string)
}

variable "bank_staff_cidrs" {
  description = "Who may open MZ web. Empty means no ingress."
  type        = list(string)
}

variable "allow_insecure_external_listener" {
  description = "TEST-ONLY. When true, the external ALB security group also allows TCP 80."
  type        = bool
}

variable "allow_insecure_internal_listener" {
  description = "TEST-ONLY. When true, the internal ALB security group also allows TCP 80."
  type        = bool
}

variable "dmz_web_port" {
  description = "Port the external ALB uses to reach DMZ web. Stock Nginx is HTTP 80."
  type        = number
}

variable "mz_web_port" {
  description = "Port bank-staff CIDRs may use to reach MZ web."
  type        = number
}

variable "app_ports" {
  description = "Ports the internal ALB may use to reach app-role instances."
  type        = list(number)
}

variable "reporting_ports" {
  description = "Ports the internal ALB may use to reach reporting-app instances."
  type        = list(number)
}

variable "mysql_port" {
  description = "MySQL port. TDD value is 3306."
  type        = number
}

variable "redis_port" {
  description = "Redis client port. TDD value is 6379."
  type        = number
}

variable "redis_cluster_ports" {
  description = "Extra ports between Redis instances. Topology is unconfirmed, so this list has no default."
  type        = list(number)
}

variable "rabbitmq_client_port" {
  description = "RabbitMQ AMQP port published on the host."
  type        = number
}

variable "rabbitmq_management_port" {
  description = "RabbitMQ management port published on the host."
  type        = number
}

variable "rabbitmq_cluster_ports" {
  description = "Ports between RabbitMQ instances. Topology is unconfirmed, so this list has no default."
  type        = list(number)
}

variable "tags" {
  description = "Extra tags."
  type        = map(string)
  default     = {}
}
