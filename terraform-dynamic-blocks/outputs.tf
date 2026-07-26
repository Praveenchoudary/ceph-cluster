output "security_group_id" {
  value = aws_security_group.web_sg.id
}

output "instance_id" {
  value = aws_instance.web.id
}

output "ingress_ports_used" {
  value = var.ingress_ports
}
