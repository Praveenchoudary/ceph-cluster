# depends_on: explicitly declares a dependency Terraform cannot infer automatically

resource "aws_security_group" "web_sg" {
  name        = "web-sg-demo"
  description = "Allow SSH and HTTP"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
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
}

resource "aws_instance" "web" {
  ami           = "ami-0f5ee92e2d63afc18"
  instance_type = "t2.micro"

  # Not strictly required here since vpc_security_group_ids would already
  # create an implicit dependency - shown for demonstration purposes.
  depends_on = [aws_security_group.web_sg]

  tags = {
    Name = "web-depends-on-demo"
  }
}

output "instance_id" {
  value = aws_instance.web.id
}
