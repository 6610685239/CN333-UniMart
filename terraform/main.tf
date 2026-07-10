module "networking" {
  source      = "./modules/networking"
  environment = var.environment
  aws_region  = var.aws_region
}

module "compute" {
  source = "./modules/compute"

  environment      = var.environment
  instance_type    = var.instance_type
  ssh_public_key   = var.ssh_public_key
  allowed_ssh_cidr = var.allowed_ssh_cidr
  docker_username  = var.docker_username

  vpc_id    = module.networking.vpc_id
  subnet_id = module.networking.public_subnet_id
}
