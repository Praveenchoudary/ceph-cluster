resource "aws_security_group" "web_sg" {
  name        = "web-sg-dynamic-demo"
  description = "Security group generated using a dynamic block"

  dynamic "ingress" {
    for_each = var.ingress_ports
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

  tags = {
    Name = "web-sg-dynamic-demo"
  }
}

resource "aws_instance" "web" {
  ami                    = "ami-0f5ee92e2d63afc18" # verify current AMI for your region
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name = "web-dynamic-sg-demo"
  }
}
