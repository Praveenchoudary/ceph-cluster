resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  subnet_id     = data.aws_subnets.default.ids[0]

  tags = {
    Name = "web-using-data-source"
  }
}
