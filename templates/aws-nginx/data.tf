# Récupération du VPC
data "aws_vpc" "main" {
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Récupération des sous-réseaux privés
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  filter {
    name   = "tag:Tier"
    values = ["private"]
  }
}

# Récupération du Security Group de l'Application
data "aws_security_group" "app_sg" {
  name   = "${var.project_name}-app-sg"
  vpc_id = data.aws_vpc.main.id
}

# Récupération du Target Group de l'ALB
data "aws_lb_target_group" "app_tg" {
  name = "${var.project_name}-app-tg"
}

# Récupération de l'Application Load Balancer pour extraire l'URL publique
data "aws_lb" "main" {
  name = "${var.project_name}-alb"
}
