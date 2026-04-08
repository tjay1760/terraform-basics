provider "aws" {
  region = "us-east-1"
  
}
data "aws_ami" "ubuntu_22_04" {
  most_recent = true

    filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

data "aws_vpc" "name" {
    default =  true
  
}
data "aws_availability_zones" "all" {
  
}
data "aws_subnets" "name" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.name.id]
  }

  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c"]
  }
}
resource "aws_launch_template" "example" {
    name_prefix = "my-dynamic-server"
  image_id                    = data.aws_ami.ubuntu_22_04.id
  instance_type               = var.instance_type


  user_data = base64encode(
    <<-EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd


cd /home/ec2-user
echo "Hi there mate" > /var/www/html/index.html

EOF
  )
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "instance" {
  name = "terraform-security-instance"
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
      from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }
  egress {
    from_port = var.egress_port
    to_port = var.egress_port
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "alb" {
  name = "terraform-security-alb"
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
      from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }
  egress {
    from_port = var.egress_port
    to_port = var.egress_port
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_autoscaling_group" "example" {
min_size = 2
max_size = 10

vpc_zone_identifier = data.aws_subnets.name.ids

launch_template {
  id = aws_launch_template.example.id
  version = "$Latest"
}

target_group_arns = [ aws_lb_target_group.web.arn
 ]

 health_check_type = "ELB"
 health_check_grace_period = 200
tag {
  key ="Name"
  value = "terraform_asg_example"
  propagate_at_launch = true
}
}

resource "aws_lb" "application" {
  name               = "application-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets =  data.aws_subnets.name.ids 

  enable_deletion_protection = false

  tags = {
    Environment = "development"
  }
}
resource "aws_lb_target_group" "web" {
  name = "web-target-group"
port = var.server_port
protocol = "HTTP"
vpc_id = data.aws_vpc.name.id

health_check {
  path = "/"
  port = var.server_port
  interval = 30
  timeout = 5
  healthy_threshold = 2
  unhealthy_threshold = 2
}
tags = {
    name = "terraform-target-group"
}
}
resource "aws_lb_listener" "webserver_listener" {
  load_balancer_arn = aws_lb.application.arn
  port = var.server_port
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
  tags = {
    Name = "alb-listenerS"
  }
}

output "alb_dns_name" {
  value = aws_lb.application.dns_name
}