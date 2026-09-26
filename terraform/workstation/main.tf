# Latest official Ubuntu 24.04 LTS (Noble) image from Canonical.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "workstation" {
  name        = "${var.name}-sg"
  description = "SSH and demo app access from a single trusted CIDR"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.workstation.id
  description       = "SSH"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.allowed_cidr
}

resource "aws_vpc_security_group_ingress_rule" "app" {
  for_each = toset([for p in var.app_ports : tostring(p)])

  security_group_id = aws_security_group.workstation.id
  description       = "Demo app port ${each.value}"
  ip_protocol       = "tcp"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  cidr_ipv4         = var.allowed_cidr
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.workstation.id
  description       = "All outbound (apt, image pulls, AWS APIs)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_instance" "workstation" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.workstation.id]
  associate_public_ip_address = true

  # Runs the repo's bootstrap script on first boot as root, adding the ubuntu user
  # to the docker group. Progress: /var/log/cloud-init-output.log
  user_data                   = "#!/bin/bash\nexport SUDO_USER=ubuntu\n${file("${path.module}/../../scripts/bootstrap-ec2.sh")}"
  user_data_replace_on_change = false

  root_block_device {
    volume_size           = var.root_volume_gb
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  # Require IMDSv2 (session tokens) to protect instance credentials from SSRF.
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = {
    Name = var.name
  }
}
