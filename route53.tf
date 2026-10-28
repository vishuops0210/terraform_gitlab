# Private Route53 zone, matching your existing lab naming.
# Records are generated from the EC2 instances, so scaling the counts
# automatically adds or removes DNS records on the next apply.
# Names: gitaly-1.internal, gitaly-2.internal, praefect-1.internal, etc.

resource "aws_route53_zone" "internal" {
  name = var.private_dns_zone

  vpc {
    vpc_id = aws_vpc.main.id
  }

  comment = "Private zone for GitLab hybrid, Gitaly and Praefect internal hostnames."

  tags = {
    Name = "${var.project}-${var.private_dns_zone}"
  }
}

resource "aws_route53_record" "gitaly" {
  count = var.gitaly_count

  zone_id = aws_route53_zone.internal.zone_id
  name    = "gitaly-${count.index + 1}.${var.private_dns_zone}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.gitaly[count.index].private_ip]
}

resource "aws_route53_record" "praefect" {
  count = var.praefect_count

  zone_id = aws_route53_zone.internal.zone_id
  name    = "praefect-${count.index + 1}.${var.private_dns_zone}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.praefect[count.index].private_ip]
}

# Single Praefect endpoint, via the internal NLB.
# GitLab Rails, Shell, and EKS should use praefect.internal:2305,
# not praefect-1.internal or praefect-2.internal directly.
resource "aws_route53_record" "praefect_nlb" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "praefect.${var.private_dns_zone}"
  type    = "A"

  alias {
    name                   = aws_lb.praefect.dns_name
    zone_id                = aws_lb.praefect.zone_id
    evaluate_target_health = true
  }
}
