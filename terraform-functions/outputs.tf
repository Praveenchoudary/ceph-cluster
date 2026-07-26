output "instance_name" {
  value = local.instance_name
}

output "default_tags" {
  value = local.default_tags
}

output "subnet_count" {
  value = length(var.subnet_cidrs)
}

output "subnet_names" {
  value = aws_subnet.public[*].tags["Name"]
}

output "instance_type_from_env" {
  value = local.instance_type_from_env
}

output "final_instance_type" {
  value = local.final_instance_type
}

output "instance_id" {
  value = aws_instance.web.id
}

output "iam_policy_json" {
  value = aws_iam_policy.example.policy
}
