variable "bucket_name" {
  description = "Required. Globally unique S3 bucket name. Underscores are rejected. AWS treats this as a single worldwide namespace, so a name taken in any account cannot be reused. The module does not invent one."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be 3-63 characters, start and end with a letter or digit, and contain only lowercase letters, digits, dots, and hyphens. Underscores are not allowed."
  }
}

variable "versioning_enabled" {
  description = "Keep previous versions of objects. Default: true. Versioning can increase storage cost over time. After versioning has been on, AWS only allows Enabled or Suspended, not a full disable."
  type        = bool
  default     = true
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
  description = "Required. Person or group accountable for this bucket. Stored in the Owner tag."
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
  description = "Optional. Extra tags. Owner, Team, Environment, and ManagedBy are applied afterwards and cannot be overridden."
  type        = map(string)
  default     = {}
}
