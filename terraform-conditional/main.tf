resource "aws_instance" "web" {

  ami = "ami-0f58b397bc5c1f2e8"   # Amazon Linux 2023 (Example - ap-south-1)

  instance_type = var.environment == "prod" ? "t3.large" : "t2.micro"

  tags = {
    Name = "${var.environment}-web-server"
  }

}