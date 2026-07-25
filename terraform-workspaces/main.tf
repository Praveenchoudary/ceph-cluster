module "ec2" {
  source        = "./modules/ec2"
  env           = terraform.workspace
  ami_id        = var.ami_id
  instance_type = var.instance_type
}
