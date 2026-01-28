output "record_fqdn" {
  description = "Fully qualified domain name managed by this module."
  value       = aws_route53_record.n8n.fqdn
}
