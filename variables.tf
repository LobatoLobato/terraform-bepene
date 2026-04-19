variable "replicas" {
  description = "List of replicas to create"
  type = list(object({
    domain             = string
    subdomain          = string
    region             = string
    instance_type      = optional(string, "t3.nano")
    zone_id            = string
    public_key         = string
    notification_email = string
    vpn_server_port    = number
  }))

  validation {
    condition     = alltrue([for r in var.replicas : contains(["sa-east-1", "us-east-1"], r.region)])
    error_message = "Region must be either sa-east-1 or us-east-1"
  }
}

variable "gcp_replicas" {
  description = "List of GCP replicas to create"
  type = list(object({
    domain             = string
    subdomain          = string
    gcp_region         = string
    gcp_zone           = string
    machine_type       = optional(string, "e2-micro")
    zone_id            = string
    public_key         = string
    notification_email = string
    vpn_server_port    = number
    billing_account_id = string
  }))
  default = []
}

variable "gcp_billing_project" {
  description = "GCP project ID to use for billing budgets and quota-based APIs"
  type        = string
}