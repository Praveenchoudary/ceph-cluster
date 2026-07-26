resource "aws_instance" "web" {
  ami           = "ami-0f5ee92e2d63afc18" # verify current AMI for your region
  instance_type = "t2.micro"

  tags = {
    Name = "terraform-state-demo"
  }
}
