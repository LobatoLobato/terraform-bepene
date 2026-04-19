locals {
  replicas_sa_east_1 = { for r in var.replicas : r.subdomain => r if r.region == "sa-east-1" }
  replicas_us_east_1 = { for r in var.replicas : r.subdomain => r if r.region == "us-east-1" }
}

data "aws_iam_role" "budgets_role" {
  name = "BudgetsRole"
}

resource "aws_budgets_budget" "monthly_cost_budget" {
  name              = "BepeneMonthlyBudget"
  budget_type       = "COST"
  limit_amount      = "50.0"
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-01-31_21:00"

  filter_expression {
    not {
      dimensions {
        key    = "RECORD_TYPE"
        values = ["Credit", "Refund"]
      }
    }
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.replicas[0].notification_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.replicas[0].notification_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 85
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.replicas[0].notification_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.replicas[0].notification_email]
  }
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

  instance_type = each.value.instance_type

  accelerator = {
    arn = aws_globalaccelerator_accelerator.accelerator.arn
    ips = aws_globalaccelerator_accelerator.accelerator.ip_sets
  }

  vpn_server_port = each.value.vpn_server_port

  public_key = each.value.public_key

  notification_email = each.value.notification_email

  budget_name      = aws_budgets_budget.monthly_cost_budget.name
  budgets_role_arn = data.aws_iam_role.budgets_role.arn

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

  instance_type = each.value.instance_type

  accelerator = {
    arn = aws_globalaccelerator_accelerator.accelerator.arn
    ips = aws_globalaccelerator_accelerator.accelerator.ip_sets
  }

  vpn_server_port = each.value.vpn_server_port

  public_key = each.value.public_key

  notification_email = each.value.notification_email

  budget_name      = aws_budgets_budget.monthly_cost_budget.name
  budgets_role_arn = data.aws_iam_role.budgets_role.arn

}

locals {
  gcp_replicas_southamerica_east1 = { for r in var.gcp_replicas : r.subdomain => r if r.gcp_region == "southamerica-east1" }
}

module "bpn_gcp_southamerica_east1" {

  for_each = local.gcp_replicas_southamerica_east1

  source = "./modules/bpn_gcp"

  providers = {
    google = google.southamerica_east1
    aws    = aws.sa_east_1
  }

  zone_id   = each.value.zone_id
  domain    = each.value.domain
  subdomain = each.value.subdomain

  gcp_region = each.value.gcp_region
  gcp_zone   = each.value.gcp_zone

  machine_type = each.value.machine_type

  vpn_server_port = each.value.vpn_server_port

  public_key = each.value.public_key

  notification_email = each.value.notification_email

  billing_account_id = each.value.billing_account_id
}