terraform {
  backend "s3" {
    bucket = "xxxxxx-terraform-state"
    key    = "tfstate"
    region = "us-east-2"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0.0"
    } 
  }
}

provider "aws" {
  region = "us-east-2"
}

variable "vpc_id" {
  default = "vpc-xxxxxxx"
}

variable "subnet_ids" {
  type = list(string)
  default = ["subnet-bbbbbb","subnet-fffffff","subnet-44444444"]
}

resource "aws_security_group" "my_instance_sg" {
  description = "My SG"
  vpc_id      = "${var.vpc_id}"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
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

resource "aws_security_group" "my_lb_sg" {
  description = "My SG"
  vpc_id      = "${var.vpc_id}"
  ingress {
    from_port   = 8000
    to_port     = 8000
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

resource "aws_launch_configuration" "my_lc" {
  image_id      = "ami-0233c2d874b811deb"
  instance_type = "t3.micro"
  key_name      = "kkkkkkk"
  root_block_device {
    volume_type = "gp2"
    volume_size = 8
  }
  user_data = <<EOF
  #!/bin/bash
  yum update -y
  touch /tmp/hello
  EOF
  security_groups = ["${aws_security_group.my_instance_sg.id}"]
}

resource "aws_lb" "my_elb" {
  load_balancer_type = "application"
  security_groups = ["${aws_security_group.my_lb_sg.id}"]
  subnets = ["${var.subnet_ids.0}", "${var.subnet_ids.1}", "${var.subnet_ids.2}"]
}

resource "aws_lb_target_group" "my_lb_tg" {
  port = 8080
  protocol = "HTTP"
  vpc_id = "${var.vpc_id}"
  health_check {
    path = "/health"
    interval = 30
    port = 8080
    timeout = 5
    healthy_threshold = 3
    unhealthy_threshold = 5
  }
}

resource "aws_lb_listener" "my_lb_listener" {
  load_balancer_arn = "${aws_lb.my_elb.id}"
  protocol = "HTTP"
  port = 8000
  default_action {
    target_group_arn = "${aws_lb_target_group.my_lb_tg.id}"
    type = "forward"
  }
}

resource "aws_autoscaling_group" "my_asg" {
  launch_configuration = "${aws_launch_configuration.my_lc.id}"
  min_size = 1
  max_size = 10
  desired_capacity = 1
  vpc_zone_identifier = ["${var.subnet_ids.0}", "${var.subnet_ids.1}", "${var.subnet_ids.2}"]
  target_group_arns = ["${aws_lb_target_group.my_lb_tg.id}"]
}
