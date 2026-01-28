output "instance_id" {
  description = "ID of the EC2 instance hosting n8n."
  value       = module.compute.instance_id
}

output "instance_public_ip" {
  description = "Elastic/public IP assigned to the instance."
  value       = module.compute.public_ip
}

output "security_group_id" {
  description = "Security group managing ingress to the host."
  value       = module.network.security_group_id
}

output "n8n_url" {
  description = "HTTPS URL for the deployed n8n instance."
  value       = "https://${var.domain_name}"
}
