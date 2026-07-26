terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # NOTE: no backend block here on purpose.
  # This project creates the bucket/table that OTHER projects will use as their backend.
  # It uses LOCAL state itself.
}
