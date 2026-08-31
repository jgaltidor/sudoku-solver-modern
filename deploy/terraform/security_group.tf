# One security group for the instance:
#   - port 80 open to the world  -- this is a public web app, that's the point
#   - all egress allowed         -- the instance reaches Docker Hub, the SSM
#                                   endpoints, etc.
#
# No inbound SSH (port 22): shell access is via SSM Session Manager (iam.tf),
# which is outbound-only from the instance -- nothing to open.
#
# No HTTPS (443): this deployment is HTTP-only for now (no domain). Add a 443
# rule + a TLS terminator (Caddy/nginx, or an ALB + ACM cert) when a domain
# is in play.

resource "aws_security_group" "app" {
  name        = "${var.project_tag}-app"
  description = "Sudoku solver: public HTTP only (shell access via SSM)"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name    = "${var.project_tag}-app"
    Project = var.project_tag
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.app.id
  description       = "HTTP from anywhere"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.app.id
  description       = "All outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
