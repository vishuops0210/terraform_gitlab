# RDS, Praefect database only.
# Database name is praefect_production, matching Praefect config.
# This is a separate database from the main GitLab Rails database,
# which comes in phase 2 and must not share this instance in production.

resource "aws_db_subnet_group" "praefect" {
  name       = "${var.project}-praefect"
  subnet_ids = aws_subnet.data[*].id

  tags = {
    Name = "${var.project}-praefect-db-subnet-group"
  }
}

resource "aws_db_instance" "praefect" {
  identifier     = "${var.project}-praefect"
  engine         = "postgres"
  engine_version = var.rds_engine_version
  instance_class = var.rds_instance_class

  allocated_storage   = var.rds_allocated_storage
  storage_type        = "gp3"
  storage_encrypted   = true
  multi_az            = var.rds_multi_az
  publicly_accessible = false

  db_name  = "praefect_production"
  username = var.rds_username
  password = var.rds_password

  db_subnet_group_name   = aws_db_subnet_group.praefect.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 7
  deletion_protection     = false
  skip_final_snapshot     = true

  tags = {
    Name = "${var.project}-praefect-rds"
    Role = "praefect-db"
  }
}
