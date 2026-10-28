# Security groups, least privilege between tiers.
# No SSH ingress anywhere by default. Access is via SSM Session Manager.
# Set var.key_name and add a 22 rule only if you explicitly need SSH.

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
