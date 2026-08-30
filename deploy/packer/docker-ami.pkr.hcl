# OPTIONAL -- the Terraform deployment does NOT need this.
#
# The default path (deploy/terraform/) installs Docker at first boot via
# user_data.sh, which adds ~20-30s to the very first startup. This Packer
# template instead bakes a custom AMI that already has Docker installed and
# the app image pre-pulled, so instances launched from it are ready almost
# immediately. That only matters when you launch instances often (autoscaling,
# frequent replacement) -- for one mostly-stopped box it's purely a learning
# exercise in how Packer relates to Terraform.
#
# Build it:
#   cd deploy/packer
#   packer init .
#   packer build docker-ami.pkr.hcl
#
# Then wire the resulting AMI ID into Terraform:
#   # deploy/terraform/terraform.tfvars
#   ami_id = "ami-0123456789abcdef0"

packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1.3"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "cpu_architecture" {
  type    = string
  default = "x86_64"
}

variable "docker_image" {
  type    = string
  default = "docker.io/jgaltidor/sudoku-solver-modern:latest"
}

# Same AL2023 image family Terraform resolves, via the AWS-published SSM
# parameter -- keeps the base identical between the two paths.
data "amazon-parameterstore" "al2023_ami" {
  name   = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-${var.cpu_architecture}"
  region = var.region
}

source "amazon-ebs" "sudoku" {
  region        = var.region
  instance_type = var.instance_type
  source_ami    = data.amazon-parameterstore.al2023_ami.value
  ssh_username  = "ec2-user"

  ami_name        = "sudoku-solver-docker-{{timestamp}}"
  ami_description = "Amazon Linux 2023 + Docker + pre-pulled sudoku-solver-modern image"

  tags = {
    Project = "sudoku-solver-modern"
    Source  = "packer"
  }
}

build {
  sources = ["source.amazon-ebs.sudoku"]

  provisioner "shell" {
    inline = [
      "set -euxo pipefail",
      "sudo dnf install -y docker",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo docker pull ${var.docker_image}",
      "sudo systemctl stop docker",
    ]
  }
}
