variable "aws_region" {
  description = "AWS region used to deploy Ironhaven resources."
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
  default     = "Ironhaven"

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+$", var.project_name))
    error_message = "The project name may contain only letters, numbers and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "The environment must be development, staging or production."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block assigned to the VPC."
  type        = string
  default     = "10.42.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "The VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "IPv4 CIDR block assigned to the public subnet."
  type        = string
  default     = "10.42.10.0/24"

  validation {
    condition     = can(cidrnetmask(var.public_subnet_cidr))
    error_message = "The public subnet CIDR must be a valid IPv4 CIDR block."
  }
}

variable "private_app_subnet_cidr" {
  description = "IPv4 CIDR block assigned to the private application subnet."
  type        = string
  default     = "10.42.20.0/24"

  validation {
    condition     = can(cidrnetmask(var.private_app_subnet_cidr))
    error_message = "The application subnet CIDR must be a valid IPv4 CIDR block."
  }
}

variable "private_data_subnet_cidr" {
  description = "IPv4 CIDR block assigned to the private data subnet."
  type        = string
  default     = "10.42.30.0/24"

  validation {
    condition     = can(cidrnetmask(var.private_data_subnet_cidr))
    error_message = "The data subnet CIDR must be a valid IPv4 CIDR block."
  }
}