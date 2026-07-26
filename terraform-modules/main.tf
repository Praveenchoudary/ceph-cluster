# Calling the same ec2 module twice, with different inputs each time

module "dev_server" {
  source        = "./modules/ec2"
  instance_name = "dev-web-server"
  ami_id        = "ami-0f5ee92e2d63afc18" # verify current AMI for your region
  instance_type = "t2.micro"
}

module "prod_server" {
  source        = "./modules/ec2"
  instance_name = "prod-web-server"
  ami_id        = "ami-0f5ee92e2d63afc18"
  instance_type = "t3.medium"
}
