output "ami_id_used" {
  value = data.aws_ami.amazon_linux.id
}

output "default_vpc_id" {
  value = data.aws_vpc.default.id
}

output "default_subnet_ids" {
  value = data.aws_subnets.default.ids
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "availability_zones" {
  value = data.aws_availability_zones.available.names
}

output "instance_id" {
  value = aws_instance.web.id
}
