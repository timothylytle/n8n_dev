variable "zone_id" {
  description = "Route53 hosted zone ID."
  type        = string
}

variable "record_name" {
  description = "Record name to create (FQDN)."
  type        = string
}

variable "target_ip" {
  description = "IPv4 address the record should point to."
  type        = string
}

variable "record_ttl" {
  description = "TTL for the DNS record."
  type        = number
  default     = 300
}

variable "record_type" {
  description = "DNS record type."
  type        = string
  default     = "A"
}

variable "tags" {
  description = "Tags applied to the Route53 record (where supported)."
  type        = map(string)
  default     = {}
}
