output "instance_id" {
  value = aws_instance.workstation.id
}

output "public_ip" {
  description = "Changes whenever the instance is stopped and started."
  value       = aws_instance.workstation.public_ip
}

output "ssh_command" {
  value = "ssh -i <path-to>/${var.key_name}.pem ubuntu@${aws_instance.workstation.public_ip}"
}

output "app_url" {
  value = "http://${aws_instance.workstation.public_ip}:8080"
}

output "ami" {
  value = "${data.aws_ami.ubuntu.name} (${data.aws_ami.ubuntu.id})"
}
