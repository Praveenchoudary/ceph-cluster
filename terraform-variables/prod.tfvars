# NOT auto-loaded - must be passed explicitly:
# terraform apply -var-file="prod.tfvars"
environment       = "prod"
instance_count    = 3
enable_monitoring = true
