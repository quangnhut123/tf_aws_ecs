// NOTE: var.launch_type = "FARGATE_NO_ALB" if you want use following

resource "aws_ecs_service" "fargate_no_alb" {
  count = var.launch_type == "FARGATE_NO_ALB" ? 1 : 0

  platform_version = var.platform_version

  name            = var.name
  cluster         = var.cluster_id
  launch_type     = "FARGATE"
  task_definition = aws_ecs_task_definition.fargate_no_alb[0].arn

  # As below is can be running in a service during a deployment
  desired_count                      = var.desired_count
  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent

  network_configuration {
    assign_public_ip = var.assign_public_ip
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
  }

  lifecycle {
    # INFO: In the future, we support that U can customize
    #       https://github.com/hashicorp/terraform/issues/3116
    ignore_changes = [
      desired_count,
      task_definition,
    ]
  }
}

resource "aws_ecs_task_definition" "fargate_no_alb" {
  count = var.launch_type == "FARGATE_NO_ALB" ? 1 : 0

  family                   = var.container_family
  container_definitions    = var.container_definitions
  network_mode             = var.network_mode
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.fargate_no_alb_ecs_task_execution_role[0].arn
  task_role_arn            = aws_iam_role.fargate_no_alb_ecs_task_role[0].arn
  depends_on = [
    aws_iam_role_policy.fargate_no_alb,
    aws_iam_role_policy_attachment.fargate_no_alb_task_execution,
    aws_iam_role_policy.fargate_no_alb_execution,
  ]
}

resource "aws_iam_role" "fargate_no_alb_ecs_task_execution_role" {
  count = var.launch_type == "FARGATE_NO_ALB" ? 1 : 0
  name  = "ecsTaskExecutionRole-${var.name}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role" "fargate_no_alb_ecs_task_role" {
  count = var.launch_type == "FARGATE_NO_ALB" ? 1 : 0

  name                  = "ecsTaskRole-${var.name}"
  path                  = var.iam_path
  force_detach_policies = true
  assume_role_policy    = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

resource "aws_iam_role_policy" "fargate_no_alb" {
  count = var.launch_type == "FARGATE_NO_ALB" ? 1 : 0

  name   = "ecsTaskExecutionRolePolicy-${var.name}"
  role   = aws_iam_role.fargate_no_alb_ecs_task_role[0].name
  policy = var.iam_role_inline_policy
}

resource "aws_iam_role_policy_attachment" "fargate_no_alb_task_execution" {
  count = var.launch_type == "FARGATE_NO_ALB" ? 1 : 0

  role       = aws_iam_role.fargate_no_alb_ecs_task_execution_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

// permissions to collect ECS Fargate metrics
resource "aws_iam_role_policy" "fargate_no_alb_execution" {
  count = var.launch_type == "FARGATE_NO_ALB" ? 1 : 0

  name   = "ecsTaskExecutionRoleFargatePolicy-${var.name}"
  role   = aws_iam_role.fargate_no_alb_ecs_task_execution_role[0].name
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:ListClusters",
        "ecs:ListContainerInstances",
        "ecs:DescribeContainerInstances"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}
