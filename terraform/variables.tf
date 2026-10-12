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
  description = "IPv4 CIDR block assigned to the first private data subnet."
  type        = string
  default     = "10.42.30.0/24"

  validation {
    condition     = can(cidrnetmask(var.private_data_subnet_cidr))
    error_message = "The first data subnet CIDR must be a valid IPv4 CIDR block."
  }
}

variable "private_data_secondary_subnet_cidr" {
  description = "IPv4 CIDR block assigned to the second private data subnet."
  type        = string
  default     = "10.42.31.0/24"

  validation {
    condition     = can(cidrnetmask(var.private_data_secondary_subnet_cidr))
    error_message = "The second data subnet CIDR must be a valid IPv4 CIDR block."
  }
}

variable "database_name" {
  description = "Initial PostgreSQL database created by RDS."
  type        = string
  default     = "ironhaven"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]*$", var.database_name))
    error_message = "The database name must start with a letter and contain only letters, numbers and underscores."
  }
}

variable "database_master_username" {
  description = "PostgreSQL master username. The password is generated and managed by AWS Secrets Manager."
  type        = string
  default     = "ironhaven_admin"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]*$", var.database_master_username))
    error_message = "The database username must start with a letter and contain only letters, numbers and underscores."
  }
}

variable "database_instance_class" {
  description = "RDS instance class used by the PostgreSQL lab database."
  type        = string
  default     = "db.t4g.micro"

  validation {
    condition     = startswith(var.database_instance_class, "db.")
    error_message = "The RDS instance class must start with db."
  }
}

variable "database_allocated_storage" {
  description = "Initial storage allocated to PostgreSQL in GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.database_allocated_storage >= 20
    error_message = "PostgreSQL requires at least 20 GiB of allocated storage for this configuration."
  }
}

variable "database_max_allocated_storage" {
  description = "Maximum storage autoscaling limit for PostgreSQL in GiB."
  type        = number
  default     = 30

  validation {
    condition     = var.database_max_allocated_storage >= var.database_allocated_storage
    error_message = "Maximum storage must be greater than or equal to the initial allocated storage."
  }
}
