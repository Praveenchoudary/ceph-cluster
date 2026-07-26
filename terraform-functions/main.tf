############################################
# join(): build consistent resource names
############################################
locals {
  instance_name = join("-", [var.environment, var.app_name, "web"])
  # e.g. "dev-payments-web"
}

############################################
# merge(): combine default tags with resource-specific tags
############################################
locals {
  default_tags = {
    ManagedBy = "terraform"
    Team      = "platform"
  }
}

############################################
# length(): make subnet count dynamic instead of hardcoded
############################################
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = merge(local.default_tags, { Name = "${var.environment}-vpc" })
}

resource "aws_subnet" "public" {
  count             = length(var.subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]

  tags = merge(local.default_tags, {
    # format(): build a padded, consistent name pattern
    Name = format("${var.environment}-subnet-%02d", count.index + 1)
  })
}

data "aws_availability_zones" "available" {
  state = "available"
}

############################################
# lookup(): safe map access with a fallback default
############################################
locals {
  instance_type_from_env = lookup(var.instance_sizes, var.environment, "t2.micro")
}

############################################
# coalesce(): pick the first non-null value
############################################
locals {
  final_instance_type = coalesce(var.custom_instance_type, local.instance_type_from_env)
}

############################################
# file(): inject a setup script without pasting it inline
############################################
resource "aws_instance" "web" {
  ami           = "ami-0f5ee92e2d63afc18" # verify current AMI for your region
  instance_type = local.final_instance_type
  subnet_id     = aws_subnet.public[0].id
  user_data     = file("${path.module}/setup.sh")

  tags = merge(local.default_tags, { Name = local.instance_name })
}

############################################
# jsonencode(): write IAM policy without manual JSON escaping
############################################
resource "aws_iam_policy" "example" {
  name = "${var.environment}-example-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = "*"
    }]
  })
}
