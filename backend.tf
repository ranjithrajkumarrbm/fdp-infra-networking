terraform {
  # Partial backend configuration. The remaining values are supplied at
  # `terraform init` time by the CI pipelines via -backend-config:
  #   -backend-config="bucket=<state-bucket>"
  #   -backend-config="key=fdp-infra-networking/<env>/terraform.tfstate"
  #   -backend-config="region=eu-west-2"
  #
  # Native S3 state locking (Terraform >= 1.10) is used, so no DynamoDB
  # lock table is required.
  backend "s3" {
    use_lockfile = true
    encrypt      = true
  }
}
