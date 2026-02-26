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