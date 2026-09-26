# DevOps workstation (EC2)

Terraform for the Ubuntu EC2 instance used to build and run the project.

| Setting | Value |
|---|---|
| AMI | Latest Ubuntu 24.04 LTS (Canonical) |
| Type | `t2.large` (2 vCPU, 8 GB) |
| Region | `us-east-2` |
| Root disk | 30 GB gp3, encrypted (8 GB default runs out when pulling images) |
| Inbound | SSH (22) and app (8080), **from one CIDR only** (`0.0.0.0/0` is rejected) |
| Metadata | IMDSv2 required |
| First boot | Runs [`scripts/bootstrap-ec2.sh`](../../scripts/bootstrap-ec2.sh): Docker, kubectl, Terraform, AWS CLI |

## Usage

```bash
cd terraform/workstation
cp example.tfvars terraform.tfvars   # set key_name and allowed_cidr
terraform init
terraform plan
terraform apply
```

After about 3–5 minutes, SSH in with the `ssh_command` output and check the bootstrap:

```bash
tail -n 20 /var/log/cloud-init-output.log   # ends with "Installed versions"
docker ps                                   # works without sudo
```

Tear down when done (removes the instance, its disk and the security group):

```bash
terraform destroy
```
