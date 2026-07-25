# Default provider (no alias) - used unless a resource specifies otherwise
provider "aws" {
  region = "ap-south-1"
}

# Aliased provider - used only when a resource sets provider = aws.us_east
provider "aws" {
  alias  = "us_east"
  region = "us-east-1"
}
