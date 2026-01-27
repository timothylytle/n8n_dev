variable "aws_profile" {
  description = "AWS shared config/credentials profile that targets the sandbox account."
  type        = string
  default     = "sandbox"
}

variable "aws_region" {
  description = "AWS region for infrastructure deployment."
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for the n8n host."
  type        = string
  default     = "t3.small"
}

variable "root_volume_size" {
  description = "Size (GiB) of the EC2 root EBS volume."
  type        = number
  default     = 40
}

variable "hosted_zone_name" {
  description = "Route53 hosted zone name (e.g., example.com) to manage the n8n record."
  type        = string
}

variable "domain_name" {
  description = "Fully-qualified domain (e.g., n8n.example.com) pointing to the EC2 instance."
  type        = string
}

variable "letsencrypt_email" {
  description = "Contact email used for Let's Encrypt registration."
  type        = string
}

variable "ssh_key_name" {
  description = "Existing AWS EC2 key pair name for SSH access."
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "List of CIDR blocks permitted to access SSH on port 22."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "vpc_id" {
  description = "VPC ID to deploy into. Leave null to use the default VPC."
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Subnet ID for the EC2 instance. Leave null to use the first default subnet."
  type        = string
  default     = null
}

variable "enable_elastic_ip" {
  description = "Whether to allocate and associate an Elastic IP with the instance."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional resource tags."
  type        = map(string)
  default     = {}
}

variable "user_data" {
  description = "Rendered user data script to bootstrap the host (can be empty in early phases)."
  type        = string
  default     = ""
}
