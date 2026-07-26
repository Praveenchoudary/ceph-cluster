############################################
# Simple output - a single attribute
############################################
output "instance_id" {
  description = "The ID of the created EC2 instance"
  value       = aws_instance.web.id
}

############################################
# Output referencing a local value directly
############################################
output "name_prefix_used" {
  description = "The computed name prefix used across resources"
  value       = local.name_prefix
}

############################################
# Output that is a whole object/map
############################################
output "instance_summary" {
  description = "Key details about the instance in one object"
  value = {
    id            = aws_instance.web.id
    public_ip     = aws_instance.web.public_ip
    instance_type = aws_instance.web.instance_type
    tags          = aws_instance.web.tags
  }
}

############################################
# Sensitive output - value hidden from CLI output
############################################
output "security_group_id" {
  description = "Security group ID - marked sensitive just for demonstration"
  value       = aws_security_group.web_sg.id
  sensitive   = true
}
