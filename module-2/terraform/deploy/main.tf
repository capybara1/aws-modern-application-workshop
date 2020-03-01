provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  web_api_service_name           = "mythicalmysfits-web-api-service"
  web_api_service_log_group_name = "mythicalmysfits-web_api-logs"
  web_api_repo_name              = "mythicalmysfits/service"
  web_api_image_tag              = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${local.web_api_repo_name}:latest"
}

resource "aws_vpc" "default" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "mythicalmysfits"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.default.id
  availability_zone_id    = data.aws_availability_zones.available.zone_ids[count.index]
  cidr_block              = "10.0.${count.index}.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "mythicalmysfits-public-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count                = 2
  vpc_id               = aws_vpc.default.id
  availability_zone_id = data.aws_availability_zones.available.zone_ids[count.index]
  cidr_block           = "10.0.${count.index + 2}.0/24"
  tags = {
    Name = "mythicalmysfits-private-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
}

resource "aws_eip" "nat" {
  count      = 2
  vpc        = true
  depends_on = [aws_internet_gateway.default]
}

resource "aws_nat_gateway" "default" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = {
    Name = "mythicalmysfits-nat-${count.index + 1}"
  }
  depends_on = [aws_internet_gateway.default]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.default.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }
  tags = {
    Name = "mythicalmysfits-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[count.index].id
}

resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.default.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.default[count.index].id
  }
  tags = {
    Name = "mythicalmysfits-private-rt${count.index + 1}"
  }
}

resource "aws_route_table_association" "private" {
  count          = 2
  route_table_id = aws_route_table.private[count.index].id
  subnet_id      = aws_subnet.private[count.index].id
}

resource "aws_lb" "default" {
  name               = "mythicalmysfits-nlb"
  load_balancer_type = "network"
  internal           = false
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "default" {
  name        = "mythicalmysfits-nlb-default-tg"
  port        = 8080
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = aws_vpc.default.id
  health_check {
    path                = "/"
    interval            = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.default.arn
  port              = 80
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }
}

resource "aws_iam_service_linked_role" "service_role" {
  aws_service_name = "ecs.amazonaws.com"
}

resource "aws_ecs_cluster" "web_api" {
  name = "mythicalmysfits-web-api-cluster"
}

resource "aws_cloudwatch_log_group" "web_api" {
  name = local.web_api_service_log_group_name
}

resource "aws_iam_role" "ecs_task" {
  name               = "ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role_policy.json
  path               = "/"
}

resource "aws_iam_role_policy" "ecs_task" {
  name   = "ecs-task-policy"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_task_policy.json
}

resource "aws_ecs_task_definition" "web_api" {
  family                   = "mythicalmysfitsservice"
  cpu                      = 256
  memory                   = 512
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_service.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  container_definitions    = <<EOT
  [
    {
      "name": "${local.web_api_service_name}",
      "image": "${local.web_api_image_tag}",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "http"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${local.web_api_service_log_group_name}",
          "awslogs-region": "${var.aws_region}",
          "awslogs-stream-prefix": "awslogs-mythicalmysfits-service"
        }
      },
      "essential": true
    }
  ]
  EOT
}

resource "aws_iam_role" "ecs_service" {
  name               = "${local.web_api_service_name}-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_service_assume_role_policy.json
  path               = "/"
}

resource "aws_iam_role_policy" "ecs_service" {
  name   = "${local.web_api_service_name}-policy"
  role   = aws_iam_role.ecs_service.id
  policy = data.aws_iam_policy_document.ecs_service_policy.json
}

resource "aws_security_group" "web_api" {
  name        = "mythicalmysfits-web-api-sg"
  description = "Controls access to fargate containers running web API services"
  vpc_id      = aws_vpc.default.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress { # required by ECS task if no public IP is assigned
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_service" "web_api" {
  name                               = local.web_api_service_name
  cluster                            = aws_ecs_cluster.web_api.arn
  launch_type                        = "FARGATE"
  desired_count                      = 1
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 0
  task_definition                    = aws_ecs_task_definition.web_api.arn
  network_configuration {
    assign_public_ip = false
    security_groups  = [aws_security_group.web_api.id]
    subnets          = aws_subnet.private[*].id
  }
  load_balancer {
    container_name   = local.web_api_service_name
    container_port   = 8080
    target_group_arn = aws_lb_target_group.default.arn
  }
}
