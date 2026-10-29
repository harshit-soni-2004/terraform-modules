variable "name_prefix" {
  description = "Short name prefix. Kept short so target-group names stay within 32 characters."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID. This module does not create a VPC."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets for the internet-facing ALB. At least two AZs."
  type        = list(string)
}

variable "mz_subnet_ids" {
  description = "Private subnets for the internal ALB. At least two AZs."
  type        = list(string)
}

variable "external_security_group_id" {
  description = "Security group for the external ALB."
  type        = string
}

variable "internal_security_group_id" {
  description = "Security group for the internal ALB."
  type        = string
}

variable "external_certificate_arn" {
  description = "ACM certificate for the external listener. Null means no HTTPS listener."
  type        = string
  default     = null
}

variable "internal_certificate_arn" {
  description = "ACM certificate for the internal listener. Null means no HTTPS listener."
  type        = string
  default     = null
}

variable "allow_insecure_external_listener" {
  description = "TEST-ONLY. HTTP listener on the external ALB."
  type        = bool
  default     = false
}

variable "allow_insecure_internal_listener" {
  description = "TEST-ONLY. HTTP listener on the internal ALB."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "ALB deletion protection. Default false so a first attempt can be destroyed."
  type        = bool
  default     = false
}

variable "dmz_instance_ids" {
  description = "DMZ web instances keyed by a stable name such as dmz_web-0. The key is known at plan time. The id may not be."
  type        = map(string)
}

variable "dmz_port" {
  description = "DMZ target port. HTTP inside the VPC."
  type        = number
}

variable "dmz_health_check_path" {
  description = "HTTP path the external target group checks. Stock Nginx answers / with 200."
  type        = string
}

variable "internal_targets" {
  description = "App and reporting tiers behind the internal ALB. No instance ids here, so this map stays known at plan time."
  type = map(object({
    port              = number
    health_check_path = string
    path_patterns     = list(string)
    default_target    = bool
  }))
}

variable "internal_instance_ids" {
  description = "For each internal tier, a map of stable instance key to instance id."
  type        = map(map(string))
}

variable "tags" {
  description = "Extra tags."
  type        = map(string)
  default     = {}
}
