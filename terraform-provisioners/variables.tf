variable "key_name" {
  description = "Existing EC2 key pair name for SSH access"
  type        = string
}

variable "private_key_path" {
  description = "Path to the local .pem private key file matching key_name"
  type        = string
}
