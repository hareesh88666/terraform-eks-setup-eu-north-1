variable "region" {
  type    = string
  default = "eu-north-1"
}

variable "cluster_name" {
  type    = string
  default = "tf-eks-cluster"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.100.0/24", "10.0.101.0/24"]
}

variable "node_group_name" {
  type    = string
  default = "tf-eks-ng"
}

variable "node_instance_type" {
  type    = string
  default = "t3.small"
}

variable "node_desired_capacity" {
  type    = number
  default = 3 
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}
variable "aws_region" {
  description = "AWS region to deploy EKS"
  default     = "eu-north-1"
}
