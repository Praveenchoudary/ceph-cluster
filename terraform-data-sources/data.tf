# Fetch the latest Amazon Linux 2023 AMI (don't hardcode it!)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Fetch the existing default VPC
data "aws_vpc" "default" {
  default = true
}

# Fetch subnets inside that default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Fetch the current AWS account ID
data "aws_caller_identity" "current" {}

# Fetch available Availability Zones in the region
data "aws_availability_zones" "available" {
  state = "available"
}
