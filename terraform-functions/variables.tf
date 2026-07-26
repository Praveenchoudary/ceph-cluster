variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "payments"
}

variable "subnet_cidrs" {
  description = "List of subnet CIDRs - length() drives how many subnets get created"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "instance_sizes" {
  description = "Map of environment -> instance type"
  type        = map(string)
  default = {
    dev  = "t2.micro"
    prod = "t3.large"
  }
}

variable "custom_instance_type" {
  description = "Optional override for instance type - null means use lookup/coalesce default"
  type        = string
  default     = null
}
