output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "nat_gateway_id" {
  value = aws_nat_gateway.nat.id
}

output "public_web_public_ip" {
  value = aws_instance.public_web.public_ip
}

output "private_app_private_ip" {
  value = aws_instance.private_app.private_ip
}
