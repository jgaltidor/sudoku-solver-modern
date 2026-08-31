# Remote state in S3 -- so `terraform` can be run from any machine with AWS
# credentials (not just the one holding a local tfstate file), and every write
# is versioned + lock-protected.
#
# The bucket is created by deploy/bootstrap/ (run that once per account first).
# `use_lockfile` is S3-native locking (Terraform >= 1.10) -- no DynamoDB table.
#
# First-time switch from the old local state:
#   terraform init -migrate-state     # answer "yes" to copy state up to S3
#
# The account-id suffix is not a secret (it appears in every ARN); it is here so
# the bucket name is globally unique. Change all three values together if you
# deploy this to a different account.
terraform {
  backend "s3" {
    bucket       = "sudoku-solver-modern-tfstate-164892691333"
    key          = "deploy/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
