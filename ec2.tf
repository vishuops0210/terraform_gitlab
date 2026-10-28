# EC2 VMs, Gitaly and Praefect.
# Count is driven by variables, so scaling is: change gitaly_count or
# praefect_count in terraform.tfvars, then terraform apply.
# VMs are spread round-robin across private subnets, so across AZs.
# No public IP. Access via SSM Session Manager, using the IAM role below.

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "ec2_ssm" {
  name = "${var.project}-ec2-ssm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.project}-ec2-ssm"
  role = aws_iam_role.ec2_ssm.name
}

resource "aws_instance" "gitaly" {
  count = var.gitaly_count

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.gitaly_instance_type
  subnet_id              = aws_subnet.private[count.index % length(aws_subnet.private)].id
  vpc_security_group_ids = [aws_security_group.gitaly.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name
  key_name               = var.key_name

  root_block_device {
    volume_size = var.gitaly_root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project}-gitaly-${count.index + 1}"
    Role = "gitaly"
  }
}

resource "aws_ebs_volume" "gitaly_data" {
  count = var.gitaly_count

  availability_zone = aws_instance.gitaly[count.index].availability_zone
  size              = var.gitaly_data_volume_size
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${var.project}-gitaly-${count.index + 1}-data"
    Role = "gitaly-data"
  }
}

resource "aws_volume_attachment" "gitaly_data" {
  count = var.gitaly_count

  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.gitaly_data[count.index].id
  instance_id = aws_instance.gitaly[count.index].id
}

resource "aws_instance" "praefect" {
  count = var.praefect_count

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.praefect_instance_type
  subnet_id              = aws_subnet.private[count.index % length(aws_subnet.private)].id
  vpc_security_group_ids = [aws_security_group.praefect.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name
  key_name               = var.key_name

  root_block_device {
    volume_size = var.praefect_root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project}-praefect-${count.index + 1}"
    Role = "praefect"
  }
}
