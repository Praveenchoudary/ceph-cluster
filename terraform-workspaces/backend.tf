# Optional: if using a remote backend, Terraform automatically stores
# a separate state file per workspace under this same backend config.
#
# terraform {
#   backend "s3" {
#     bucket         = "mycompany-terraform-state-prod"
#     key            = "workspaces-demo/terraform.tfstate"
#     region         = "ap-south-1"
#     dynamodb_table = "terraform-locks"
#     encrypt        = true
#   }
# }
