# Security groups, least privilege between tiers.
# SSH ingress is off by default. Set var.key_name to an existing AWS key pair
# and var.ssh_allowed_cidrs to allow SSH, for lab use the VPC CIDR only.
# SSM Session Manager still works with or without SSH.

resource "aws_security_group" "gitaly" {
  name        = "${var.project}-gitaly"
  description = "Gitaly VMs: accept gRPC from Praefect only."
  vpc_id      = aws_vpc.main.id

  # Gitaly gRPC, plain. Use 8076 instead if you enable TLS on Gitaly.
  ingress {
    description     = "Gitaly gRPC from Praefect"
    from_port       = 8075
    to_port         = 8075
    protocol        = "tcp"
    security_groups = [aws_security_group.praefect.id]
  }

  dynamic "ingress" {
    for_each = length(var.ssh_allowed_cidrs) > 0 ? [1] : []
    content {
      description = "SSH from allowed CIDRs only"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_allowed_cidrs
    }
  }

  egress {
    description = "All outbound, for package installs and RDS/SSM via NAT"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-gitaly"
  }
}

resource "aws_security_group" "praefect" {
  name        = "${var.project}-praefect"
  description = "Praefect VMs: accept client traffic from inside the VPC only."
  vpc_id      = aws_vpc.main.id

  # Praefect listen port, for GitLab Rails, Shell, and later EKS pods.
  ingress {
    description = "Praefect from VPC"
    from_port   = 2305
    to_port     = 2305
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  dynamic "ingress" {
    for_each = length(var.ssh_allowed_cidrs) > 0 ? [1] : []
    content {
      description = "SSH from allowed CIDRs only"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_allowed_cidrs
    }
  }

  egress {
    description = "All outbound, for Gitaly and RDS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-praefect"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project}-rds"
  description = "Praefect RDS: accept PostgreSQL from Praefect only."
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from Praefect"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.praefect.id]
  }

  tags = {
    Name = "${var.project}-rds"
  }
}
