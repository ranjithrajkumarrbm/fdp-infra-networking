# fdp-infra-networking

Terraform for the **FDP** AWS networking layer in **London (`eu-west-2`)**.

It provisions a VPC per environment with:

| Tier              | Count | Purpose                                              | Internet |
|-------------------|-------|-----------------------------------------------------|----------|
| `public`          | 2     | Internet Gateway + NAT Gateway(s), public LBs        | in/out   |
| `private-app`     | 2     | EKS worker nodes / pods                              | egress via NAT |
| `private-db`      | 2     | PostgreSQL / RDS                                     | isolated |

Plus: route tables + associations for every tier, security groups for EKS and
PostgreSQL, and **gateway VPC endpoints for S3 and DynamoDB**.

## Layout

```
.
├── vpc_main.tf          # root: locals (dev/prod config sets) + VPC module call
├── providers.tf         # AWS provider (region = eu-west-2, default_tags)
├── backend.tf           # S3 backend (partial - values passed at init)
├── versions.tf          # Terraform + provider version constraints
├── outputs.tf           # root outputs (re-exported from the module)
└── modules/
    └── vpc/
        ├── vpc.tf        # VPC, subnets, IGW, NAT, RTs, SGs, endpoints
        ├── variables.tf
        ├── outputs.tf
        └── versions.tf
```

## Environments

Region is fixed. A single `environment` variable (`dev` | `prod`) selects one of
two local config sets in [vpc_main.tf](vpc_main.tf). Every resource is named from
a computed prefix:

```
prefix = "<app_name>-<env_name>-<region_short_name>"   # e.g. fdp-dev-euw2
```

| Setting             | dev            | prod           |
|---------------------|----------------|----------------|
| VPC CIDR            | `10.0.0.0/16`  | `10.1.0.0/16`  |
| NAT gateways        | 1 (shared)     | 2 (one per AZ) |
| DB subnet egress    | off            | off            |

State is stored per environment at
`s3://<bucket>/fdp-infra-networking/<env>/terraform.tfstate`.

## Running locally

```bash
terraform init \
  -backend-config="bucket=<your-tf-state-bucket>" \
  -backend-config="region=eu-west-2" \
  -backend-config="key=fdp-infra-networking/dev/terraform.tfstate"

terraform plan  -var="environment=dev"
terraform apply -var="environment=dev"
```

### Backend bootstrap (one-time)

The S3 state bucket must exist before the first `init`. Native S3 locking
(Terraform ≥ 1.10) is used, so no DynamoDB table is needed. Suggested:

```bash
aws s3api create-bucket --bucket <your-tf-state-bucket> --region eu-west-2 \
  --create-bucket-configuration LocationConstraint=eu-west-2
aws s3api put-bucket-versioning --bucket <your-tf-state-bucket> \
  --versioning-configuration Status=Enabled
```

## CI/CD

Three GitHub Actions workflows under [.github/workflows/](.github/workflows/):

| Workflow                  | Triggers                                              | Action |
|---------------------------|------------------------------------------------------|--------|
| `terraform-plan.yml`      | PR to `main`, or manual dispatch (choose env)         | `fmt` + `validate` + `plan`; posts the plan as a PR comment. On a PR it plans **both** dev and prod. |
| `terraform-apply.yml`     | push to `main` (→ dev), or manual dispatch (choose env)| `terraform apply -auto-approve` |
| `terraform-destroy.yml`   | manual dispatch only; requires typing `destroy`       | `terraform destroy -auto-approve` |

### AWS access

The workflows authenticate with `aws-actions/configure-aws-credentials` using
static keys. Configure in the repo (Settings → Secrets and variables → Actions):

**Secrets**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

**Variables**
- `TF_STATE_BUCKET` — name of the S3 bucket holding Terraform state

For per-environment credentials/approvals, create GitHub **Environments** named
`dev` and `prod` and attach the secrets / required reviewers there — the
workflows already set `environment:` accordingly. To switch to OIDC instead of
static keys, replace the `aws-access-key-id`/`aws-secret-access-key` inputs with
`role-to-assume: <role-arn>` and add `permissions: id-token: write`.
