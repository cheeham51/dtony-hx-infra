provider "aws" {
  region = "ap-southeast-2"
}

terraform {
  backend "s3" {
    bucket         = "hx-app-infra-state"
    key            = "hx-app.tfstate"
    region         = "ap-southeast-2"
    encrypt        = true
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.8.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# Public Subnets
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.8.1.0/24"
  availability_zone       = "ap-southeast-2a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.8.2.0/24"
  availability_zone       = "ap-southeast-2b"
  map_public_ip_on_launch = true
}

# Route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "ecs_sg" {
  name   = "hx-app-sg-a"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM Role for ECS execution
resource "aws_iam_role" "ecs_exec" {
  name = "hx-app-ecs-exec-role-a"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec_attach" {
  role       = aws_iam_role.ecs_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "hx-cluster"
}

# Task Definition (placeholder)
resource "aws_ecs_task_definition" "bootstrap" {
  family                   = "hx-app-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_exec.arn

  container_definitions = jsonencode([
    {
      name      = "hx-app",
      image     = "amazon/amazon-ecs-sample",
      essential = true,
      portMappings = [
        {
          containerPort = 80
        }
      ]
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "hx-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.bootstrap.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs_sg.id]
  }

  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [aws_iam_role_policy_attachment.ecs_exec_attach]
}
