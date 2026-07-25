output "current_workspace" {
  value = terraform.workspace
}

output "instance_id" {
  value = module.ec2.instance_id
}

output "instance_name" {
  value = module.ec2.instance_name
}
