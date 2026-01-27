variable "instance_type" {
  type        = string
  description = "EC2 instance type."
}

variable "root_volume_size" {
  type        = number
  description = "Root EBS volume size in GiB."
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for EC2 placement."
}

variable "security_group_id" {
  type        = string
  description = "Security group applied to the instance."
}

variable "ssh_key_name" {
  type        = string
  description = "Existing EC2 key pair name."
}

variable "enable_elastic_ip" {
  type        = bool
  description = "Allocate and associate Elastic IP when true."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to compute resources."
  default     = {}
}

variable "user_data" {
  type        = string
  description = "Rendered user-data script contents."
  default     = ""
}

variable "ami_owner" {
  type        = string
  description = "Owner ID used to look up the Ubuntu AMI."
  default     = "099720109477"
}

variable "ami_name_filter" {
  type        = string
  description = "Name filter used to select the Ubuntu AMI."
  default     = "ubuntu/images/hvm-ssd/ubuntu-jammy-24.04-amd64-server-*"
}
