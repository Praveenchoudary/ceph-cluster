# Security group allowing SSH/HTTP into the public EC2 instance
resource "aws_security_group" "public_web" {
  name   = "${var.environment}-public-web-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # tighten to your IP in real use
  }

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

  tags = {
    Name = "${var.environment}-public-web-sg"
  }
}

# A simple EC2 instance placed in the PUBLIC subnet, reachable from the internet
resource "aws_instance" "public_web" {
  ami                    = "ami-0f5ee92e2d63afc18" # verify current AMI for your region
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.public_web.id]

  tags = {
    Name = "${var.environment}-public-web"
  }
}

# A simple EC2 instance placed in the PRIVATE subnet - no public IP,
# reaches the internet outbound only via the NAT Gateway
resource "aws_instance" "private_app" {
  ami           = "ami-0f5ee92e2d63afc18"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private[0].id

  vpc_security_group_ids = [aws_security_group.public_web.id]

  tags = {
    Name = "${var.environment}-private-app"
  }
}
