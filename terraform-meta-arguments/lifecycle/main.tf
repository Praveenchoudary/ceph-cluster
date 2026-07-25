# lifecycle: controls create/update/destroy behavior for a resource

resource "aws_instance" "web" {
  ami           = "ami-0f5ee92e2d63afc18"
  instance_type = "t2.micro"

  tags = {
    Name = "web-lifecycle-demo"
  }

  lifecycle {
    # Blocks `terraform destroy` from deleting this resource.
    # Remove or comment this out before you actually want to destroy it.
    prevent_destroy = true

    # When replacement is required, create the new resource
    # before destroying the old one (avoids downtime).
    create_before_destroy = true

    # Ignore drift in tags - Terraform will not try to "fix"
    # tag changes made outside of Terraform.
    ignore_changes = [tags]
  }
}

output "instance_id" {
  value = aws_instance.web.id
}
