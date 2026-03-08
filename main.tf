locals {
  replicas_sa_east_1 = { for r in var.replicas : r.subdomain => r if r.region == "sa-east-1" }
  replicas_us_east_1 = { for r in var.replicas : r.subdomain => r if r.region == "us-east-1" }
}

resource "aws_globalaccelerator_accelerator" "accelerator" {
  name            = "Bepene"
  ip_address_type = "IPV4"
  enabled         = true
  attributes {
    flow_logs_enabled = false
  }

}

module "bpn_sa_east_1" {

  for_each = local.replicas_sa_east_1

  source = "./modules/bpn"

  providers = {
    aws = aws.sa_east_1
  }

  zone_id   = each.value.zone_id
  domain    = each.value.domain
  subdomain = each.value.subdomain

  region = each.value.region

  accelerator = {
    arn = aws_globalaccelerator_accelerator.accelerator.arn
    ips = aws_globalaccelerator_accelerator.accelerator.ip_sets
  }

  vpn_server_port = each.value.vpn_server_port

  public_key = each.value.public_key

  notification_email = each.value.notification_email

}

module "bpn_us_east_1" {

  for_each = local.replicas_us_east_1

  source = "./modules/bpn"

  providers = {
    aws = aws.us_east_1
  }

  zone_id   = each.value.zone_id
  domain    = each.value.domain
  subdomain = each.value.subdomain

  region = each.value.region

  accelerator = {
    arn = aws_globalaccelerator_accelerator.accelerator.arn
    ips = aws_globalaccelerator_accelerator.accelerator.ip_sets
  }

  vpn_server_port = each.value.vpn_server_port

  public_key = each.value.public_key

  notification_email = each.value.notification_email

}