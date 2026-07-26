resource "aws_security_group" "web_sg" {
  name        = "provisioner-demo-sg"
  description = "Allow SSH and HTTP"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # tighten to your IP in real use
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  ami                    = "ami-0f5ee92e2d63afc18" # Amazon Linux 2023, verify current for your region
  instance_type          = "t2.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name = "provisioner-demo-ec2"
  }

  # ---------- Connection block: how Terraform SSHes into this instance ----------
  connection {
    type        = "ssh"
    user        = "ec2-user"          # "ubuntu" if using an Ubuntu AMI instead
    private_key = file(var.private_key_path)
    host        = self.public_ip
  }

  # ---------- file: copies a local file onto the EC2 instance ----------
  provisioner "file" {
    source      = "${path.module}/nginx.conf"
    destination = "/tmp/nginx.conf"
  }

  # ---------- remote-exec: runs commands ON the EC2 instance itself ----------
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y nginx",
      "sudo cp /tmp/nginx.conf /etc/nginx/conf.d/demo.conf",
      "sudo systemctl start nginx",
      "sudo systemctl enable nginx"
    ]
  }

  # ---------- local-exec: runs a command on YOUR machine (not the EC2) ----------
  provisioner "local-exec" {
    command = "echo Instance ${self.id} is up with public IP ${self.public_ip} >> instance_log.txt"
  }
}
