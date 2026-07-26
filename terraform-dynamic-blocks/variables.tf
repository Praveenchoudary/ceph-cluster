variable "ingress_ports" {
  description = "List of ports to allow inbound traffic on"
  type        = list(number)
  default     = [22, 80, 443]
}
