# Deploying to AWS EC2

Runs the production container ([`Dockerfile.combined`](../Dockerfile.combined) — frontend built and
served as static files by FastAPI, one process on port 8000) on a single EC2 instance. Terraform
provisions the instance; the instance's boot script installs Docker and starts the container on
port 80.

```
deploy/
  bootstrap/          one-time: creates the S3 bucket that holds Terraform state
  terraform/          the deployment itself (state lives in that S3 bucket)
  packer/             OPTIONAL — bake a Docker-preinstalled AMI (not needed for the default path)
  iam-policy.json     least-privilege policy for the deploy IAM user
```

- **State is in S3** (`deploy/terraform/backend.tf`) so `terraform` can be run from any machine with
  AWS credentials — not just the one holding a local state file.
- **Shell access is via [SSM Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)**,
  not SSH. No key pair, no open port 22 — access is gated by IAM and logged in CloudTrail.

**Cost:** `t3.micro` is free-tier eligible (750 hrs/month for the first 12 months on a new
account). There is **no Elastic IP**, so a *stopped* instance costs only the 8 GB gp3 root volume
(~$0.65/month), plus a few cents for the state bucket. `scripts/deploy.sh destroy` takes it to ~$0.
The trade-off for skipping the EIP: the public IP changes every stop/start.

The devcontainer carries `terraform`, `aws`, `packer`, `tflint`, and `session-manager-plugin` (see
[`.devcontainer/`](../.devcontainer/)). If you just added them, rebuild the container ("Dev
Containers: Rebuild Container").

---

## 1. One-time prerequisites

### AWS credentials

Do **not** use your AWS root account. In the AWS console:

1. IAM → Policies → Create policy → JSON tab → paste [`iam-policy.json`](iam-policy.json) → name it
   `sudoku-deploy`.
2. IAM → Users → Create user (e.g. `sudoku-deploy`), attach `sudoku-deploy`, no console access.
3. Create an access key for that user (type: "Command Line Interface").

Then configure the CLI **yourself in a terminal** (so the secret never lands in a chat transcript
or a file under version control):

```bash
aws configure
# AWS Access Key ID:     <paste>
# AWS Secret Access Key: <paste>
# Default region name:   us-east-1
# Default output format:  json

aws sts get-caller-identity   # confirms it works
```

### Docker Hub

The instance pulls `jgaltidor/sudoku-solver-modern:latest`. To publish/refresh it you need
`docker login` as `jgaltidor` (push access to that repo).

### The state bucket (once per AWS account)

```bash
cd deploy/bootstrap
terraform init
terraform apply          # creates s3://sudoku-solver-modern-tfstate-<account-id>
```

The bucket name is hard-coded in [`deploy/terraform/backend.tf`](terraform/backend.tf) with this
account's ID. Deploying to a **different** account means changing the `bucket` / `region` there and
in `deploy/bootstrap`'s output, then re-running this step.

---

## 2. Publish the production image

The instance runs whatever is at `jgaltidor/sudoku-solver-modern:latest`. Build and push the
current tree so the deployment matches the code:

```bash
# from the repo root
docker login
docker buildx build --platform linux/amd64 -f Dockerfile.combined \
  -t jgaltidor/sudoku-solver-modern:latest --push .
```

`--platform linux/amd64` matches the default `t3.micro`. If you set `instance_type` to a `t4g.*`
(arm64), use `--platform linux/amd64,linux/arm64` instead.

`scripts/deploy.sh` (next step) does this build+push for you.

---

## 3. Deploy

```bash
scripts/deploy.sh                # build+push the image, then `terraform apply`
```

or by hand:

```bash
cd deploy/terraform
terraform init                   # first run: "yes" to the S3 backend
terraform apply
```

There is **no `terraform.tfvars` to fill in** — every variable has a working default. Copy
`terraform.tfvars.example` → `terraform.tfvars` only if you want to override the region, instance
type, or image.

`apply` prints the outputs (also `terraform output` any time):

```
app_url     = "http://<public-ip>"
ssm_command = "aws ssm start-session --target i-0abc..."
instance_id = "i-0abc..."
```

The container image pull happens on first boot — give it 1–2 minutes.

> **Where the live values live.** `terraform output` (from `deploy/terraform/`) is the source of
> truth for the current public IP, DNS name, and instance ID. Don't copy them into docs or scripts —
> the **public IP changes on every stop/start** and the **instance ID changes on replacement**.
> State is in S3 now, so it isn't tied to one machine and every write is versioned.

---

## 4. Verify

```bash
cd deploy/terraform
IP=$(terraform output -raw public_ip)
curl -s "http://$IP/health"          # {"status":"ok"}
open "http://$IP"                     # the Sudoku UI; solve a board end to end
```

If it doesn't respond, open a shell on the box and look:

```bash
aws ssm start-session --target "$(terraform output -raw instance_id)"
# then, on the instance (you land as ssm-user, with passwordless sudo):
sudo docker ps -a
sudo docker logs sudoku
sudo cat /var/log/cloud-init-output.log
```

(An instance takes ~2 min after boot to register with SSM. If `start-session` says the target is
not connected, wait and retry.)

---

## 5. Stop / start to save money

```bash
scripts/deploy.sh stop            # pause compute billing (EBS volume still ~$0.65/mo)
scripts/deploy.sh start           # boots it; prints the new public IP
```

The container has `--restart unless-stopped`, so it comes back automatically after a start.

---

## 6. Update the running app

After pushing a new `:latest` image, roll it out by replacing the instance (re-runs the boot
script, ~2 min, new IP):

```bash
cd deploy/terraform && terraform apply -replace=aws_instance.app
```

Or in place, without a new instance:

```bash
aws ssm start-session --target "$(terraform output -raw instance_id)"
# on the instance:
sudo docker pull docker.io/jgaltidor/sudoku-solver-modern:latest
sudo docker rm -f sudoku
sudo docker run -d --name sudoku --restart unless-stopped -p 80:8000 \
  docker.io/jgaltidor/sudoku-solver-modern:latest
```

---

## 7. Tear down

```bash
scripts/deploy.sh destroy         # removes the instance, security group, IAM role/profile
```

Back to ~$0. The **state bucket is left behind on purpose** (it must outlive the deployment, and
costs pennies). To remove it too, after `destroy`: `cd deploy/bootstrap && terraform destroy`.

---

## Deploying as a second developer

Everything is in shared state / public infrastructure now, so another person can deploy from their
own machine. They need:

1. **Docker Hub push access** to `jgaltidor/sudoku-solver-modern` (ask jgaltidor to add you as a
   collaborator), plus `docker login`. — *Only needed to publish a new image; not needed to
   `terraform apply` an existing one.*
2. **Their own AWS credentials** — an access key for the `sudoku-deploy` IAM user (or their own user
   with the same [`iam-policy.json`](iam-policy.json)), then `aws configure`.
3. **Nothing else** — the Terraform state is in S3, the state bucket already exists, there's no SSH
   key to copy, and the devcontainer brings the tooling. `terraform init` in `deploy/terraform/`
   picks up the shared state directly.

Shell access to the instance just needs the `ssm:StartSession` permission (it's in
`iam-policy.json`) — `aws ssm start-session --target <instance-id>`.

---

## Optional: Packer

[`packer/docker-ami.pkr.hcl`](packer/docker-ami.pkr.hcl) bakes an AMI with Docker pre-installed and
the image pre-pulled, so instances launched from it start faster. **The default deployment does not
need this** — it's here as a learning exercise. Packer needs a few more permissions than
[`iam-policy.json`](iam-policy.json) grants (image/snapshot creation); see HashiCorp's
[minimal Packer IAM policy](https://developer.hashicorp.com/packer/integrations/hashicorp/amazon#iam-task-or-instance-role).

```bash
cd deploy/packer
packer init .
packer build docker-ami.pkr.hcl
# note the "ami-..." it prints, then in deploy/terraform/terraform.tfvars:
#   ami_id = "ami-0123456789abcdef0"
```
