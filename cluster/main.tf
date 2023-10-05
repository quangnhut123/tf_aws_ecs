resource "aws_ecs_cluster" "main" {
  name = var.name
}

resource "aws_cloudwatch_log_group" "ecs_agent" {
  name              = var.log_group
  retention_in_days = var.log_groups_expiration_days
  tags              = var.log_groups_tags
}

resource "aws_autoscaling_group" "app" {
  name                 = aws_ecs_cluster.main.name
  enabled_metrics      = var.asg_enabled_metrics
  termination_policies = var.asg_termination_policies

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

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

#Launch template for main cluster

data "template_file" "user_data" {
  template = <<EOF
    #!/bin/bash
    echo ECS_CLUSTER=${var.name} >> /etc/ecs/ecs.config
  EOF
}

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
  user_data                            = "${base64encode(data.template_file.user_data.rendered)}"
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
