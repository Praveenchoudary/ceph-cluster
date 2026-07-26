resource "aws_instance" "web" {
  ami           = "ami-0f5ee92e2d63afc18" # verify current AMI for your region
  instance_type = var.instance_type

  tags = {
    Name        = "${var.environment}-github-actions-demo"
    Environment = var.environment
    ManagedBy   = "github-actions"
  }
}
