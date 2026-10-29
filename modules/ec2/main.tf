# Asks AWS which Amazon Linux 2023 x86_64 AMI is current in the caller's
# region. The parameter value is an AMI ID. It is not hardcoded, so the same
# module works in more than one region. AWS updates this parameter when a
# new AMI is published, so a later plan can propose replacing the instance.
data "aws_ssm_parameter" "al2023_ami" {
  count = var.ami_type == "amazon_linux" ? 1 : 0

  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Asks AWS for Canonical's latest Ubuntu 24.04 LTS server image in this
# region. most_recent picks the newest match. The owner ID is Canonical's
# official AWS account. No AMI ID is hardcoded.
data "aws_ami" "ubuntu" {
  count = var.ami_type == "ubuntu" ? 1 : 0

  most_recent = true
  owners      = ["099720109477"]

  filter {
    name = "name"
    values = [
      "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-????????",
      "ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-????????",
    ]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  selected_ami = var.ami_type == "ubuntu" ? data.aws_ami.ubuntu[0].id : data.aws_ssm_parameter.al2023_ami[0].value

  tags = merge(var.additional_tags, {
    Name        = var.name
    Owner       = var.owner
    Team        = var.team
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_instance" "this" {
  ami           = local.selected_ami
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  vpc_security_group_ids = var.security_group_ids

  # Hardcoded off. Omitting this argument would follow the subnet setting,
  # and a default-VPC subnet often assigns a public IPv4 address (billable).
  associate_public_ip_address = false

  # Detailed monitoring is a paid option. Basic monitoring stays on.
  monitoring = false

  key_name = var.key_name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # T3 unlimited mode can add CPU-credit charges. Standard mode throttles
  # instead. Non-burstable types reject this block, so it is set only for
  # instance types whose name starts with "t".
  dynamic "credit_specification" {
    for_each = can(regex("^t[0-9]", var.instance_type)) ? [1] : []

    content {
      cpu_credits = "standard"
    }
  }

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true

    tags = local.tags
  }

  tags = local.tags
}
