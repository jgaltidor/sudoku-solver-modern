variable "aws_region" {
  description = "AWS region to deploy into. us-east-1 is the cheapest and the default for most learning."
  type        = string
  default     = "us-east-1"
}

variable "cpu_architecture" {
  description = <<-EOT
    CPU architecture for the instance and the AL2023 AMI: "x86_64" or "arm64".
    Must match both var.instance_type (t3.* = x86_64, t4g.* = arm64) and the
    architecture the Docker image was pushed for (see deploy/README.md).
  EOT
  type        = string
  default     = "x86_64"

  validation {
    condition     = contains(["x86_64", "arm64"], var.cpu_architecture)
    error_message = "cpu_architecture must be \"x86_64\" or \"arm64\"."
  }
}

variable "instance_type" {
  description = "EC2 instance type. t3.micro and t4g.micro are both free-tier eligible (750 hrs/mo, first 12 months)."
  type        = string
  default     = "t3.micro"
}

variable "docker_image" {
  description = "Container image the instance pulls and runs on port 80."
  type        = string
  default     = "docker.io/jgaltidor/sudoku-solver-modern:latest"
}

variable "ami_id" {
  description = <<-EOT
    Optional AMI ID override. Leave empty to use the latest Amazon Linux 2023
    (Docker installed at boot by user_data.sh). Set it to a Packer-baked AMI
    (see deploy/packer/) to skip the boot-time install.
  EOT
  type        = string
  default     = ""
}

variable "project_tag" {
  description = "Value for the Project tag applied to every created resource."
  type        = string
  default     = "sudoku-solver-modern"
}
