# ---------- Simple string variable ----------
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

# ---------- String variable with validation ----------
variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment must be one of: dev, qa, prod."
  }
}

# ---------- Number variable ----------
variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 1
}

# ---------- Bool variable ----------
variable "enable_monitoring" {
  description = "Whether to enable detailed monitoring"
  type        = bool
  default     = false
}

# ---------- List variable ----------
variable "allowed_ports" {
  description = "List of ports to allow inbound"
  type        = list(number)
  default     = [22, 80]
}

# ---------- Map variable ----------
variable "instance_type_map" {
  description = "Map of environment to instance type"
  type        = map(string)
  default = {
    dev  = "t2.micro"
    qa   = "t3.small"
    prod = "t3.large"
  }
}

# ---------- Object variable (structured/complex type) ----------
variable "server_config" {
  description = "Structured server configuration"
  type = object({
    name          = string
    instance_type = string
    monitoring    = bool
  })
  default = {
    name          = "web-server"
    instance_type = "t2.micro"
    monitoring    = false
  }
}

# ---------- Sensitive variable (e.g. a password/secret) ----------
variable "db_password" {
  description = "Database password - never printed in plan/apply output"
  type        = string
  sensitive   = true
  default     = "changeme123"
}
