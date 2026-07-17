terraform {
  backend "s3" {
    bucket       = "final-project-terraform-state-539896451836"
    key          = "final-project/terraform.tfstate"
    region       = "il-central-1"
    encrypt      = true
    use_lockfile = true
  }
}