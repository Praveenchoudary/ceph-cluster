resource "aws_security_group" "web_sg" {
  name = "${var.environment}-web-sg"

  dynamic "ingress" {
    for_each = var.allowed_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  count                  = var.instance_count
  ami                    = "ami-0f5ee92e2d63afc18" # verify current AMI for your region
  instance_type           = var.instance_type_map[var.environment]
  monitoring              = var.enable_monitoring
  vpc_security_group_ids  = [aws_security_group.web_sg.id]

  tags = {
    Name        = "${var.environment}-${var.server_config.name}-${count.index}"
    Environment = var.environment
  }
}
