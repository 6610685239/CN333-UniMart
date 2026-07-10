variable "environment" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "ssh_public_key" {
  type      = string
  sensitive = true
}

variable "allowed_ssh_cidr" {
  type = string
}

variable "docker_username" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}
