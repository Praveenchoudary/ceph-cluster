variable "environments" {
  description = "List of environment names"
  type        = list(string)
  default     = ["dev", "qa", "prod"]
}

variable "instance_sizes" {
  description = "Map of environment to instance type"
  type        = map(string)
  default = {
    dev  = "t2.micro"
    qa   = "t3.small"
    prod = "t3.large"
  }
}

variable "ports" {
  description = "List of ports"
  type        = list(number)
  default     = [22, 80, 443]
}
