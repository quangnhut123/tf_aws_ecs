===============================================
aws ecs/service_load_balancing terraform module
===============================================

A terraform module to provides ecs service balanced on application load balancer

* ECS Service
   * Support launch_type: "EC2" / "FARGATE"
   * with ECS Task
   * with CloudWatch Log Group(s)
   * with IAM Role & attached IAM Policy
* *[Optional] Service Autoscaling*

See more details about `Service Load Balancing`_ in the official AWS docs.

.. _Service Load Balancing: http://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-load-balancing.html

----

.. contents::
   :local:
   :depth: 2

Basic Usage
===========

* Input  variables: See `variables.tf <variables.tf>`_
* Output variables: See `outputs.tf <outputs.tf>`_

.. code:: hcl

   # Pre-require your resources declaration (as may be necessary)

   provider "aws" {
     # https://github.com/terraform-providers/terraform-provider-aws/releases
     version = "~> 1.0"
     region  = "${var.region}"
   }

   provider "template" {
     # https://github.com/terraform-providers/terraform-provider-template/releases
     version = "~> 1.0"
   }

   # The following related sources is out of scope on this module
   #resource "aws_alb"              "xxx" {}
   #resource "aws_alb_lister"       "xxx" {}
   #resource "aws_alb_target_group" "xxx" {
   #  target_type = "ip" // "ip" for farget, "instance" for the default
   #}

   # for launch_type: "FARGATE"
   #resource "aws_subnet"           "xxx" {}
   #resource "aws_security_group"   "xxx" {}


   module "ecs_service" {
     source                       = "git@github.com:voyagegroup/tf_aws_ecs//service_load_balancing"
     name                         = "ex-app-api-service"
     log_groups                   = "ex-app-api/container" // same as "awslogs-group" at container_definition
     log_groups_expiration_days   = 30
     log_groups_tags              = {
       Application = "ex-app-api"
     }

     # 1. Selected launch_type: "FARGATE" (cluster auto creating)
     cluster_name                 = "${aws_ecs_cluster.ex_app.name}"
     launch_type                  = "FARGATE"
     network_mode                 = "awsvpc"
     subnet_ids                   = ["${aws_subnet.xxx.id}", "${aws_subnet.yyy.id}"]
     security_group_ids           = ["${aws_security_group.xxx.id}"]
     # 2. Selected launch_type: "EC2" (cluster needs created by external)
     #cluster_id                  = "${aws_ecs_cluster.ex_app.id}"
     #cluster_name                = "${aws_ecs_cluster.ex_app.cluster_name}"
     #launch_type                 = "EC2"

     target_group_arn             = "${aws_alb_target_group.ex_app_api.arn}"
     #desired_count               = 4
     container_name               = "ex-app-api" // same as "name"          into container_definition
     container_port               = "80"         // same as "containerPort" into container_definition
     container_family             = "ex-app-api"
     container_definitions        = <<TASK_DEFINITION
   [
     {
       "name":      "ex-app-api",
       "essential": true,
       "image":     "${var.YOUR_AWS_ACCOUNT_ID}.dkr.ecr.${var.AWS_REGION}.amazonaws.com/ex-app-api:latest",
       "cpu":       512,
       "memory":    1024,
       "portMappings": [
        {
           "hostPort": 0,
           "containerPort": 80
         }
       ],
       "logConfiguration": {
         "logDriver": "awslogs",
         "options": {
           "awslogs-group":  "ex-app-api-service/container",
           "awslogs-region": "${var.AWS_REGION}"
         }
       }
     }
   ]
   TASK_DEFINITION
   }


A note of caution
-----------------

Currently `aws_ecs_service.main.task_definition` is ignored by lifecycle
cause task_definition is updated often via continuous ecs deployment.

Although it is a difficult decision, we hope to support dynamic lifecycle
featured by Terraform.

See detail: [#1](https://github.com/voyagegroup/tf_aws_ecs/issues/1)


Advanced Usage
==============

As below U can create enhanced ecs-service using optional input-variables or others

.. contents::
   :local:


Enabled autoscaling
-------------------

.. code:: hcl

   module "ecs_service" {
     source = "git@git.hub.com:voyagegroup/tf_aws_ecs//service_load_balancing"

     # ...

     autoscale_iam_role_arn        = "${data.aws_iam_role.ecs_autoscale_service_linked_role.arn}"
     autoscale_min_capacity        = 2
     autoscale_max_capacity        = 8

     #scale_out_ok_actions         = []
     scale_out_more_alarm_actions  = ["${aws_sns_topic.ex_alert.arn}"]
     scale_out_thresholds          = {
       cpu    = 80
       memory = 75
     }
     scale_out_step_adjustment     = {
       metric_interval_lower_bound = 0
       scaling_adjustment          = 1
     }

     #scale_in_ok_actions          = []
     #scale_in_more_alarm_actions  = []
     scale_in_thresholds           = {
       cpu    = 10
       memory = 20
     }
     scale_in_step_adjustment      = {
       metric_interval_upper_bound = 0
       scaling_adjustment          = -1
     }
   }

   data "aws_iam_role" "ecs_autoscale_service_linked_role" {
     # Prepare creating a service-linked role (CLI)
     # $ aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com
     # Ref: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/using-service-linked-roles.html
     name = "AWSServiceRoleForApplicationAutoScaling_ECSService"
   }

See more details about `Service Auto Scaling`_ in the official AWS docs.

.. _Service Auto Scaling: http://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-auto-scaling.html


On ecs-cluster created with our terraform module
------------------------------------------------

Maybe only use launch_type as "EC2"

.. code:: hcl

   module "ecs_cluster" {
     source = "git@git.hub.com:voyagegroup/tf_aws_ecs//cluster"
     # ...
   }

   module "ecs_service" {
     source       = "git@git.hub.com:voyagegroup/tf_aws_ecs//service_load_balancing"
     cluster_id   = "${module.api_ecs_cluster.cluster_id}"
     cluster_name = "${module.api_ecs_cluster.cluster_name}"
     # ...
   }


Multiple ecs-services on the same ecs-cluster
---------------------------------------------


Case: Multiple application load balancers
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code:: hcl

   # Creating alb
   #resource "aws_alb" "api" {}
   #resource "aws_alb_listner" "api" {}
   #resource "aws_alb_target_group" "api" {}

   # Creating alb(-internal)
   #resource "aws_alb" "api_internal" {
   #  internal = true
   #}
   #resource "aws_alb_listner" "api_internal" {}
   #resource "aws_alb_target_group" "api_internal" {}

   module "ecs_cluster" {
     source = "git@git.hub.com:voyagegroup/tf_aws_ecs//cluster"
     # ...
   }

   module "api_ecs_service" {
     source                       = "git@github.com:voyagegroup/tf_aws_ecs//service_load_balancing"
     name                         = "api"
     cluser_id                    = "${module.ecs_cluster.cluster_id}"
     cluster_name                 = "${module.ecs_cluster.cluster_name}"
     target_group_arn             = "${aws_alb_target_group.api.arn}"
     # ...
   }

   module "api_internal_ecs_service" {
     source                       = "git@github.com:voyagegroup/tf_aws_ecs//service_load_balancing"
     name                         = "api_internal"
     cluser_id                    = "${module.ecs_cluster.cluster_id}"
     cluster_name                 = "${module.ecs_cluster.cluster_name}"
     target_group_arn             = "${aws_alb_target_group.api_internal.arn}"
     # ...
   }


Case: Multiple lister rules on application load balancer
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code:: hcl

   resource "aws_alb" "api" {
     # ...
   }

   resource "aws_alb_listener" "api" {
     # ...

     "default_action" {
       target_group_arn = "${aws_alb_target_group.api.arn}"
       type             = "forward"
     }
   }

   resource "aws_alb_target_group" "api" {
     # ...
   }

   resource "aws_alb_listener_rule" "api_canary" {
     listener_arn = "${aws_alb_listener.api.arn}"
     priority     = 99

     action {
       type             = "forward"
       target_group_arn = "${aws_alb_target_group.api_canary.arn}"
     }

     condition {
       field  = "host-header"
       values = ["test.*"]
     }
   }

   resource "aws_alb_target_group" "api_canary" {
     # ...
   }

   module "ecs_cluster" {
     source = "git@git.hub.com:voyagegroup/tf_aws_ecs//cluster"
     # ...
   }

   module "api_ecs_service" {
     source                       = "git@github.com:voyagegroup/tf_aws_ecs//service_load_balancing"
     name                         = "api"
     cluser_id                    = "${module.ecs_cluster.cluster_id}"
     cluster_name                 = "${module.ecs_cluster.cluster_name}"
     target_group_arn             = "${aws_alb_target_group.api.arn}"
     # ...
   }

   module "api_canary_ecs_service" {
     source                       = "git@github.com:voyagegroup/tf_aws_ecs//service_load_balancing"
     name                         = "api_canary"
     cluser_id                    = "${module.ecs_cluster.cluster_id}"
     cluster_name                 = "${module.ecs_cluster.cluster_name}"
     target_group_arn             = "${aws_alb_target_group.api_canary.arn}"
     # ...
   }
