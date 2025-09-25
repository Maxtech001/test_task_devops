
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "interview-solution"
}

variable "allowed_ip" {
  description = "CIDR allowed to access EC2 over SSH/HTTP"
  type        = string
  default     = "88.196.208.91/32"
}

variable "instance_type" {
  description = "EC2 instance type for the ASG"
  type        = string
  default     = "t3.micro"
}

variable "additional_volume_sizes" {
  description = "Sizes (GiB) for /dev/xvdb and /dev/xvdc"
  type        = list(number)
  default     = [10, 10]
}

variable "key_name" {
  description = "Optional EC2 key pair for SSH; leave empty to disable"
  type        = string
  default     = ""
}

# End of variables.tf