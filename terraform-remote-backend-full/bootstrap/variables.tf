variable "aws_region" {
  description = "AWS region for state resources"
  type        = string
  default     = "ap-south-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state"
  type        = string
  default     = "mycompany-terraform-state-prod"   # CHANGE THIS to something unique
}

variable "lock_table_name" {
  description = "DynamoDB table name for state locking"
  type        = string
  default     = "terraform-locks"
}
