resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type

  tags = {
    Name        = "${var.env}-ec2"
    Environment = var.env
  }
}
