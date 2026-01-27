data "aws_vpc" "default" {
  count   = var.vpc_id == null ? 1 : 0
  default = true
}

locals {
  effective_vpc_id = var.vpc_id != null ? var.vpc_id : data.aws_vpc.default[0].id
}

data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [local.effective_vpc_id]
  }
}

locals {
  effective_subnet_id = var.subnet_id != null ? var.subnet_id : data.aws_subnets.selected.ids[0]
  common_tags = merge({
    Project     = "n8n-poc"
    Environment = "sandbox"
  }, var.tags)
}

module "network" {
  source           = "./modules/network"
  vpc_id           = local.effective_vpc_id
  allowed_ssh_cidr = var.allowed_ssh_cidr
  tags             = local.common_tags
}

module "compute" {
  source            = "./modules/compute"
  instance_type     = var.instance_type
  root_volume_size  = var.root_volume_size
  subnet_id         = local.effective_subnet_id
  security_group_id = module.network.security_group_id
  ssh_key_name      = var.ssh_key_name
  enable_elastic_ip = var.enable_elastic_ip
  tags              = local.common_tags
  user_data         = var.user_data
}

module "dns" {
  source      = "./modules/dns"
  zone_id     = var.hosted_zone_id
  record_name = var.domain_name
  target_ip   = module.compute.public_ip
}
