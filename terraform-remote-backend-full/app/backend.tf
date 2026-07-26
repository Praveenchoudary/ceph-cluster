terraform {
  backend "s3" {
    bucket         = "mycompany-terraform-state-prod"   # must match bootstrap's state_bucket_name
    key            = "prod/app/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"                  # must match bootstrap's lock_table_name
    encrypt        = true
  }
}
