########################
# AZs (pick two)
########################
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

########################
# VPC (2 public subnets across 2 AZs) — Flow Logs OFF
########################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = "10.50.0.0/16"

  azs            = local.azs
  public_subnets = ["10.50.11.0/24", "10.50.12.0/24"]

  enable_dns_support   = true
  enable_dns_hostnames = true

  # Disable VPC Flow Logs to avoid CloudWatch/deprecation noise
  enable_flow_log = false
}

########################
# Security Group
########################
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "Allow SSH/HTTP only from allowed IP"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
    description = "SSH from allowed IP"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
    description = "HTTP from allowed IP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

########################
# IAM for SSM (use name_prefix to avoid collisions)
########################
resource "aws_iam_role" "ec2_ssm_role" {
  name_prefix = "${var.project_name}-ec2-ssm-role-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name_prefix = "${var.project_name}-ec2-profile-"
  role        = aws_iam_role.ec2_ssm_role.name
}

########################
# AMI: Amazon Linux 2023 (x86_64)
########################
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"] # Amazon

  filter {
    name   = "name"
    values = ["al2023-ami-*x86_64"]
  }
}

########################
# Launch Template
########################
resource "aws_launch_template" "lt" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type
  key_name      = var.key_name != "" ? var.key_name : null

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = filebase64("${path.module}/user_data.sh")

  # Root volume
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 16
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  # Additional EBS volumes
  block_device_mappings {
    device_name = "/dev/xvdb"
    ebs {
      volume_size           = var.additional_volume_sizes[0]
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  block_device_mappings {
    device_name = "/dev/xvdc"
    ebs {
      volume_size           = var.additional_volume_sizes[1]
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${var.project_name}-ec2" }
  }
}

########################
# Auto Scaling Group (name_prefix to avoid collisions)
########################
resource "aws_autoscaling_group" "asg" {
  name_prefix         = "${var.project_name}-asg-"
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  vpc_zone_identifier = module.vpc.public_subnets

  health_check_type         = "EC2"
  health_check_grace_period = 60
  force_delete              = true   # helps tear down if targets stay attached

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

########################
# Get ASG instance IDs & IPs
########################
data "aws_instances" "asg" {
  depends_on = [aws_autoscaling_group.asg]

  # Instances auto-tagged with the created ASG name (use .id, not deprecated .name)
  instance_tags = {
    "aws:autoscaling:groupName" = aws_autoscaling_group.asg.id
  }

  filter {
    name   = "instance-state-name"
    values = ["pending", "running"]
  }
}

########################
# Outputs
########################
output "asg_instance_ids" {
  value = data.aws_instances.asg.ids
}

output "instance_public_ips" {
  value = data.aws_instances.asg.public_ips
}

output "instance_private_ips" {
  value = data.aws_instances.asg.private_ips
}

# End of main.tf
