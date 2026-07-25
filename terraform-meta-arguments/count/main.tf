# count: creates multiple copies of a resource, indexed numerically (0, 1, 2 ...)

resource "aws_instance" "web" {
  count         = 3
  ami           = "ami-0f5ee92e2d63afc18"
  instance_type = "t2.micro"

  tags = {
    Name = "web-${count.index}"
  }
}

output "instance_ids" {
  value = aws_instance.web[*].id
}
