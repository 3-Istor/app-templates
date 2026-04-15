###############################################################################
# modules/infra/aws-asg-cluster/main.tf
# Crée un Auto Scaling Group AWS pour une app web.
# Équivalent AWS du module openstack-vm-cluster.
###############################################################################

# ── Launch Template ───────────────────────────────────────────────────────────
resource "aws_launch_template" "app" {
  name_prefix   = "${var.app_name}-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [var.app_sg_id]

  # user_data est déjà base64+gzip via cloudinit_config (module software)
  user_data = var.user_data

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_type           = "gp3"
      volume_size           = 20
      delete_on_termination = true
      encrypted             = true
    }
  }

  metadata_options {
    http_tokens = "required" # IMDSv2 obligatoire
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "${var.app_name}-node"
      AppName = var.app_name
      Project = var.project_name
    }
  }
}

# ── Auto Scaling Group ────────────────────────────────────────────────────────
resource "aws_autoscaling_group" "app" {
  name                      = "${var.app_name}-asg"
  desired_capacity          = var.instance_count
  min_size                  = var.instance_count
  max_size                  = var.instance_count * 2
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [var.target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "AppName"
    value               = var.app_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }
}

output "app_public_url" {
  value       = "Récupérer le DNS de l'ALB depuis le module loadbalancer du terraform-aws"
  description = "L'URL publique est celle de l'ALB défini dans terraform-aws"
}
