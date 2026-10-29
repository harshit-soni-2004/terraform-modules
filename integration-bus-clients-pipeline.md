# integration-bus-clients pipelines

This describes `bitbucket-pipelines.yml` for the Veefin SCF 4.0 repo `integration-bus-clients`. Every step runs on a self-hosted Linux shell runner. Bitbucket does not start a Docker image for these steps. Java, Maven, Docker, `curl`, `ssh`, and `rsync` come from the runner machine.

Two machines match the label `runner`: `github-runner-1` (also labeled `runner1`) and `github-runner-2` (also labeled `runner2`). Bitbucket picks either one.

## How the file is organized

`definitions.steps` declares four step templates and names them with YAML anchors (`&build`, `&docker-build`, `&deploy-to-ec2`, `&deploy-jar-to-qa`). `pipelines` does not repeat those steps. It points at them with `*build` and the other anchors.

`<<: *deploy-to-ec2` copies the EC2 deploy step and then sets a Bitbucket deployment environment (`dev`, `uat`, or `development`). The script stays the same. The environment changes which deployment variables Bitbucket injects.

## The four steps

### Build (`&build`)

Runs on every push to `development`, `QA`, and `master`, and as the first step of `manual-deploy-scf4-qa-jar`.

```yaml
- chmod +x ./build.sh
- ./build.sh
```

Artifacts kept for later steps in the same pipeline: `target/*.jar`.

`build.sh` does four things, in order:

1. Sets `JAVA_HOME` to Java 21 on the runner. The assignment is not exported.
2. Deletes `~/.m2/repository/com/veefin` so Maven re-downloads Veefin libraries.
3. Reads the project version with `mvn help:evaluate -Dexpression=project.version -q -DforceStdout`, then runs `mvn clean install -DskipTests`.
4. Rsyncs the built output to the shared Maven host `maven.veefin.in`. The second rsync uses the version string from step 3 as a directory name.

The script has no `set -e`. The pipeline step fails only when the last command exits non-zero.

### Build & Push Docker Image to ECR (`&docker-build`)

Used by the manual Docker deploy pipelines and by `docker-build-only`.

```yaml
- sed -i 's/\r$//' ./docker-build.sh
- chmod +x ./docker-build.sh
- ./docker-build.sh
```

`sed` strips Windows CRLF endings so the shell on the runner can execute the file. The script body is not in this workspace. From the step name, `docker-build.sh` builds the image and pushes it to Amazon ECR.

### Deploy to EC2 (`&deploy-to-ec2`)

Runs only after a Docker build, in the manual PSB and Invest pipelines. The calling pipeline sets `deployment`, so this step sees that environment's variables.

```yaml
- sed -i 's/\r$//' deploy-to-ec2.sh
- chmod +x ./deploy-to-ec2.sh
- ./deploy-to-ec2.sh
```

Same CRLF cleanup as the Docker step. The script body is not in this workspace. From the step name, `deploy-to-ec2.sh` takes the image that `docker-build.sh` pushed and deploys it to an EC2 host chosen by the deployment variables.

### Deploy JAR to scf4qa (`&deploy-jar-to-qa`)

Runs only as the second step of `manual-deploy-scf4-qa-jar`. Bitbucket environment: `test`. The commands are inline in the YAML. There is no shell file.

| Action | What it uses |
|---|---|
| Download | `https://maven.veefin.in/core/com/veefin/external-integration/0.0.1-QA/external-integration-0.0.1-QA.jar` saved locally as `external-integration.jar`. `curl -fL` fails the step if the download fails. |
| SSH to `15.206.9.130` | User is `$SCF4_QA_SSH_USER`. Creates `/home/ec2-user/java-dev/api_integration`. If `api_integration.jar` is already there, renames it to `api_integration.jar_<timestamp>.bak`. |
| SCP | Uploads the downloaded file as `/home/ec2-user/java-dev/api_integration/api_integration.jar`. |
| Restart | `sudo systemctl restart api-integration.service`, waits 2 seconds, then `systemctl is-active`. A service that is not active fails the step. |
| Cleanup | Deletes the local `external-integration.jar` on the runner. |

This step does not deploy `target/*.jar` from the Build step. It always downloads `external-integration-0.0.1-QA.jar`.

## Which pipeline runs which steps

Pushes run automatically. Custom pipelines run only when someone starts them in Bitbucket.

| Pipeline | Trigger | Steps |
|---|---|---|
| `development` | Push to branch `development` | Build |
| `QA` | Push to branch `QA` | Build |
| `master` | Push to branch `master` | Build |
| `manual-deploy-scf4-psb-dev` | Manual | Docker build and push, then Deploy to EC2 with environment `dev` |
| `manual-deploy-scf4-psb-uat` | Manual | Docker build and push, then Deploy to EC2 with environment `uat` |
| `manual-deploy-scf4-invest-dev` | Manual | Docker build and push, then Deploy to EC2 with environment `development` |
| `manual-deploy-scf4-qa-jar` | Manual | Build, then Deploy JAR to scf4qa with environment `test` |
| `docker-build-only` | Manual | Docker build and push |

```text
push to development / QA / master
  └── Build (build.sh → maven.veefin.in)

manual-deploy-scf4-qa-jar
  ├── Build (build.sh → maven.veefin.in)
  └── Deploy JAR to scf4qa
        └── download external-integration-0.0.1-QA.jar
            → scp to 15.206.9.130 as api_integration.jar
            → restart api-integration.service

manual-deploy-scf4-psb-dev | psb-uat | invest-dev
  ├── docker-build.sh → ECR
  └── deploy-to-ec2.sh → EC2 for that deployment environment

docker-build-only
  └── docker-build.sh → ECR
```

## Where runs #49–#52 fail

Those runs are the automatic `development` pipeline, so the only step is Build. `mvn clean install` reaches `BUILD SUCCESS`. The step fails in `build.sh` on the second rsync: `MVN_VERSION` is `0.0.1-QA` with a trailing ANSI reset (`ESC[0m`), the directory does not exist, and rsync exits 3.

`manual-deploy-scf4-qa-jar` starts with that same Build step, so it stops before the QA download and restart.
