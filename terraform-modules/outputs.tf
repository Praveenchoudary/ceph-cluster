output "dev_instance_id" {
  value = module.dev_server.instance_id
}

output "dev_public_ip" {
  value = module.dev_server.public_ip
}

output "prod_instance_id" {
  value = module.prod_server.instance_id
}

output "prod_public_ip" {
  value = module.prod_server.public_ip
}
