output "region_used" {
  value = var.aws_region
}

output "environment" {
  value = var.environment
}

output "instance_type_chosen" {
  value = var.instance_type_map[var.environment]
}

output "instance_ids" {
  value = aws_instance.web[*].id
}

# Sensitive values must be explicitly marked sensitive in outputs too,
# otherwise Terraform will error when you try to output a sensitive variable directly.
output "db_password_is_set" {
  value     = var.db_password
  sensitive = true
}
