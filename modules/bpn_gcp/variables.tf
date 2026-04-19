variable "domain" {
  description = "The domain to use for the subdomain"
  type        = string
}

variable "subdomain" {
  description = "The subdomain to use"
  type        = string
}

variable "zone_id" {
  description = "The Route53 zone ID where the record will be created"
  type        = string
}

variable "vpn_server_port" {
  description = "The port for the VPN server"
  type        = number
  default     = 443
}

variable "public_key" {
  description = "The public key for SSH access"
  type        = string
}

variable "notification_email" {
  description = "Email address to receive billing notifications"
  type        = string
}

variable "gcp_region" {
  description = "GCP region to deploy the resources"
  type        = string
}

variable "gcp_zone" {
  description = "GCP zone to deploy the compute instance"
  type        = string
}

variable "machine_type" {
  description = "GCE machine type to use for the VPN server"
  type        = string
  default     = "e2-micro"
}

variable "billing_account_id" {
  description = "GCP billing account ID for budget alerts"
  type        = string
}
