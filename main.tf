provider "aws" {
  region = "us-east-1"
  profile = default
}
resource "aws_launch_configuration" "example" {
  image_id                    = "ami-02dfbd4ff395f2a1b"
  instance_type          = "t3.micro"
  security_groups = [aws_security_group.instance.id]
  associate_public_ip_address = true

  user_data = <<-EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd


cd /home/ec2-user
echo "Hi there mate" > /var/www/html/index.html

EOF
lifecycle {
  create_before_destroy = true
}
}

resource "aws_security_group" "instance" {
  name = "terraform-security-instance"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
      from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_autoscaling_group" "example" {
launch_configuration = aws_launch_configuration.example.name
min_size = 2
max_size = 10
tag {
  key ="Name"
  value = "terraform_asg_example"
  propagate_at_launch = true
}
}
