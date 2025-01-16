# Region where AWS resources will be created
variable "region" {
  description = "AWS region for resource creation"
  type        = string
  default     = "us-east-1"
}

# S3 Bucket Name
variable "bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
}

# DynamoDB Table Name
variable "dynamodb_table" {
  description = "Name of the DynamoDB table for state locking"
  type        = string
}

# EC2 Instance Count
variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 2
}

# EC2 Instance Type
variable "instance_type" {
  description = "Type of EC2 instances to launch"
  type        = string
  default     = "t2.micro"
}

# Key Pair Name
variable "key_name" {
  description = "Key pair name for SSH access to EC2 instances"
  type        = string
}

# VPC ID
variable "vpc_id" {
  description = "VPC ID where the EC2 instances will be deployed"
  type        = string
}

# Subnet IDs
variable "subnet_ids" {
  description = "List of subnet IDs for EC2 instances"
  type        = list(string)
}

# Security Group IDs
variable "security_group_ids" {
  description = "List of security group IDs for EC2 instances"
  type        = list(string)
}
