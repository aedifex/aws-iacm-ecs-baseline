############################################
# Terraform & Provider
############################################

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

############################################
# Default Networking (POV Speed Mode)
############################################

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

############################################
# ECR Repository
############################################

resource "aws_ecr_repository" "app" {
  name = "hx-ecs-demo"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "hx-ecs-demo"
  }
}

############################################
# ECS Cluster
############################################

resource "aws_ecs_cluster" "main" {
  name = "hx-ecs-cluster"

  tags = {
    Name = "hx-ecs-cluster"
  }
}

############################################
# IAM Role for ECS Task Execution (Fargate)
############################################

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "hx-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

############################################
# Security Group for ALB + ECS Tasks
############################################

resource "aws_security_group" "ecs_sg" {
  name   = "hx-ecs-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # POV only
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "hx-ecs-sg"
  }
}

############################################
# Application Load Balancer
############################################

resource "aws_lb" "alb" {
  name               = "hx-ecs-alb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.ecs_sg.id]

  tags = {
    Name = "hx-ecs-alb"
  }
}

############################################
# Target Group
############################################

resource "aws_lb_target_group" "tg" {
  name        = "hx-ecs-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "hx-ecs-tg"
  }
}

############################################
# Listener
############################################

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

############################################
# Outputs (Shared with App Workspace)
############################################

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "target_group_name" {
  value = aws_lb_target_group.tg.name
}

output "security_group_name" {
  value = aws_security_group.ecs_sg.name
}

output "execution_role_arn" {
  value = aws_iam_role.ecs_task_execution_role.arn
}

output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}