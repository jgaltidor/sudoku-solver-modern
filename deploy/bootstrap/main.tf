# Bootstrap: the S3 bucket that holds deploy/terraform/'s state.
#
# Chicken-and-egg -- the bucket must exist before deploy/terraform/ can use it
# as a backend, and you can't create it with the config that depends on it. So
# this is a separate, tiny config with its own *local* state (there's nothing
# here worth protecting: one bucket, recreatable in seconds).
#
#   cd deploy/bootstrap
#   terraform init
#   terraform apply            # prints the bucket name
#
# Then set that bucket name in deploy/terraform/backend.tf's `bucket = ...` (or
# pass -backend-config) and run `terraform init -migrate-state` there once.
#
# Run this once per AWS account. `terraform destroy` here only after
# deploy/terraform/ itself has been destroyed (the bucket must outlive it).

terraform {
  required_version = ">= 1.10"

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

variable "aws_region" {
  description = "Must match deploy/terraform/'s aws_region."
  type        = string
  default     = "us-east-1"
}

variable "project_tag" {
  type    = string
  default = "sudoku-solver-modern"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "tfstate" {
  # Account ID suffix -- bucket names are globally unique across all of AWS.
  bucket = "${var.project_tag}-tfstate-${data.aws_caller_identity.current.account_id}"

  tags = {
    Project = var.project_tag
    Purpose = "terraform-state"
  }
}

# Every state write becomes a recoverable version -- undo a bad apply.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# State versions pile up forever otherwise; 90 days of history is plenty.
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    id     = "expire-noncurrent-state-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

output "bucket" {
  description = "Put this in deploy/terraform/backend.tf (bucket = ...)."
  value       = aws_s3_bucket.tfstate.id
}
