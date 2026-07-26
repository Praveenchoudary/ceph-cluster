resource "aws_instance" "my_first_ec2" {
  ami           = "ami-0f5ee92e2d63afc18"   # Amazon Linux 2023, ap-south-1 - verify it's current
  instance_type = "t2.micro"

  tags = {
    Name = "my-first-terraform-ec2"
  }
}
