variable "name_prefix" {
  description = "Short prefix for resource names. Lowercase letters, digits, and hyphens."
  type        = string
}

variable "vpc_cidr" {
  description = "Required. VPC CIDR. Must not overlap on-premises or other VPCs. With subnet_newbits 8, a /16 yields /24 subnets."
  type        = string
}

variable "subnet_newbits" {
  description = "Bits added to the VPC prefix to form each subnet. Default 8. Eight subnets are carved (2 AZs x 4 tiers)."
  type        = number
  default     = 8
}

variable "availability_zones" {
  description = "Exactly two Availability Zone names, in order. No default."
  type        = list(string)
}

variable "enable_data_nat_route" {
  description = "When true, data-tier subnets use the NAT Gateway as their default route so first boot can pull images. Turn this off after bootstrap. SSM to the DB instances then stops working, because this stack has no SSM VPC endpoints."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied in addition to Name. Owner, Team, Environment, and ManagedBy should already be in provider default_tags."
  type        = map(string)
  default     = {}
}
