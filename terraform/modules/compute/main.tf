# Security Group
resource "aws_security_group" "unimart" {
  name_prefix = "unimart-${var.environment}-"
  description = "UniMart application security group"
  vpc_id      = var.vpc_id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "unimart-${var.environment}-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

# SSH Key Pair
resource "aws_key_pair" "deployer" {
  key_name   = "unimart-${var.environment}-key"
  public_key = var.ssh_public_key
}

# Latest Ubuntu 24.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Instance
resource "aws_instance" "unimart" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.unimart.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user-data.sh", {
    docker_username = var.docker_username
  })

  tags = { Name = "unimart-${var.environment}" }

  lifecycle {
    ignore_changes = [ami]
  }
}

# Elastic IP
resource "aws_eip" "unimart" {
  instance = aws_instance.unimart.id
  domain   = "vpc"

  tags = { Name = "unimart-${var.environment}-eip" }
}
