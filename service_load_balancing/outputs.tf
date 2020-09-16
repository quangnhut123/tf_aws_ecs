output "service_name" {
  value = var.name
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.app[0].name
}

output "log_group_arn" {
  value = aws_cloudwatch_log_group.app[0].arn
}

output "fargate_ecs_task_role" {
  value = length(aws_iam_role.fargate_ecs_task_role) > 0 ? aws_iam_role.fargate_ecs_task_role[0].arn : ""
}

output "fargate_ecs_task_execution_role" {
  value = length(aws_iam_role.fargate_ecs_task_execution_role) > 0 ? aws_iam_role.fargate_ecs_task_execution_role[0].arn : ""
}

