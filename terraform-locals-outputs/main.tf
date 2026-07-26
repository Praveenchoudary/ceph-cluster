############################################
# locals: computed/derived values used multiple times in this file
############################################
locals {
  # Simple local - build a consistent name once
  name_prefix = "${var.environment}-${var.app_name}"

  # Local built from a function - common tags reused across every resource
  common_tags = {
    Environment = var.environment
    Application = var.app_name
    ManagedBy   = "terraform"
  }

  # Local using a conditional - pick instance type based on environment
  instance_type = var.environment == "prod" ? "t3.medium" : "t2.micro"

  # Local combining several other locals/variables together
  full_config = {
    name          = "${local.name_prefix}-web"
    instance_type = local.instance_type
    tags          = local.common_tags
  }
}

resource "aws_security_group" "web_sg" {
  name = "${local.name_prefix}-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_instance" "web" {
  ami                    = "ami-0f5ee92e2d63afc18" # verify current AMI for your region
  instance_type          = local.full_config.instance_type
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = merge(local.common_tags, {
    Name = local.full_config.name
  })
}
