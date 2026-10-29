# Rails Postgres and Redis, for EKS GitLab. Separate from Praefect RDS.
# Rails RDS: Postgres 17, database gitlabhq_production, user gitlab.
# Password comes from RAILS_DB_PASSWORD env via terragrunt inputs, never
# hardcoded here. Same pattern as Praefect RDS password.
# Redis: ElastiCache replication group, TLS on, auth token from
# REDIS_AUTH_TOKEN env via terragrunt inputs, scheme rediss in values.
# Both live in data subnets for RDS and private subnets for Redis,
# private only, ingress from VPC CIDR only, for lab simplicity.

resource "aws_security_group" "rails_rds" {
  name        = "${var.project}-rails-rds"
  description = "Rails RDS, Postgres 5432 from VPC only."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Postgres from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-rails-rds"
    Role = "rails-db"
  }
}

resource "aws_db_subnet_group" "rails" {
  name       = "${var.project}-${var.environment}-rails"
  subnet_ids = aws_subnet.data[*].id

  tags = {
    Name = "${var.project}-${var.environment}-rails"
  }
}

resource "aws_db_instance" "rails" {
  identifier = "${var.project}-${var.environment}-rails"

  engine         = "postgres"
  engine_version = "17"

  instance_class    = var.rails_rds_instance_class
  allocated_storage = var.rails_rds_allocated_storage
  storage_type      = var.rails_rds_storage_type
  storage_encrypted = true

  multi_az            = var.rails_rds_multi_az
  publicly_accessible = false

  db_name  = "gitlabhq_production"
  username = "gitlab"
  password = var.rails_db_password

  db_subnet_group_name   = aws_db_subnet_group.rails.name
  vpc_security_group_ids = [aws_security_group.rails_rds.id]

  backup_retention_period = var.rails_rds_backup_retention_period
  deletion_protection     = false
  skip_final_snapshot     = true

  tags = {
    Name = "${var.project}-${var.environment}-rails"
    Role = "rails-db"
  }
}

resource "aws_security_group" "redis" {
  name        = "${var.project}-redis"
  description = "Redis 6379 from VPC only."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Redis from VPC"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-redis"
    Role = "redis"
  }
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project}-${var.environment}-redis"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.project}-${var.environment}-redis"
  description          = "GitLab Redis, TLS on."

  engine               = "redis"
  engine_version       = "7.1"
  node_type            = var.redis_node_type
  num_cache_clusters   = 1
  parameter_group_name = "default.redis7"

  automatic_failover_enabled = false
  multi_az_enabled           = false

  transit_encryption_enabled = true
  at_rest_encryption_enabled = true
  auth_token                 = var.redis_auth_token

  port               = 6379
  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis.id]
  apply_immediately  = true
}
