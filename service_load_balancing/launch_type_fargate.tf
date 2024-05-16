// NOTE: var.launch_type = "FARGATE" if you want use following
locals {
  enable_service_discovery = var.enable_service_discovery
  service_discovery_registry_arn = var.enable_service_discovery && var.service_discovery_registry_arn != "" ? var.service_discovery_registry_arn : null
}
resource "aws_ecs_service" "fargate" {
  count = var.launch_type == "FARGATE" ? 1 : 0

  platform_version = var.platform_version

  name            = var.name
  cluster         = var.cluster_id
  launch_type     = var.launch_type
  task_definition = aws_ecs_task_definition.fargate[0].arn

  # As below is can be running in a service during a deployment
  desired_count                      = var.desired_count
  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent

  network_configuration {
    assign_public_ip = var.assign_public_ip
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  dynamic "service_registries" {
    for_each = local.enable_service_discovery ? [1] : []
    content {
      registry_arn   = local.service_discovery_registry_arn
    }
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

resource "aws_ecs_task_definition" "fargate" {
  count = var.launch_type == "FARGATE" ? 1 : 0

  family                   = var.container_family
  container_definitions    = var.container_definitions
  network_mode             = var.network_mode
  requires_compatibilities = [var.launch_type]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.fargate_ecs_task_execution_role[0].arn
  task_role_arn            = aws_iam_role.fargate_ecs_task_role[0].arn
  depends_on = [
    aws_iam_role_policy.fargate,
    aws_iam_role_policy_attachment.fargate_task_execution,
    aws_iam_role_policy.fargate_execution,
  ]
}

resource "aws_iam_role" "fargate_ecs_task_execution_role" {
  count = var.launch_type == "FARGATE" ? 1 : 0
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

resource "aws_iam_role" "fargate_ecs_task_role" {
  count = var.launch_type == "FARGATE" ? 1 : 0

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

resource "aws_iam_role_policy" "fargate" {
  count = var.launch_type == "FARGATE" ? 1 : 0

  name   = "ecsTaskExecutionRolePolicy-${var.name}"
  role   = aws_iam_role.fargate_ecs_task_role[0].name
  policy = var.iam_role_inline_policy
}

resource "aws_iam_role_policy" "fargate_s3" {
  count = var.launch_type == "FARGATE" && var.s3_policy ? 1 : 0

  name   = "ecsTaskRoleS3Policy-${var.name}"
  role   = aws_iam_role.fargate_ecs_task_role[0].name
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": ${var.s3_policy} && length(${var.bucket_arn_list}) > 0 ? ${var.bucket_arn_list} : ["null"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": ${var.s3_policy} && length(${var.bucket_arn_list}) > 0 ? [ for arn in ${var.bucket_arn_list} : "${arn}/*" ] : ["null"]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "fargate_task_execution" {
  count = var.launch_type == "FARGATE" ? 1 : 0

  role       = aws_iam_role.fargate_ecs_task_execution_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

// permissions to collect ECS Fargate metrics
resource "aws_iam_role_policy" "fargate_execution" {
  count = var.launch_type == "FARGATE" ? 1 : 0

  name   = "ecsTaskExecutionRoleFargatePolicy-${var.name}"
  role   = aws_iam_role.fargate_ecs_task_execution_role[0].name
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

