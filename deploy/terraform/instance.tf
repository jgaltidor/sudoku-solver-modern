# The instance itself, plus the SSH key pair it trusts.
#
# No Elastic IP: AWS bills an EIP even while the instance is stopped, which
# defeats the "keep it off to save money" plan. The trade-off is that the
# public IP changes every stop/start -- re-read it with `terraform refresh &&
# terraform output public_ip` (see deploy/README.md).

resource "aws_key_pair" "app" {
  key_name   = "${var.project_tag}-key"
  public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))

  tags = {
    Project = var.project_tag
  }
}

resource "aws_instance" "app" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.app.key_name

  user_data = templatefile("${path.module}/user_data.sh", {
    docker_image = var.docker_image
  })
  # Re-run user_data (i.e. replace the instance) when the script or the image
  # reference changes.
  user_data_replace_on_change = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
  }

  tags = {
    Name    = var.project_tag
    Project = var.project_tag
  }
}
