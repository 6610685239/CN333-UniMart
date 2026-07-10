output "instance_id" {
  value = aws_instance.unimart.id
}

output "elastic_ip" {
  value = aws_eip.unimart.public_ip
}

output "security_group_id" {
  value = aws_security_group.unimart.id
}
