# Terraform modules for the internal developer platform

Reusable Terraform modules for a private S3 bucket, a single EC2 instance with its root EBS volume, and a single RDS instance. Internal teams such as LOS and SCF can call the same modules with their own inputs. No IDP product is wired up here. Backstage, Port, Humanitec, and similar tools are out of scope until the platform choice is confirmed.

These modules are for personal-account testing. They are not production-ready. `terraform validate` only checks that the configuration is internally consistent.

## What a Terraform module is

A module is a folder of Terraform files you call from another configuration, similar to a function. `variables.tf` is the input list, `main.tf` is the body, `outputs.tf` is the return values, and `versions.tf` declares which Terraform and provider versions the module needs. The caller decides the region and credentials. The module does not.

## Repository structure

```
terraform_poc/
  modules/
    ec2/          reusable EC2 instance and root volume
    s3/           reusable S3 bucket
    rds/          reusable RDS instance
  examples/
    dev/          one personal-account stack that calls those modules
  .gitignore
  README.md
```

Run Terraform from `examples/dev`, not from the repository root. The root used to call an S3 module directly. That caller was removed so there is only one place that creates resources.

## How a team consumes a module

LOS and SCF do not copy the module source, and this repo does not grow a variables file per team. One `examples/dev` stack calls the modules. The team changes `terraform.tfvars`. A future IDP would collect the same fields and generate that file. A call looks like:

```hcl
module "documents" {
  source = "../../modules/s3"

  bucket_name        = "los-dev-documents-<globally-unique-suffix>"
  versioning_enabled = false
  team               = "los"
  owner              = "los-platform"
  environment        = "dev"
}
```

`team` must match `^[a-z0-9-]+$` (lowercase letters, digits, hyphens). `los` and `scf` pass. `LOS` does not. That rule exists because the value may be copied into a name. It is an assumption, not a confirmed company standard.

## Current test assumptions

- One AWS account, yours, using the normal credential chain. No keys are stored in this repo.
- Example region defaults to `ap-south-1` because the original S3 proof of concept used that region. Change `aws_region` if you need somewhere else. Modules do not hardcode a region.
- Subnet and security group IDs come from `terraform.tfvars`. The example does not look up or create a VPC. Default-VPC subnets often assign public IPv4 addresses. The EC2 module still sets `associate_public_ip_address = false`.
- State is a local `terraform.tfstate` in `examples/dev` after you init there. It is gitignored. Do not commit it.
- There is no remote backend yet. The company backend (S3, DynamoDB locking, Terraform Cloud, or something else) is not decided. Local state has no locking and is easy to lose or leak.
- `examples/dev/terraform.tfvars` is the developer configuration. It is gitignored. Copy `terraform.tfvars.example` and replace the placeholders. `terraform plan` reads that file and should not prompt for normal values.
- `create_rds` defaults to `false`. A normal plan has no RDS instance, subnet group, or Secrets Manager secret.

Copy `examples/dev/terraform.tfvars.example` to `examples/dev/terraform.tfvars` and replace the placeholders before you plan. `terraform.tfvars` is gitignored.

## EC2 inputs

| Variable | Type | Default | Class | Description |
|---|---|---|---|---|
| `name` | string | none | REQUIRED | Name tag for the instance and root volume. |
| `subnet_id` | string | none | REQUIRED | Existing subnet. The module does not create a VPC. |
| `security_group_ids` | list(string) | none | REQUIRED | At least one existing security group. |
| `team` | string | none | REQUIRED | Lowercase team code. |
| `owner` | string | none | REQUIRED | Owner tag. |
| `ami_type` | string | `amazon_linux` | OPTIONAL | `amazon_linux` or `ubuntu`. The module resolves an x86_64 AMI ID in the caller region. |
| `instance_type` | string | `t3.micro` | OPTIONAL | Small x86_64 burstable type. Not a Free Tier guarantee. |
| `root_volume_size` | number | `8` | OPTIONAL | Root volume size in GiB. Minimum 8. |
| `root_volume_type` | string | `gp3` | OPTIONAL | `gp3` or `gp2` only. |
| `key_name` | string | `null` | OPTIONAL | Existing key pair name. No key pair is created. |
| `environment` | string | `dev` | OPTIONAL | `dev`, `staging`, or `prod`. |
| `additional_tags` | map(string) | `{}` | OPTIONAL | Extra tags. Cannot override platform tags or Name. |

### How the AMI is chosen

The developer sets `ami_type` to `amazon_linux` or `ubuntu`. The module turns that into an AMI ID. No AMI ID is entered in `terraform.tfvars`.

`amazon_linux` reads the public SSM parameter `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64`. That parameter holds the current Amazon Linux 2023 x86_64 AMI for the region on the AWS provider.

`ubuntu` uses an `aws_ami` data source owned by Canonical (`099720109477`). It selects the latest available Ubuntu 24.04 LTS (Noble) x86_64 HVM EBS image. The name filter accepts the gp3 and gp2 server image paths and requires an 8-character date suffix, so minimal images are not selected.

Both lookups follow the provider region. Neither hardcodes `ap-south-1` or an AMI ID. A later plan can propose replacing the instance when AWS publishes a newer image. `t3.micro` is x86_64. These lookups do not return Arm images. Any other `ami_type`, such as `windows`, fails validation.

### EC2 outputs

| Output | Description |
|---|---|
| `instance_id` | Instance ID. |
| `instance_arn` | Instance ARN. |
| `private_ip` | Private IPv4 address. |
| `public_ip` | Public IPv4 address, or null when there is none. |
| `availability_zone` | Availability Zone of the instance. |

## S3 inputs

| Variable | Type | Default | Class | Description |
|---|---|---|---|---|
| `bucket_name` | string | none | REQUIRED | Globally unique bucket name. |
| `team` | string | none | REQUIRED | Lowercase team code. |
| `owner` | string | none | REQUIRED | Owner tag. |
| `versioning_enabled` | bool | `true` | OPTIONAL | `true` keeps object versions. Versions add storage cost. AWS can only suspend versioning later, not fully disable it. |
| `environment` | string | `dev` | OPTIONAL | `dev`, `staging`, or `prod`. |
| `additional_tags` | map(string) | `{}` | OPTIONAL | Extra tags. Cannot override platform tags. |

### S3 outputs

| Output | Description |
|---|---|
| `bucket_name` | Bucket name. |
| `bucket_arn` | Bucket ARN. |
| `bucket_region` | Region of the caller provider. The bucket is created there. |

The original module already created the bucket, the public-access block, SSE-S3, and versioning. Those resources are unchanged in purpose. Versioning is now a variable, tags can be extended, and the region output was added. The old provider block inside the S3 module was removed so the caller controls the region.

`force_destroy` is left at the AWS default `false`. Destroying a bucket that still has objects will fail until you empty it. That avoids a module that silently deletes data.

## RDS inputs

Creating this module costs money. Destroy it when the test is finished. See the cost section below.

| Variable | Type | Default | Class | Description |
|---|---|---|---|---|
| `identifier` | string | none | REQUIRED | Unique DB identifier. Starts with a letter. Lowercase, digits, hyphens. |
| `security_group_ids` | list(string) | none | REQUIRED | At least one existing security group. |
| `engine_version` | string | none | REQUIRED | Exact version you have verified. No default. |
| `team` | string | none | REQUIRED | Lowercase team code. |
| `owner` | string | none | REQUIRED | Owner tag. |
| `subnet_ids` | list(string) | `null` | OPTIONAL | At least two subnets in different AZs. Creates a DB subnet group. Set this or `db_subnet_group_name`, not both. |
| `db_subnet_group_name` | string | `null` | OPTIONAL | Existing DB subnet group. Set this or `subnet_ids`, not both. |
| `engine` | string | `postgres` | OPTIONAL | Low-cost default, not a company standard. `mysql` is the other engine with a built-in port. |
| `instance_class` | string | `db.t3.micro` | OPTIONAL | Small class. Not a Free Tier guarantee. |
| `allocated_storage` | number | `20` | OPTIONAL | GiB. 20 is the minimum for PostgreSQL and MySQL on gp3. |
| `storage_type` | string | `gp3` | OPTIONAL | `gp3` or `gp2`. No provisioned IOPS. |
| `db_name` | string | `null` | OPTIONAL | Extra database created at launch. Null skips it. |
| `username` | string | `dbadmin` | OPTIONAL | Master username. The password is not an input. |
| `port` | number | `null` | OPTIONAL | Null becomes 5432 for postgres and 3306 for mysql. |
| `backup_retention_period` | number | `1` | OPTIONAL | Days of automated backups. 0 to 35. |
| `skip_final_snapshot` | bool | `true` | OPTIONAL | TEST-ONLY default. Destroy skips the final snapshot and drops the data. |
| `final_snapshot_identifier` | string | `null` | OPTIONAL | Required only when `skip_final_snapshot` is false. |
| `deletion_protection` | bool | `false` | OPTIONAL | TEST-ONLY default. Production may need `true`. |
| `environment` | string | `dev` | OPTIONAL | `dev`, `staging`, or `prod`. |
| `additional_tags` | map(string) | `{}` | OPTIONAL | Extra tags. Cannot override platform tags. |

`subnet_ids` and `db_subnet_group_name` are each optional, but one of them is required. RDS places the instance across subnets in at least two Availability Zones even when the instance itself is single-AZ. The DB subnet group has no hourly charge. This module does not create a VPC.

### Why `engine_version` has no default

A data source that picks the latest version would make two applies, with no code change, install different versions. A version string committed in the module would be reproducible until AWS retires it, and this repo should not guess which PostgreSQL release is still offered. You pin the version in the caller.

Check what your region offers before you set `create_rds = true`:

```bash
aws rds describe-db-engine-versions --engine postgres --region ap-south-1 --query "DBEngineVersions[].EngineVersion"
```

Use one of those strings as `rds_engine_version`. The `16.8` comment in `terraform.tfvars.example` is only an illustration. Confirm it before you use it.

`engine = "postgres"` is the default engine. It is a common low-cost choice, not a platform standard. `auto_minor_version_upgrade` is left at the AWS default (`true`). A pinned `16.8` can still move to a newer 16.x during a maintenance window. Say if you want that turned off.

### RDS outputs

| Output | Description |
|---|---|
| `db_instance_identifier` | DB identifier. |
| `endpoint` | `hostname:port`. Not a password. |
| `port` | Listening port. |
| `arn` | Instance ARN. |
| `master_user_secret_arn` | Secrets Manager ARN of the managed master password. The ARN is not the password. The secret value is not an output. |

### Test-only destroy behavior

`skip_final_snapshot = true` and `deletion_protection = false` make a personal test easy to remove. They also make it easy to delete the database with no snapshot. Those defaults must not be copied into production until the Platform team sets a policy.

## Security settings that are enforced

These are not variables. A caller cannot turn them off.

All taggable resources get `Owner`, `Team`, `Environment`, and `ManagedBy = "Terraform"`. Extra tags are merged in first, so they cannot replace those four. EC2 also sets `Name` the same way.

S3:

- Server-side encryption with SSE-S3 (`AES256`). No customer-managed KMS key, which would add a charge.
- All four S3 public-access-block settings are on.
- No public-bucket policy and no website hosting.

EC2:

- Root volume encrypted.
- Root volume deleted with the instance.
- IMDSv2 required (`http_tokens = "required"`).
- Detailed monitoring off.
- No Elastic IP.
- No public IPv4 address (`associate_public_ip_address = false`).
- Burstable (T-family) instances use standard CPU credits, not unlimited. Unlimited can add charges. Non-T types do not get that setting, because AWS rejects it for them.
- No SSH key is created. No SSM instance role is created. With the public IP forced off, you cannot SSH in from the internet. The console can still show the instance.

RDS:

- Storage encrypted with the AWS-managed RDS key.
- `publicly_accessible = false`.
- `multi_az = false` for this version. It is not a variable. Multi-AZ roughly doubles the instance charge. Revisit it when the Platform team asks.
- No read replica.
- No provisioned IOPS and no gp3 IOPS or throughput override above the included baseline.
- Performance Insights off.
- Enhanced monitoring off (`monitoring_interval = 0`).
- Master password is `manage_master_user_password = true`. RDS stores it in Secrets Manager. There is no password variable and no password output.

The managed password still has a footprint: Secrets Manager charges for the secret, and Terraform state stores the secret ARN. State is local and must not be committed. Anyone with the state file and IAM access could retrieve the secret. That is still safer than a password in git.

## What can incur charges

Free Tier eligibility depends on the account age, region, and the offer AWS is running. Do not treat these defaults as a promise of a $0 bill.

| Resource | When it costs money |
|---|---|
| EC2 | While the instance is running, even if idle. Stopped instances are not free of EBS charges. |
| EBS | You pay for the provisioned root volume (8 GiB gp3 by default, 10 GiB on the LOS profile) whether or not the instance is running. |
| Public IPv4 | A public address on the instance would be billable. The module forces this off. A default subnet can still bill other resources that do take a public address. |
| RDS | Instance hours, allocated storage (minimum 20 GiB), and backup storage beyond the included amount. This is the expensive resource. Leave `create_rds = false` unless you mean to test it, and destroy it afterwards. |
| Secrets Manager | About one secret per RDS instance, billed monthly, plus API calls. |
| S3 | Stored data, requests, and every object version kept when versioning is on. An empty bucket is cheap. It is not always free. |
| Data transfer | Traffic out to the internet. |

This stack does not create a NAT Gateway, Elastic IP, load balancer, autoscaling group, extra monitoring, Multi-AZ database, or read replica.

## Developer configuration

Copy `examples/dev/terraform.tfvars.example` to `examples/dev/terraform.tfvars`. That file is the configuration an IDP would eventually generate. LOS and SCF each keep their own values. They do not get a separate variables file.

Values with defaults (`ami_type`, `instance_type`, `root_volume_size`, `root_volume_type`, `environment`, `versioning_enabled`, `create_rds`) can be omitted. `team`, `owner`, `ec2_name`, `subnet_id`, `security_group_ids`, and `bucket_name` cannot be guessed, so the example file contains them. The sample subnet and security group use `x` on purpose and fail validation until you replace them with real IDs. `ami_type` defaults to `amazon_linux`. Change it to `ubuntu` to select Ubuntu 24.04. No AMI ID is required.

`key_name` defaults to null. The sample sets `los-dev-key` to show where an existing key pair name goes. Remove the line to launch without a key. No key pair is created.

## Commands

From `examples/dev`, after copying `terraform.tfvars.example` to `terraform.tfvars`:

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
terraform destroy
```

`fmt` can also be run from the repository root. `init` downloads the AWS provider and writes `.terraform.lock.hcl`. It does not create AWS resources. There is no remote backend to configure.

Review `terraform plan` before `apply`. With `create_rds = false` it should show one EC2 instance, its root volume, one S3 bucket, the public-access block, encryption, and versioning. It should show no RDS resources. It should not prompt for the values in `terraform.tfvars`.

`apply` and `destroy` are yours to run. Destroy every test resource when you are done, including the Secrets Manager secret created with RDS. An instance left running and a database left up continue to bill.

## Local state

`examples/dev` uses the Terraform default, a local state file, because the company remote-backend standard is not set. Local state is not shared, not locked, and not encrypted as a group. It can contain resource IDs and the RDS secret ARN. `.gitignore` excludes `*.tfstate`, `*.tfstate.*`, and `*.tfvars`. It does not exclude `.terraform.lock.hcl`. Commit the lock file when you are ready. Do not commit state.

The old root `terraform.tfstate` is empty and is left in place. It is gitignored. This change does not migrate that state. The example keeps its own state after the first apply.

## IDP

These modules are IDP-agnostic. They expose variables and outputs only. Nothing in this repo targets a specific internal developer portal.

## Not production-ready

Validation passing does not make this a production platform. Still missing:

- A remote backend and state locking.
- A confirmed tagging and naming standard. Team-code casing is an assumption.
- An approved AMI catalog. Today the choice is latest Amazon Linux 2023 or latest Ubuntu 24.04 x86_64, which can change over time.
- A platform-owned VPC and subnet source. Today the caller pastes subnet and security group IDs into tfvars.
- An RDS engine and version standard, backup retention, deletion protection, and final-snapshot policy.
- A secrets standard beyond "let RDS create one Secrets Manager secret".
- Multi-AZ, if production databases need it. This version forbids it on purpose.
- Guardrails around instance size and storage so a caller cannot request an expensive type. Today those values are validated only for a floor, not a ceiling.
- Pipeline checks, policy-as-code, and module versioning. Teams would copy this folder or point `source` at a git tag later. Nothing publishes a version yet.
- Login path. No SSM role and no public IP means no shell access.

Destroy all test resources after you finish checking the plan.
