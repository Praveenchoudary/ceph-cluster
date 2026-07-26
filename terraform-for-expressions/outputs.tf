output "upper_environments" {
  value = local.upper_environments
}

output "env_name_lengths" {
  value = local.env_name_lengths
}

output "non_dev_environments" {
  value = local.non_dev_environments
}

output "instance_type_list" {
  value = local.instance_type_list
}

output "port_descriptions" {
  value = local.port_descriptions
}

output "instance_ids" {
  value = { for k, v in aws_instance.web : k => v.id }
}
