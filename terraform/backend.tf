terraform {
  backend "s3" {
    bucket       = "ironhaven-tfstate-084824953530-eu-west-3"
    key          = "ironhaven/development/terraform.tfstate"
    region       = "eu-west-3"
    encrypt      = true
    use_lockfile = true
  }
}
