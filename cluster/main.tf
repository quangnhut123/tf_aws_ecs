resource "aws_ecs_cluster" "main" {
  name = var.name
}

resource "aws_cloudwatch_log_group" "ecs_agent" {
  name              = var.log_group
  retention_in_days = var.log_groups_expiration_days
  tags              = var.log_groups_tags
}

resource "aws_autoscaling_group" "app" {
  name            = aws_ecs_cluster.main.name
  enabled_metrics = var.asg_enabled_metrics

  launch_configuration = aws_launch_configuration.app.name
  termination_policies = var.asg_termination_policies

  # NOTE: this module no handled desired capacity
  #desired_capacity     = "${var.asg_desired}"
  min_size = var.asg_min_size
  max_size = var.asg_max_size

  vpc_zone_identifier = var.vpc_zone_identifier
  default_cooldown    = var.asg_default_cooldown

  tags = [var.asg_extra_tags]

  lifecycle {
    create_before_destroy = true

    # NOTE: changed automacally by autoscale policy
    ignore_changes = [desired_capacity]
  }
}

resource "aws_launch_configuration" "app" {
  name_prefix                 = "${aws_ecs_cluster.main.name}-"
  security_groups             = var.security_groups
  key_name                    = var.key_name
  image_id                    = var.ami_id
  instance_type               = var.instance_type
  ebs_optimized               = var.ebs_optimized
  iam_instance_profile        = aws_iam_instance_profile.ecs_instance.name
  user_data                   = var.user_data
  associate_public_ip_address = var.associate_public_ip_address
  enable_monitoring           = true

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  # NOTE: Currently no-support to customizing block device(s)
  #   - OS specified image_id is not always using /dev/xvdcz as docker storage
  #   - As a workaround, creates the ami that it is customizing to the block device mappings
  #
  # DOCS: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-ami-storage-config.html
  #ebs_block_device  { device_name = "/dev/xvdcz" }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [image_id]
  }
}

#Launch template for main cluster
resource "aws_launch_template" "app" {
  name_prefix = "${aws_ecs_cluster.main.name}-launch-template-"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      delete_on_termination = var.delete_on_termination
      encrypted             = var.encrypted
      volume_type           = var.ebs_volume_type
    }
  }

  capacity_reservation_specification {
    capacity_reservation_preference = "open"
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance.name
  }

  monitoring {
    enabled = true
  }

  network_interfaces {
    associate_public_ip_address = var.associate_public_ip_address
    security_groups             = var.security_groups
  }
  disable_api_termination              = var.disable_api_termination
  ebs_optimized                        = var.ebs_optimized
  image_id                             = var.ami_id
  instance_initiated_shutdown_behavior = "terminate"
  update_default_version               = true
  instance_type                        = var.instance_type
  key_name                             = var.key_name
  user_data                            = var.user_data
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${aws_ecs_cluster.main.name}-launch-template"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
