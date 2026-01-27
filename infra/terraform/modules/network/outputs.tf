output "security_group_id" {
  description = "ID of the security group managing n8n host traffic."
  value       = aws_security_group.n8n.id
}
