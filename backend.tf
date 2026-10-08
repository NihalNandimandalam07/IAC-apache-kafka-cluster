terraform {
  backend "s3" {
    bucket       = "kafka-terraform-state-backend-nn"
    key          = "kafka-cluster/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}