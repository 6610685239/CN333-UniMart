output "ec2_public_ip" {
  description = "The Elastic IP address of the EC2 instance"
  value       = module.compute.elastic_ip
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = module.compute.instance_id
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i your-key.pem ubuntu@${module.compute.elastic_ip}"
}

output "app_url" {
  description = "Application URL"
  value       = "http://${module.compute.elastic_ip}"
}
