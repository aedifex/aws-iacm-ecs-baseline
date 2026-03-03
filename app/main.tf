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
# Variables
############################################

variable "container_image" {
  description = "Container image for ECS task"
  type        = string
  default     = "nginx:latest"
}

variable "desired_count" {
  description = "Number of running tasks"
  type        = number
  default     = 1
}

############################################
# Data Sources (Reference Infra Workspace)
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

data "aws_ecs_cluster" "main" {
  cluster_name = "hx-ecs-cluster"
}

data "aws_lb_target_group" "tg" {
  name = "hx-ecs-tg"
}

data "aws_security_group" "ecs_sg" {
  name = "hx-ecs-sg"
}

data "aws_iam_role" "execution_role" {
  name = "hx-ecs-task-execution-role"
}

############################################
# ECS Task Definition
############################################

resource "aws_ecs_task_definition" "task" {
  family                   = "hx-ecs-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.aws_iam_role.execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = var.container_image
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}

############################################
# ECS Service
############################################

resource "aws_ecs_service" "service" {
  name            = "hx-ecs-service"
  cluster         = data.aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [data.aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = data.aws_lb_target_group.tg.arn
    container_name   = "nginx"
    container_port   = 80
  }

  depends_on = [aws_ecs_task_definition.task]
}

############################################
# Output ALB DNS
############################################

data "aws_lb" "alb" {
  name = "hx-ecs-alb"
}

output "alb_dns_name" {
  value = data.aws_lb.alb.dns_name
}