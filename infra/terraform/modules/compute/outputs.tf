output "instance_id" {
  description = "ID of the created EC2 instance."
  value       = aws_instance.n8n.id
}

output "public_ip" {
  description = "Public or Elastic IP assigned to the instance."
  value       = var.enable_elastic_ip ? aws_eip.n8n[0].public_ip : aws_instance.n8n.public_ip
}
