# SCF_LS first attempt

Terraform for the diagrammed SCF/LOS layout: one VPC, one NAT Gateway, an internet-facing ALB, an internal ALB, EC2 tiers, and one S3 bucket. This is the first attempt. It is not a production build, and it does not deploy the Veefin application.

Remote state is not configured. Local state is a block on apply until that standard is chosen. Do not run `terraform apply`.

## What is in this stack

| Diagram item | What this stack creates |
| --- | --- |
| External load balancer, port 443 | Internet-facing ALB in two public subnets |
| DMZ web x2 | EC2 in the public subnets, stock Nginx container. No public IPv4 address |
| Internal load balancer, port 443 | Internal ALB in two MZ subnets |
| MZ web x2 | EC2 in MZ subnets, stock Nginx. Not an ALB target |
| App Server 1 and 2 | EC2, placeholder container, internal ALB target |
| Reporting App Server 1 and 2 | EC2, placeholder container, internal ALB target |
| RabbitMQ x3 | EC2. Terraform does not form the cluster |
| Redis x3 | EC2. Terraform does not configure replication |
| Firewall before the databases | Security groups. Not AWS Network Firewall. No custom NACLs |
| Core DB and Reporting DB | One EC2 each, MySQL in Docker, separate encrypted data volume |
| NFS / object storage | One S3 bucket through `modules/s3` |

WAF is not created. The diagram's WAF is a third party. There is no `0.0.0.0/0` default on the external ALB.

Subnet placement:

| Tier | What is placed there |
| --- | --- |
| Public | External ALB, DMZ web 1 and 2, and the NAT Gateway |
| Private MZ | Internal ALB, MZ web, app servers, and reporting app servers |
| Private data | RabbitMQ, Redis, Core DB, and Reporting DB |

The network module still creates the private subnets in the dmz CIDR range. DMZ web instances are not placed in them.

Public subnet placement does not by itself give an EC2 instance a public IP. The current EC2 module has public IP assignment disabled. Therefore, DMZ web instances in public subnets will not have direct internet connectivity unless an approved public-IP/egress design is added.

Internet clients reach the external ALB only. The DMZ web security group allows its target port from that ALB's security group, not from `0.0.0.0/0`. DMZ web egress to the internal ALB on 443 is unchanged.

## Out of scope

DR zone, WAF, ESB, VPN, CBS, SMS, mail, help desk, Route 53 records, the monitoring stack, AWS Backup, Kafka, MongoDB, RabbitMQ cluster formation, Redis replication, MySQL replication, and Veefin application deployment. RDS MySQL and EFS are alternatives that this stack does not build.

## Layout

```
SCF_LS/
  main.tf, variables.tf, outputs.tf, versions.tf, README.md
  diagram.tfvars.example
  minimal.tfvars.example
  modules/network     VPC, subnets, IGW, one NAT
  modules/security    security groups only
  modules/alb         ALBs, listeners, target groups
  modules/compute     instances, data volumes, boot script
```

The AWS provider is only in this root. Network, ALB, security, and compute take `vpc_id` and subnet IDs. They do not create a VPC of their own. The bucket comes from `../modules/s3`, unchanged.

Suggested instance types are not defaults. Counts and instance types are required on every tier.

| TDD size | Suggested type in the diagram example |
| --- | --- |
| Web 2 vCPU / 4 GiB | `c7i.large` |
| App 4 vCPU / 16 GiB | `m7i.xlarge` |
| DB 4 vCPU / 16 GiB | `m7i.xlarge` |
| RabbitMQ 2 vCPU / 4 GiB | `c7i.large` |
| Redis 2 vCPU / 4 GiB | `c7i.large` |

`diagram.tfvars.example` uses those types and the diagram counts. `minimal.tfvars.example` uses one instance of every tier, all `t3.micro`, including MySQL. Subnets still exist in two Availability Zones in both examples, because an ALB needs two zones.

## S3 environment names

`modules/s3` accepts only `dev`, `staging`, and `prod`. This stack uses the same three values.

| Name you use | Value to set |
| --- | --- |
| SIT | `dev` |
| UAT | `staging` |
| Prod-DC | `prod` |
| Prod-DR | Out of scope. Do not map it |

That is a label limit of the shared module, not a separate account. No lifecycle or retention rules are set. The bucket blocks public access, enables versioning, encrypts with SSE-S3, and denies non-TLS requests. `force_destroy` stays false.

## Release lines

A tag is a required variable with no default. The example files use `REPLACE_ME` and name the line only. No patch tag is selected here.

Use the previous release line only when that line still receives security fixes. Otherwise use the oldest line that does.

| Component | Line used for this attempt | Deviation |
| --- | --- | --- |
| MySQL | 8.4 LTS | 8.0 reached end of life on 30 Apr 2026. Do not deploy 8.0 or 8.2 |
| RabbitMQ | 4.3.x | 4.2 community support ended 31 Jul 2026. 4.3 community support ends 30 Nov 2026, so plan an upgrade before that date. 3.12 and 3.13 are already out of community support |
| Redis | Previous minor of the latest that still receives fixes | Pending a legal license decision. 7.2 is end of life. Redis 8 is a different license family. Valkey is not in the TDD and is not substituted here. No tag is selected |
| Nginx | 1.30.x stable | Older lines, including 1.28, 1.26, and the TDD's 1.22, are not used. Those lines do not get security fixes |
| OS | Amazon Linux 2023 | The TDD asks for RHEL, Alma, or Rocky 8.8+ / 9.2+. The boot script uses `dnf` and the Amazon Linux `docker` package. It will not work on those distributions |

Image names are variables because Docker Hub tag existence was not checked from this repo. Check a tag with `docker buildx imagetools inspect <image>:<tag>` before you apply. Every instance pulls through one NAT address, so anonymous Docker Hub rate limits can fail the boot. An ECR pull-through cache is a later change, not this stack.

## First boot authentication

No password, token, or key is written in Terraform, in tfvars, in outputs, or in the boot script text. Where a test password is required, the instance creates it at first boot with `openssl rand -hex`, writes it as root mode `0600`, and does not print it. Terraform state stores the script, including the `openssl` and `cat` commands, not the generated value. Nothing in this stack reads those files back.

App and reporting containers are not given these values. They are placeholders and do not connect to MySQL, RabbitMQ, or Redis.

| Container | First boot | What it allows until something is wired |
| --- | --- | --- |
| MySQL | Random root password in `/root/mysql-root.password` (mode 0600). The container gets `MYSQL_ROOT_PASSWORD_FILE` pointing at that mounted file. The command does not set `MYSQL_ROOT_PASSWORD` | Network clients do not have the password. The app containers are not given the file |
| RabbitMQ | No `RABBITMQ_DEFAULT_USER` or password. No password file | The image's `guest` user works only on localhost inside the container. A connection to the published port cannot use `guest` |
| Redis | Random password written only inside `/root/redis.conf` (mode 0600) as `requirepass`. The server is `redis-server /root/redis.conf`. The password is not a process argument | Clients that do not present that password are rejected. The app containers are not given the file |
| Nginx | No authentication and no password file | The stock image serves its welcome page on HTTP port 80. Anyone who can pass the security group can read that page |

What this stack could not do:

- The official MySQL entrypoint reads `MYSQL_ROOT_PASSWORD_FILE` and then exports `MYSQL_ROOT_PASSWORD` into the process environment. After start, `docker inspect` can still show the password. Replacing that entrypoint would skip database initialization, so this stack does not replace it.
- The official Redis image runs as user `redis`, and its entrypoint drops to that user. That user cannot read a root-owned mode `0600` file. This stack starts `redis-server` as root, with the entrypoint replaced, so the server can read `/root/redis.conf` and the password stays off the command line. It does not run as the image's `redis` user.

If `rabbitmq_tls` is true, the boot script exits. This stack does not install RabbitMQ certificates. Mapping host port 5671 to container port 5672 would label plaintext as TLS, so both example files set `rabbitmq_tls = false`, `rabbitmq_client_port = 5672`, and `rabbitmq_management_port = 15672`. The TDD ports are 5671 and 15671. Those stay unused until a later change actually has certificates. The running container listens on plaintext 5672 and 15672. Flag that.

## How containers start

`systemctl enable --now docker` runs for every role before the container starts.

DMZ web and MZ web both install `/etc/systemd/system/nginx-container.service`. The unit has `Restart=always` and runs the pinned Nginx image in the foreground. The Docker command does not pass `--restart`. The published port is the tier `container_port` to container port 80.

Every other role uses `docker run -d --restart unless-stopped`. App and reporting-app run `placeholder_image` as `PLACEHOLDER-<tier>`, publishing `container_port` to container port 80. The examples use 8080 and 8081. Those containers are not the Veefin application and are not given the MySQL, Redis, or RabbitMQ credentials.

## Listeners, target groups, and port 443

Stock Nginx and the placeholder image speak HTTP. This stack does not generate a self-signed certificate at boot. Between each ALB and its instances, traffic is HTTP inside the VPC. The instance security groups allow that HTTP port from the ALB, not 443 on the instance. This is cleartext on the private network. Flag it.

| Target group | Protocol | Port | Health check |
| --- | --- | --- | --- |
| DMZ web, external ALB | HTTP | Tier `container_port` (80 in the examples) | HTTP `GET` on `health_check_path`, matcher `200`. Examples use `/` |
| App, internal ALB | HTTP | Tier `container_port` (8080 in the examples) | HTTP `GET` on `/`, matcher `200` |
| Reporting app, internal ALB | HTTP | Tier `container_port` (8081 in the examples) | HTTP `GET` on `/`, matcher `200` |

8080 and 8081 are placeholders, not the TDD microservice port list. The placeholder image must return 200 for `GET /` on container port 80. A stock Nginx image does. MZ web is not an ALB target.

The internal listener's default action forwards to the tier with `default_target = true` (the app tier in the examples). Other HTTP tiers need `path_patterns`. The example pattern `/reporting*` is a placeholder and is not from the TDD. Flag it.

The external listener forwards only to DMZ web. Stock Nginx does not reverse-proxy to the internal ALB. That wiring is not done.

Bank-staff ingress uses the MZ web `container_port` (80 in the examples) and only the CIDRs in `bank_staff_cidrs`. An empty list creates no rule. The diagram's 443-to-the-server path is not TLS on the instance, because the stock image is HTTP. Flag it.

### Certificate variables

`external_certificate_arn` and `internal_certificate_arn` are separate. `allow_insecure_external_listener` and `allow_insecure_internal_listener` default to false and are labelled TEST-ONLY.

Each ALB has its own precondition: its certificate is set, or its own insecure flag is true. If neither is set, Terraform fails. A certificate on one ALB does not satisfy the other.

| Certificate | Insecure flag | Listeners on that ALB |
| --- | --- | --- |
| Set | false | HTTPS 443 only |
| Null | true | HTTP 80 only, TEST-ONLY |
| Set | true | Both 443 and 80 |
| Null | false | Plan fails |

HTTPS listeners use `ELBSecurityPolicy-TLS13-1-2-2021-06`. Access logs are off, because they need a log-bucket policy this stack does not create. Flag that. `deletion_protection` defaults to false so a first attempt can be destroyed.

The external ALB security group admits 443, and port 80 only when `allow_insecure_external_listener` is true. Its only egress is TCP to the DMZ web security group on `container_port` (80 in both example files). That is the target-group port and the health-check port (`traffic-port`). It is not 443 on the instance.

The internal ALB security group admits 443 from DMZ web and MZ web, and port 80 from those same groups only when `allow_insecure_internal_listener` is true. Its egress is TCP to the app security group on each app `container_port` and to the reporting security group on each reporting `container_port`. Health checks use `traffic-port`, so they use those same ports. The examples are 8080 and 8081.

`aws_security_group` removes the default allow-all egress. Neither ALB security group has any other egress. They do not get the bootstrap 443-to-internet or DNS rules.

## Security group egress

Return traffic is allowed by the security group's state. The first packet of a new connection is not. Every security-group-to-security-group ingress rule has a matching egress rule on the source group.

| Source | Egress besides bootstrap |
| --- | --- |
| DMZ web and MZ web | TCP 443 to the internal ALB. TCP 80 to the internal ALB only when the TEST-ONLY internal listener is on |
| App and reporting | TCP `mysql_port` to MySQL, TCP `redis_port` to Redis, TCP client and management ports to RabbitMQ |
| RabbitMQ | TCP cluster ports to itself |
| Redis | TCP cluster ports to itself |
| External ALB | TCP DMZ target port to DMZ web |
| Internal ALB | TCP app target ports to app, TCP reporting target ports to reporting |

Bootstrap egress, kept on the seven instance groups only, is still TCP 443 to `0.0.0.0/0` plus TCP and UDP 53 to the VPC CIDR. That is image pull and SSM. It is not the east-west path.

Bank-staff CIDRs and the external ALB client CIDRs are ingress from a CIDR. There is no paired egress rule back to those CIDRs. Reply packets are covered by state.

There is no SSH, no RDP, and no key pair. There is no `0.0.0.0/0` ingress. Instances do not receive public IPv4 addresses. Public subnets set `map_public_ip_on_launch` to false.

The security-group path from app and reporting to MySQL, Redis, and RabbitMQ now exists. The containers are still not configured to use it. Stock Nginx still does not proxy to the internal ALB.

`enable_data_nat_route` defaults to true so the data subnets have a default route to the single NAT Gateway during bootstrap. Set it to false after bootstrap to remove that route. Turning it off also stops SSM and package installs on the database instances, because this stack creates no SSM VPC endpoints. Flag that.

One NAT Gateway, in the first public subnet, serves every private route that has a default route. If that Availability Zone fails, the other zone loses outbound internet. Flag that. Public IPv4 on this stack is the NAT address plus the internet-facing ALB's addresses. The internal ALB has no public address.

## Plan role permissions

This list is inferred from the resources and data sources in this root. It was not produced by an AWS plan. Apply needs the matching create, modify, and delete actions and is broader. Those apply actions are not listed here.

A first plan, with empty state, calls:

| Action | When |
| --- | --- |
| `sts:GetCallerIdentity` | Every plan. `allowed_account_ids` uses it |
| `ssm:GetParameter` | Only when `ami_id` is null. Parameter `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64` |

A later plan refreshes what is already in state. That read set is:

| Service | Read actions the refresh uses |
| --- | --- |
| EC2 | Describe VPC, subnets, route tables, internet gateway, NAT gateway, addresses, security groups, security group rules, instances, volumes, and their tags |
| Elastic Load Balancing | Describe load balancers, listeners, listener rules, target groups, and target health registrations |
| S3 | Get bucket location, tagging, encryption, versioning, public access block, and bucket policy |
| IAM | Get role, get instance profile, list attached role policies. Only if this stack created the profile, or you are refreshing that role. Set `create_instance_profile` to false and pass `existing_instance_profile_name` if the plan role cannot create roles |

`data "aws_region"` reads the provider configuration. It is not an AWS API call. `AmazonSSMManagedInstanceCore` is attached only when this stack creates the instance role. That managed policy is broader than a hand-written SSM policy. It is the support set for the SSM agent. A permissions boundary is applied only in that same case, and only if `permissions_boundary_arn` is set.

## Estimated cost

Estimate only. Not a Price List API query, and not a quote. Confirm in the AWS Pricing Calculator for the account's region before anyone applies.

Assumptions: 730 hours in a month, on-demand Linux, no Savings Plans. Rounded public rates used for the arithmetic: `t3.micro` $0.0104/hour, `c7i.large` $0.089/hour, `m7i.xlarge` $0.202/hour, gp3 $0.08/GB-month, ALB $0.0225/hour each, NAT Gateway $0.045/hour, in-use public IPv4 $0.005/hour. Those hourly figures are the planning rates behind the table. A different region changes them.

Minimal shape: 8 x `t3.micro`, root 30 GiB each, two data volumes of 20 GiB. Diagram shape: 4 x `c7i.large` web, 2 x `m7i.xlarge` app, 2 x `m7i.xlarge` reporting, 3 x `c7i.large` RabbitMQ, 3 x `c7i.large` Redis, 2 x `m7i.xlarge` database, root 30 GiB each, two data volumes of 50 GiB. Both shapes: 2 ALBs, 1 NAT, 3 public IPv4 addresses (1 NAT + 2 ALB zone addresses).

| Item | Minimal per day | Minimal per month | Diagram per day | Diagram per month |
| --- | --- | --- | --- | --- |
| EC2 | $2.00 | $61 | $50.45 | $1,534 |
| EBS gp3 | $0.74 | $22 | $1.52 | $46 |
| 2 ALBs, base only | $1.08 | $33 | $1.08 | $33 |
| NAT Gateway, base only | $1.08 | $33 | $1.08 | $33 |
| Public IPv4, 3 addresses | $0.36 | $11 | $0.36 | $11 |
| S3, empty bucket | about $0 | $0 to $1 | about $0 | $0 to $1 |
| Data transfer, NAT processing, ALB LCU | not estimated (usage) | not estimated (usage) | not estimated (usage) | not estimated (usage) |

EBS in the table is root plus the two MySQL data volumes. Redis and RabbitMQ data sit on the root volume. Flag that. The shared EC2 module caps root disks at 100 GiB for its own tests. This stack allows 8 to 200 GiB. The cap was a test limit, not a security control.

## Variables

| Variable | Required or optional | Notes |
| --- | --- | --- |
| `aws_region`, `allowed_account_ids`, `name_prefix`, `owner`, `team`, `environment` | Required | Environment is `dev`, `staging`, or `prod` |
| `vpc_cidr`, `availability_zones` | Required | Exactly two zone names. This stack does not look them up |
| `alb_ingress_cidrs` | Required | No default |
| `tiers` | Required | Counts and instance types have no defaults |
| `nginx_image`, `placeholder_image`, `rabbitmq_image`, `redis_image`, `mysql_image` | Required | Tag included. No default |
| `rabbitmq_tls`, `rabbitmq_client_port`, `rabbitmq_management_port`, `rabbitmq_cluster_ports` | Required | Cluster ports have no default |
| `redis_port`, `redis_cluster_ports`, `mysql_port` | Required | Cluster ports have no default |
| `bucket_name` | Required | Lowercase, no underscores |
| `external_certificate_arn`, `internal_certificate_arn` | Optional, default null | Each ALB has its own precondition |
| `allow_insecure_external_listener`, `allow_insecure_internal_listener` | Optional, default false | TEST-ONLY |
| `create_instance_profile` | Optional, default false | Examples set true so a test plan is self-contained |
| `existing_instance_profile_name` | Required when the toggle above is false | |
| `permissions_boundary_arn` | Optional | Used only if this stack creates the role |
| `ami_id` | Optional, default null | Null selects Amazon Linux 2023 via SSM. Setting it skips that lookup. Changing AMI replaces instances |
| `enable_data_nat_route` | Optional, default true | Turn off after bootstrap |
| `bank_staff_cidrs` | Optional, default `[]` | Empty means no MZ ingress |
| `subnet_newbits` | Optional, default 8 | `/16` becomes eight `/24` subnets |
| `deletion_protection` | Optional, default false | |
| `additional_tags` | Optional | `Name`, `Owner`, `Team`, `Environment`, and `ManagedBy` win |

Provider default tags and the S3 module tags use the same Owner, Team, Environment, and ManagedBy values, so AWS provider 5 does not perpetual-diff those keys.

## Guardrails copied from the shared EC2 module

The compute module duplicates these settings because `modules/ec2` cannot take a user-data script, an extra volume, or an instance profile without a breaking change. `modules/ec2` was not edited. This duplication is technical debt.

- IMDSv2 required (`http_tokens = required`), hop limit 1. Containers cannot use the instance role. The SSM agent on the host can.
- Root volume gp3, encrypted, deleted with the instance.
- No public IPv4 on instances.
- T3 `cpu_credits = standard` only when the instance type matches `t` plus a digit. Other types do not set credit specification.
- Detailed monitoring off.
- Tags `Name`, `Owner`, `Team`, `Environment`, `ManagedBy`.
- No key pair and no SSH.

MySQL data volumes are encrypted gp3, attached at `/dev/sdf`, and are not deleted when the instance is terminated from the console. `terraform destroy` still deletes them, because they are resources in this state. There are no backups in this stack. The boot script formats the disk only when it has no filesystem, mounts it at `/var/lib/scf-mysql`, and gives that directory to the MySQL container. On Nitro instances the device name appears as an NVMe disk. The script waits for a non-root disk.

Changing user data replaces the instance. AMI and user data are not ignored.

## How to run

From `SCF_LS`:

```bash
terraform fmt -recursive
terraform init -backend=false
terraform validate
```

Then, with company credentials, you run plan. This repository does not run plan or apply for you.

```bash
terraform plan -var-file=diagram.tfvars.example -out=tfplan
terraform show -no-color tfplan > plan.txt
```

Use `minimal.tfvars.example` instead for the small shape. Replace `REPLACE_ME` values first, or plan will fail on the region, the zone names, and the image names. `tfplan` and `plan.txt` are sensitive and gitignored. Do not commit them. `.terraform.lock.hcl` is committed after init.

`init -backend=false` does not talk to an AWS account. `validate` does not either. `plan` does.

## Known limits

- Stock Nginx does not proxy to the internal ALB.
- Placeholder containers are not the Veefin application and are not given MySQL, Redis, or RabbitMQ credentials. The security-group path to those ports exists.
- RabbitMQ test boot is plaintext on 5672 and 15672. The TDD ports 5671 and 15671 are not opened. Both example files set `rabbitmq_tls = false`.
- ALB-to-instance traffic is HTTP inside the VPC.
- The boot script is Amazon Linux 2023-specific.
- S3 environment labels are only `dev`, `staging`, and `prod`.
- One NAT Gateway.
- ALB access logs are off.
- No flow logs, no WAF, no Route 53, no backup, no ECR, no customer-managed KMS key. EBS encryption uses the `aws/ebs` key.
- Reporting is in this attempt at the diagram's two instances. A separate reporting build is not blocked by missing counts anymore. The path pattern is still a placeholder.
- TDD sizing lists two web servers. The diagram has two web groups (DMZ and MZ). This stack creates both groups. Flag the extra group against the TDD count.
- TDD splits LOS and SCF app servers. The diagram shows App Server 1 and 2. The `tiers` map can gain `los` and `scf` keys with role `app` later, without a code change. The examples use one `app` key.
