variable "vpc_id" {
  description = "VPC where the security group will be created."
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR blocks permitted for SSH access."
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to the security group."
  type        = map(string)
  default     = {}
}
