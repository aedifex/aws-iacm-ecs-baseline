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
# Default Networking (use default VPC)
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
# Reference existing infra resources
############################################

data "aws_ecs_cluster" "main" {
  cluster_name = "hx-ecs-cluster"
}

data "aws_security_group" "ecs_sg" {
  name = "hx-ecs-sg"
}

data "aws_iam_role" "execution_role" {
  name = "hx-ecs-task-execution-role"
}

data "aws_lb" "alb" {
  name = "hx-ecs-alb"
}

data "aws_lb_listener" "http" {
  load_balancer_arn = data.aws_lb.alb.arn
  port              = 80
}

############################################
# NEW Target Group for NGINX (port 80)
############################################

resource "aws_lb_target_group" "nginx_tg" {
  name        = "hx-ecs-tg-nginx"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  deregistration_delay = 30

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

############################################
# Listener Rule to route ALL traffic to nginx
# (Overrides infra default action without editing infra)
############################################

resource "aws_lb_listener_rule" "nginx_all" {
  listener_arn = data.aws_lb_listener.http.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_tg.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

############################################
# ECS Task Definition (NGINX)
############################################

resource "aws_ecs_task_definition" "task" {
  family                   = "hx-ecs-nginx"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.aws_iam_role.execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "nginx:latest"
      essential = true

      portMappings = [
        { containerPort = 80 }
      ]
    }
  ])
}

############################################
# ECS Service
############################################

resource "aws_ecs_service" "service" {
  name            = "hx-ecs-service-nginx"
  cluster         = data.aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [data.aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.nginx_tg.arn
    container_name   = "app"
    container_port   = 80
  }

  depends_on = [aws_lb_listener_rule.nginx_all]
}

############################################
# Output
############################################

output "alb_dns_name" {
  value = data.aws_lb.alb.dns_name
}