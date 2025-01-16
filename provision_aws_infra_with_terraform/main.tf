# Directory Structure
# terraform-aws-infra/
# ├── main.tf
# ├── variables.tf
# ├── outputs.tf
# ├── README.md

# main.tf
provider "aws" {
  region = var.region
}

module "s3_backend" {
  source = "./modules/s3-backend"

  bucket_name = var.bucket_name
  dynamodb_table = var.dynamodb_table
  region = var.region
}

module "ec2_cluster" {
  source = "./modules/ec2-cluster"

  instance_count = var.instance_count
  instance_type = var.instance_type
  key_name = var.key_name
  vpc_id = var.vpc_id
  subnet_ids = var.subnet_ids
  security_group_ids = var.security_group_ids
}

# variables.tf
variable "region" {
  description = "AWS region"
  type = string
  default = "us-east-1"
}

variable "bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type = string
}

variable "dynamodb_table" {
  description = "Name of the DynamoDB table for state locking"
  type = string
}

variable "instance_count" {
  description = "Number of EC2 instances"
  type = number
  default = 2
}

variable "instance_type" {
  description = "EC2 instance type"
  type = string
  default = "t2.micro"
}

variable "key_name" {
  description = "Key pair name for EC2 instances"
  type = string
}

variable "vpc_id" {
  description = "VPC ID where instances will be deployed"
  type = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type = list(string)
}

# outputs.tf
output "s3_bucket" {
  description = "S3 bucket name for Terraform state"
  value = module.s3_backend.bucket_name
}

output "ec2_instance_ids" {
  description = "IDs of EC2 instances"
  value = module.ec2_cluster.instance_ids
}

# README.md
# Terraform AWS Infrastructure Module

This Terraform module provisions:
- An S3 bucket and DynamoDB table for state management.
- A cluster of EC2 instances with customizable instance types and counts.

## Inputs
- `region`: AWS region for provisioning resources.
- `bucket_name`: Name of the S3 bucket.
- `dynamodb_table`: Name of the DynamoDB table.
- `instance_count`: Number of EC2 instances.
- `instance_type`: Type of EC2 instances.
- `key_name`: Key pair for EC2 SSH access.
- `vpc_id`: VPC ID for the EC2 cluster.
- `subnet_ids`: Subnet IDs for deploying EC2 instances.
- `security_group_ids`: Security group IDs for EC2 instances.

## Outputs
- `s3_bucket`: Name of the S3 bucket.
- `ec2_instance_ids`: List of EC2 instance IDs.

## Usage
```hcl
module "aws_infra" {
  source = "path/to/terraform-aws-infra"

  bucket_name = "my-terraform-state"
  dynamodb_table = "my-terraform-locks"
  region = "us-east-1"
  instance_count = 3
  instance_type = "t3.medium"
  key_name = "my-key-pair"
  vpc_id = "vpc-123456"
  subnet_ids = ["subnet-123456", "subnet-654321"]
  security_group_ids = ["sg-123456"]
}
