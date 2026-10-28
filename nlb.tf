# Internal Network Load Balancer in front of Praefect.
# Yes, this is needed: GitLab Rails, Shell, and later EKS pods should hit
# one Praefect endpoint, not individual Praefect VMs.
# Endpoint after apply: praefect.internal:2305, or the NLB DNS name from outputs.
# NLB is TCP only, it preserves the client IP, so the Praefect security
# group already allows 2305 from the VPC CIDR. No NLB security group is used.
# Target group attachments follow praefect_count automatically, so scaling
# Praefect VMs also scales NLB targets on the next apply.

resource "aws_lb" "praefect" {
  name               = "${var.project}-praefect"
  internal           = true
  load_balancer_type = "network"
  subnets            = aws_subnet.private[*].id

  enable_cross_zone_load_balancing = true

  tags = {
    Name = "${var.project}-praefect-nlb"
    Role = "praefect-nlb"
  }
}

resource "aws_lb_target_group" "praefect" {
  name     = "${var.project}-praefect"
  port     = 2305
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id

  health_check {
    protocol            = "TCP"
    port                = "2305"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = {
    Name = "${var.project}-praefect-tg"
  }
}

resource "aws_lb_target_group_attachment" "praefect" {
  count = var.praefect_count

  target_group_arn = aws_lb_target_group.praefect.arn
  target_id        = aws_instance.praefect[count.index].id
  port             = 2305
}

resource "aws_lb_listener" "praefect" {
  load_balancer_arn = aws_lb.praefect.arn
  port              = 2305
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.praefect.arn
  }
}
