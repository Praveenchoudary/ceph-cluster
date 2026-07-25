# provider (meta-argument): selects which provider configuration a resource uses
# Useful for multi-region or multi-account setups

resource "aws_instance" "web_mumbai" {
  ami           = "ami-0f5ee92e2d63afc18"
  instance_type = "t2.micro"

  tags = {
    Name = "web-mumbai"
  }
}

resource "aws_instance" "web_us" {
  provider      = aws.us_east
  ami           = "ami-0c101f26f147fa7fd"
  instance_type = "t2.micro"

  tags = {
    Name = "web-us-east"
  }
}

output "mumbai_instance_id" {
  value = aws_instance.web_mumbai.id
}

output "us_east_instance_id" {
  value = aws_instance.web_us.id
}
