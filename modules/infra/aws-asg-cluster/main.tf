resource "aws_lb_target_group" "app_tg" {
  name     = "${var.app_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  deregistration_delay = 10

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

resource "aws_lb_listener_rule" "app_rule" {
  listener_arn = var.alb_listener_arn
  priority     = var.rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }

  condition {
    host_header {
      values = ["${var.app_name}.3istor.com"]
    }
  }
}

resource "aws_launch_template" "app_lt" {
  name_prefix   = "${var.app_name}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [var.app_sg_id]
  user_data              = base64encode(var.user_data)

  metadata_options {
    http_tokens = "required"
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.app_name}-node"
      Role = "application"
    }
  }
}

resource "aws_autoscaling_group" "app_asg" {
  name                = "${var.app_name}-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.app_tg.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 300

  min_size         = var.instance_count
  max_size         = var.instance_count + 2
  desired_capacity = var.instance_count

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.app_name}-asg-node"
    propagate_at_launch = true
  }
}
