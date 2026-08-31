# IAM role + instance profile that lets the instance register with AWS Systems
# Manager, so you get a shell via `aws ssm start-session` instead of SSH:
# no key pair to manage, no port 22 open, access gated by IAM, sessions in
# CloudTrail. The SSM agent ships in the AL2023 AMI already.
#
# Connect:  aws ssm start-session --target <instance-id>
# (needs the session-manager-plugin locally -- it's in the devcontainer)

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${var.project_tag}-instance"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = {
    Project = var.project_tag
  }
}

# AWS-managed policy with exactly the permissions the SSM agent needs.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.project_tag}-instance"
  role = aws_iam_role.instance.name

  tags = {
    Project = var.project_tag
  }
}
