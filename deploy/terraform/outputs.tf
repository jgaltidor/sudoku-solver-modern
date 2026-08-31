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

output "ssm_command" {
  description = "Open a shell on the instance (needs the session-manager-plugin; it's in the devcontainer)."
  value       = "aws ssm start-session --target ${aws_instance.app.id}"
}

output "instance_id" {
  description = "Instance ID, for `aws ec2 stop-instances` / `start-instances` and SSM."
  value       = aws_instance.app.id
}
