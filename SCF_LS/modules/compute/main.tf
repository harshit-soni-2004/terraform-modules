locals {
  subnet_tier = {
    dmz_web       = "public"
    mz_web        = "mz"
    app           = "mz"
    reporting_app = "mz"
    rabbitmq      = "data"
    redis         = "data"
    mysql         = "data"
  }

  instances = merge([
    for key, tier in var.tiers : {
      for index in range(tier.count) :
      "${key}-${index}" => {
        tier_key  = key
        role      = tier.role
        index     = index
        type      = tier.instance_type
        root_gb   = tier.root_volume_gb
        data_gb   = tier.data_volume_gb
        port      = tier.container_port
        subnet_id = var.subnet_ids_by_tier[local.subnet_tier[tier.role]][index % length(var.subnet_ids_by_tier[local.subnet_tier[tier.role]])]
      }
    }
  ]...)
}

resource "aws_instance" "this" {
  for_each = local.instances

  ami                         = var.ami_id
  instance_type               = each.value.type
  subnet_id                   = each.value.subnet_id
  vpc_security_group_ids      = [var.security_group_ids_by_role[each.value.role]]
  iam_instance_profile        = var.instance_profile_name
  associate_public_ip_address = false
  monitoring                  = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  dynamic "credit_specification" {
    for_each = can(regex("^t[0-9]", each.value.type)) ? [1] : []
    content {
      cpu_credits = "standard"
    }
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = each.value.root_gb
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/templates/user-data.sh.tftpl", {
    role                     = each.value.role
    tier_key                 = each.value.tier_key
    container_port           = coalesce(each.value.port, 0)
    nginx_image              = var.nginx_image
    placeholder_image        = var.placeholder_image
    rabbitmq_image           = var.rabbitmq_image
    redis_image              = var.redis_image
    mysql_image              = var.mysql_image
    rabbitmq_tls             = var.rabbitmq_tls ? "true" : "false"
    rabbitmq_client_port     = var.rabbitmq_client_port
    rabbitmq_management_port = var.rabbitmq_management_port
    redis_port               = var.redis_port
    mysql_port               = var.mysql_port
  })

  user_data_replace_on_change = true

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-${each.key}"
    Owner       = var.owner
    Team        = var.team
    Environment = var.environment
    ManagedBy   = "Terraform"
    Role        = each.value.role
  })

  lifecycle {
    precondition {
      condition     = contains(["dmz_web", "mz_web", "app", "reporting_app"], each.value.role) ? each.value.port != null : true
      error_message = "Web and app tiers need container_port."
    }
  }
}

resource "aws_ebs_volume" "mysql" {
  for_each = { for key, inst in local.instances : key => inst if inst.role == "mysql" }

  availability_zone = aws_instance.this[each.key].availability_zone
  size              = each.value.data_gb
  type              = "gp3"
  encrypted         = true

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-${each.key}-data"
    Owner       = var.owner
    Team        = var.team
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_volume_attachment" "mysql" {
  for_each = aws_ebs_volume.mysql

  device_name = "/dev/sdf"
  volume_id   = each.value.id
  instance_id = aws_instance.this[each.key].id
}
