# Root config: provider, and the data sources that pick *where* (default VPC)
# and *what* (latest Amazon Linux 2023 AMI) the instance runs on. The actual
# resources are split into security_group.tf and instance.tf for readability --
# Terraform loads every .tf file in this directory regardless.
#
# State is local (a terraform.tfstate file next to these configs, gitignored).
# That's fine for a single-operator learning deployment; a shared/team setup
# would move it to an S3 backend with DynamoDB locking instead.

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# The newest Amazon Linux 2023 AMI for the chosen CPU architecture, resolved at
# plan time from an AWS-published SSM parameter -- no hardcoded AMI IDs to go
# stale, and it stays correct across regions. AL2023 ships `dnf` and has Docker
# in its default repos, which is all user_data.sh needs.
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-${var.cpu_architecture}"
}

# Deploy into the account's default VPC / default subnets -- no custom
# networking to manage for a single public instance. A real production estate
# would define its own VPC with private subnets + a load balancer.
data "aws_vpc" "default" {
  default = true
}

# Not every AZ offers every instance type (e.g. t3.micro is absent from
# us-east-1e). Restrict the subnet choice to AZs that actually offer the
# requested type, so `instance.tf` can safely take .ids[0].
data "aws_ec2_instance_type_offerings" "supported_azs" {
  filter {
    name   = "instance-type"
    values = [var.instance_type]
  }
  location_type = "availability-zone"
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "availability-zone"
    values = data.aws_ec2_instance_type_offerings.supported_azs.locations
  }
}

locals {
  # var.ami_id wins when set (e.g. a Packer-baked AMI, see deploy/packer/);
  # otherwise fall back to the resolved AL2023 image. nonsensitive() because
  # the SSM data source marks its value sensitive, which would otherwise
  # redact the AMI ID (public info) throughout `terraform plan` output.
  ami_id = var.ami_id != "" ? var.ami_id : nonsensitive(data.aws_ssm_parameter.al2023_ami.value)
}
