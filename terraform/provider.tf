provider "aws" {
  region = "eu-west-3"

  default_tags {
    tags = {
      Project     = "Ironhaven"
      Environment = "development"
      ManagedBy   = "Terraform"
    }
  }
}

