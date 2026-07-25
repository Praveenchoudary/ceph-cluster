# for_each: creates multiple copies of a resource from a map/set, indexed by key (safer than count)

resource "aws_instance" "web" {
  for_each = {
    dev  = "t2.micro"
    prod = "t3.medium"
  }

  ami           = "ami-0f5ee92e2d63afc18"
  instance_type = each.value

  tags = {
    Name        = "web-${each.key}"
    Environment = each.key
  }
}

output "instance_ids" {
  value = { for k, v in aws_instance.web : k => v.id }
}
