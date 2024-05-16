resource "aws_iam_role" "ecs_instance" {
  name                  = "${aws_ecs_cluster.main.name}-ecs-instance-role"
  path                  = var.iam_path
  force_detach_policies = true

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

}

resource "aws_iam_policy" "s3_policy" {
  count  = var.s3_policy ? 1 : 0
  name   = "additional-s3-policy"
  policy = data.aws_iam_policy_document.s3_policy_document[count.index].json
}

data "aws_iam_policy_document" "s3_policy_document" {
  count  = var.s3_policy ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = var.s3_policy && length(var.bucket_arn_list) > 0 ? var.bucket_arn_list : null

  }

  statement {
    effect = "Allow"
    actions = [
      "s3:*",
    ]
    resources = var.s3_policy && length(var.bucket_arn_list) > 0 ? [ for arn in var.bucket_arn_list : "${arn}/*" ] : null

  }
}

resource "aws_iam_policy_attachment" "s3_policy_attach" {
  count = var.s3_policy ? 1 : 0
  name  = "additional-s3-policy-attach"

  roles = aws_iam_role.ecs_instance.name

  policy_arn = aws_iam_policy.s3_policy[count.index].arn
}

resource "aws_iam_role_policy_attachment" "ecs_instance_policy" {
  count = length(var.iam_policy_arns)

  role = aws_iam_role.ecs_instance.name
  policy_arn = element(var.iam_policy_arns, count.index)

  depends_on = [aws_iam_role.ecs_instance]
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "${aws_ecs_cluster.main.name}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance.name
  path = var.iam_path

  depends_on = [aws_iam_role.ecs_instance]
}

