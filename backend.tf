terraform {
  # State bucket and region are fixed for this project. Only `key` is supplied
  # at `terraform init` time (per environment) via:
  #   -backend-config="key=fdp-infra-networking/<env>/terraform.tfstate"
  #
  # Native S3 state locking (Terraform >= 1.10) is used, so no DynamoDB
  # lock table is required.
  backend "s3" {
    bucket       = "fdp-infra-state-bucket-861477414666-eu-west-2-an"
    region       = "eu-west-2"
    use_lockfile = true
    encrypt      = true
  }
}
