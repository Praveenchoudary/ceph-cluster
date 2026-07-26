locals {
  ############################################
  # for expression on a LIST -> produces a LIST
  # syntax: [for item in list : expression]
  ############################################
  upper_environments = [for env in var.environments : upper(env)]
  # -> ["DEV", "QA", "PROD"]

  ############################################
  # for expression on a LIST -> produces a MAP
  # syntax: {for item in list : key => value}
  ############################################
  env_name_lengths = { for env in var.environments : env => length(env) }
  # -> { dev = 3, qa = 2, prod = 4 }

  ############################################
  # for expression with a FILTER (if condition)
  ############################################
  non_dev_environments = [for env in var.environments : env if env != "dev"]
  # -> ["qa", "prod"]

  ############################################
  # for expression on a MAP -> produces a LIST
  # syntax: [for key, value in map : expression]
  ############################################
  instance_type_list = [for env, size in var.instance_sizes : "${env}=${size}"]
  # -> ["dev=t2.micro", "qa=t3.small", "prod=t3.large"]

  ############################################
  # for expression building tag maps dynamically per port
  ############################################
  port_descriptions = { for p in var.ports : p => "allow-port-${p}" }
  # -> { 22 = "allow-port-22", 80 = "allow-port-80", 443 = "allow-port-443" }
}

# Using for_each (loop that CREATES resources) together with a `for` expression
# (loop that TRANSFORMS a value) - the for expression prepares the data,
# for_each uses it to create actual resources.
resource "aws_security_group" "web_sg" {
  name = "for-expression-demo-sg"

  dynamic "ingress" {
    for_each = var.ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = local.port_descriptions[ingress.value]
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
  for_each      = var.instance_sizes
  ami           = "ami-0f5ee92e2d63afc18" # verify current AMI for your region
  instance_type = each.value

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name = "${each.key}-web-server"
  }
}
