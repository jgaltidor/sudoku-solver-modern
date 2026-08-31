output "public_ip" {
  description = "Current public IP of the instance (changes on every stop/start)."
  value       = aws_instance.app.public_ip
}

output "public_dns" {
  description = "Current public DNS name of the instance."
  value       = aws_instance.app.public_dns
}

output "app_url" {
  description = "Open this in a browser once the instance has finished booting (~1-2 min)."
  value       = "http://${aws_instance.app.public_ip}"
}

output "ssh_command" {
  description = "SSH into the instance (uses the private key matching var.ssh_public_key_path)."
  value       = "ssh ec2-user@${aws_instance.app.public_ip}"
}

output "instance_id" {
  description = "Instance ID, for `aws ec2 stop-instances` / `start-instances`."
  value       = aws_instance.app.id
}
