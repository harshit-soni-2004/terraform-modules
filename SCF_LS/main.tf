data "aws_ssm_parameter" "al2023" {
  count = var.ami_id == null ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_iam_policy_document" "ec2_assume" {
  count = var.create_instance_profile ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm" {
  count = var.create_instance_profile ? 1 : 0

  name                 = "${var.name_prefix}-ssm"
  assume_role_policy   = data.aws_iam_policy_document.ec2_assume[0].json
  permissions_boundary = var.permissions_boundary_arn
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count = var.create_instance_profile ? 1 : 0

  role       = aws_iam_role.ssm[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  count = var.create_instance_profile ? 1 : 0

  name = "${var.name_prefix}-ssm"
  role = aws_iam_role.ssm[0].name
}

module "network" {
  source = "./modules/network"

  name_prefix           = var.name_prefix
  vpc_cidr              = var.vpc_cidr
  subnet_newbits        = var.subnet_newbits
  availability_zones    = var.availability_zones
  enable_data_nat_route = var.enable_data_nat_route
  tags                  = var.additional_tags
}

module "security" {
  source = "./modules/security"

  name_prefix                      = var.name_prefix
  vpc_id                           = module.network.vpc_id
  vpc_cidr                         = module.network.vpc_cidr
  alb_ingress_cidrs                = var.alb_ingress_cidrs
  bank_staff_cidrs                 = var.bank_staff_cidrs
  allow_insecure_external_listener = var.allow_insecure_external_listener
  allow_insecure_internal_listener = var.allow_insecure_internal_listener
  dmz_web_port                     = local.dmz_web.container_port
  mz_web_port                      = local.mz_web.container_port
  app_ports                        = local.app_ports
  reporting_ports                  = local.reporting_ports
  mysql_port                       = var.mysql_port
  redis_port                       = var.redis_port
  redis_cluster_ports              = var.redis_cluster_ports
  rabbitmq_client_port             = var.rabbitmq_client_port
  rabbitmq_management_port         = var.rabbitmq_management_port
  rabbitmq_cluster_ports           = var.rabbitmq_cluster_ports
  tags                             = var.additional_tags
}

module "compute" {
  source = "./modules/compute"

  name_prefix                = var.name_prefix
  tiers                      = var.tiers
  subnet_ids_by_tier         = local.subnet_ids_by_tier
  security_group_ids_by_role = local.security_group_ids_by_role
  ami_id                     = var.ami_id != null ? var.ami_id : data.aws_ssm_parameter.al2023[0].value
  instance_profile_name      = var.create_instance_profile ? aws_iam_instance_profile.ssm[0].name : var.existing_instance_profile_name
  nginx_image                = var.nginx_image
  placeholder_image          = var.placeholder_image
  rabbitmq_image             = var.rabbitmq_image
  redis_image                = var.redis_image
  mysql_image                = var.mysql_image
  rabbitmq_tls               = var.rabbitmq_tls
  rabbitmq_client_port       = var.rabbitmq_client_port
  rabbitmq_management_port   = var.rabbitmq_management_port
  redis_port                 = var.redis_port
  mysql_port                 = var.mysql_port
  owner                      = var.owner
  team                       = var.team
  environment                = var.environment
  tags                       = var.additional_tags
}

module "alb" {
  source = "./modules/alb"

  name_prefix                      = var.name_prefix
  vpc_id                           = module.network.vpc_id
  public_subnet_ids                = module.network.public_subnet_ids
  mz_subnet_ids                    = module.network.mz_subnet_ids
  external_security_group_id       = module.security.external_alb_id
  internal_security_group_id       = module.security.internal_alb_id
  external_certificate_arn         = var.external_certificate_arn
  internal_certificate_arn         = var.internal_certificate_arn
  allow_insecure_external_listener = var.allow_insecure_external_listener
  allow_insecure_internal_listener = var.allow_insecure_internal_listener
  deletion_protection              = var.deletion_protection
  dmz_instance_ids                 = local.dmz_instance_ids
  dmz_port                         = local.dmz_web.container_port
  dmz_health_check_path            = local.dmz_web.health_check_path
  internal_targets                 = local.internal_targets
  internal_instance_ids            = local.internal_instance_ids
  tags                             = var.additional_tags
}

module "files" {
  source = "../modules/s3"

  bucket_name        = var.bucket_name
  versioning_enabled = true
  team               = var.team
  owner              = var.owner
  environment        = var.environment
  additional_tags    = var.additional_tags
}

data "aws_iam_policy_document" "bucket_tls" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      module.files.bucket_arn,
      "${module.files.bucket_arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tls_only" {
  bucket = module.files.bucket_name
  policy = data.aws_iam_policy_document.bucket_tls.json

  depends_on = [module.files]
}

resource "terraform_data" "guards" {
  input = var.name_prefix

  lifecycle {
    precondition {
      condition     = length(local.role_keys["dmz_web"]) == 1 && length(local.role_keys["mz_web"]) == 1
      error_message = "Exactly one dmz_web tier and exactly one mz_web tier are required."
    }
    precondition {
      condition     = length(local.role_keys["app"]) >= 1 && length(local.role_keys["reporting_app"]) >= 1 && length(local.role_keys["rabbitmq"]) >= 1 && length(local.role_keys["redis"]) >= 1 && length(local.role_keys["mysql"]) >= 1
      error_message = "At least one app, reporting_app, rabbitmq, redis, and mysql tier is required. Extra app keys are allowed."
    }
    precondition {
      condition     = length([for key, tier in var.tiers : key if contains(["app", "reporting_app"], tier.role) && tier.default_target]) == 1
      error_message = "Exactly one app or reporting_app tier must set default_target = true."
    }
    precondition {
      condition = alltrue([
        for key, tier in var.tiers : length(tier.path_patterns) > 0
        if contains(["app", "reporting_app"], tier.role) && !tier.default_target
      ])
      error_message = "Every app or reporting tier that is not the default target needs path_patterns."
    }
    precondition {
      condition = alltrue([
        for key, tier in var.tiers : tier.data_volume_gb > 0
        if tier.role == "mysql"
      ])
      error_message = "Every mysql tier needs data_volume_gb greater than 0."
    }
    precondition {
      condition = alltrue([
        for key, tier in var.tiers : contains(["dmz_web", "mz_web", "app", "reporting_app"], tier.role) ? tier.container_port != null : true
      ])
      error_message = "Web and app tiers need container_port."
    }
    precondition {
      condition = alltrue([
        for key, tier in var.tiers : contains(["dmz_web", "mz_web", "app", "reporting_app", "rabbitmq", "redis", "mysql"], tier.role)
      ])
      error_message = "role must be dmz_web, mz_web, app, reporting_app, rabbitmq, redis, or mysql."
    }
    precondition {
      condition = alltrue([
        for key, tier in var.tiers : tier.count >= 1 && tier.root_volume_gb >= 8 && tier.root_volume_gb <= 200
      ])
      error_message = "Each tier needs count of at least 1 and a root volume from 8 to 200 GiB. The shared EC2 module's 100 GiB cap is not copied."
    }
    precondition {
      condition     = (var.create_instance_profile && var.existing_instance_profile_name == null) || (!var.create_instance_profile && var.existing_instance_profile_name != null)
      error_message = "Set create_instance_profile true, or set existing_instance_profile_name. Do not set both."
    }
    precondition {
      condition     = alltrue([for key, tier in var.tiers : length("${var.name_prefix}-${key}") <= 32 && can(regex("^[a-z0-9-]+$", key))])
      error_message = "Tier keys must be lowercase. name_prefix plus the key must be 32 characters or fewer."
    }
    precondition {
      condition     = can(cidrsubnet(var.vpc_cidr, var.subnet_newbits, 7))
      error_message = "vpc_cidr is too small for eight subnets at this subnet_newbits."
    }
    precondition {
      condition     = alltrue([for port in concat(var.rabbitmq_cluster_ports, var.redis_cluster_ports, [var.rabbitmq_client_port, var.rabbitmq_management_port, var.redis_port, var.mysql_port]) : port > 0 && port < 65536])
      error_message = "Ports must be between 1 and 65535."
    }
    precondition {
      condition = alltrue([
        for key, tier in var.tiers : startswith(tier.health_check_path, "/")
        if contains(["dmz_web", "app", "reporting_app"], tier.role)
      ])
      error_message = "health_check_path must start with /."
    }
  }
}

locals {
  role_keys = {
    for role in ["dmz_web", "mz_web", "app", "reporting_app", "rabbitmq", "redis", "mysql"] :
    role => [for key, tier in var.tiers : key if tier.role == role]
  }

  dmz_key = one(local.role_keys["dmz_web"])
  mz_key  = one(local.role_keys["mz_web"])
  dmz_web = var.tiers[local.dmz_key]
  mz_web  = var.tiers[local.mz_key]

  app_ports       = [for key, tier in var.tiers : tier.container_port if tier.role == "app"]
  reporting_ports = [for key, tier in var.tiers : tier.container_port if tier.role == "reporting_app"]

  subnet_ids_by_tier = {
    public = module.network.public_subnet_ids
    mz     = module.network.mz_subnet_ids
    data   = module.network.data_subnet_ids
  }

  security_group_ids_by_role = {
    dmz_web       = module.security.dmz_web_id
    mz_web        = module.security.mz_web_id
    app           = module.security.app_id
    reporting_app = module.security.reporting_id
    rabbitmq      = module.security.rabbitmq_id
    redis         = module.security.redis_id
    mysql         = module.security.mysql_id
  }

  internal_targets = {
    for key, tier in var.tiers : key => {
      port              = tier.container_port
      health_check_path = tier.health_check_path
      path_patterns     = tier.path_patterns
      default_target    = tier.default_target
    } if contains(["app", "reporting_app"], tier.role)
  }

  dmz_instance_ids = {
    for index in range(local.dmz_web.count) :
    "${local.dmz_key}-${index}" => module.compute.instance_ids["${local.dmz_key}-${index}"]
  }

  internal_instance_ids = {
    for key, tier in var.tiers : key => {
      for index in range(tier.count) :
      "${key}-${index}" => module.compute.instance_ids["${key}-${index}"]
    } if contains(["app", "reporting_app"], tier.role)
  }
}
