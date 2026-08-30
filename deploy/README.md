# Deploying to AWS EC2

Runs the production container ([`Dockerfile.combined`](../Dockerfile.combined) — frontend built and
served as static files by FastAPI, one process on port 8000) on a single EC2 instance. Terraform
provisions the instance; the instance's boot script installs Docker and starts the container on
port 80.

```
deploy/
  terraform/          the deployment (run `terraform apply` here)
  packer/             OPTIONAL — bake a Docker-preinstalled AMI (not needed for the default path)
  iam-policy.json     least-privilege policy for the deploy IAM user
```

**Cost:** `t3.micro` is free-tier eligible (750 hrs/month for the first 12 months on a new
account). There is **no Elastic IP**, so a *stopped* instance costs only the 8 GB gp3 root volume
(~$0.65/month). `terraform destroy` takes it to ~$0. The trade-off: the public IP changes every
stop/start.

The devcontainer already has `terraform`, `aws`, `packer`, and `tflint` (see
[`.devcontainer/devcontainer.json`](../.devcontainer/devcontainer.json)). If you just added them,
rebuild the container ("Dev Containers: Rebuild Container").

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

Delete the access key (IAM → Users → Security credentials) when you're done deploying.

### SSH key

Terraform registers a public key on the instance for the `ec2-user` login. Default path is
`~/.ssh/id_ed25519.pub`. Create one if you don't have it:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
```

(Override with `ssh_public_key_path` in `terraform.tfvars` to use a different key.)

### Docker Hub

The instance pulls `jgaltidor/sudoku-solver-modern:latest`. To publish/refresh it (next step) you
need `docker login` as `jgaltidor`.

---

## 2. Publish the production image

The instance runs whatever is at `jgaltidor/sudoku-solver-modern:latest`. Build and push the
current `master` so the deployment matches the code:

```bash
# from the repo root
docker login
docker buildx build --platform linux/amd64 -f Dockerfile.combined \
  -t jgaltidor/sudoku-solver-modern:latest --push .
```

`--platform linux/amd64` matches the default `t3.micro`. If you set `instance_type` to a `t4g.*`
(arm64), use `--platform linux/amd64,linux/arm64` instead.

Sanity-check the image before deploying it:

```bash
docker run --rm -p 8000:8000 jgaltidor/sudoku-solver-modern:latest
curl -s localhost:8000/health
```

---

## 3. Deploy

```bash
cd deploy/terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set ssh_ingress_cidr to "$(curl -s https://checkip.amazonaws.com)/32"

terraform init
terraform apply
```

`apply` prints the outputs (also `terraform output` any time):

```
app_url     = "http://<public-ip>"
ssh_command = "ssh ec2-user@<public-ip>"
instance_id = "i-0abc..."
```

The container image pull happens on first boot — give it 1–2 minutes.

---

## 4. Verify

```bash
IP=$(terraform output -raw public_ip)
curl -s "http://$IP/health"          # {"status":"ok"} (or similar)
open "http://$IP"                     # the Sudoku UI; solve a board end to end
```

If it doesn't respond, SSH in and look:

```bash
ssh ec2-user@$IP
docker ps -a
docker logs sudoku
sudo cat /var/log/cloud-init-output.log
```

---

## 5. Stop / start to save money

```bash
cd deploy/terraform
aws ec2 stop-instances  --instance-ids "$(terraform output -raw instance_id)"
# ...later...
aws ec2 start-instances --instance-ids "$(terraform output -raw instance_id)"

# the public IP changed — refresh state and re-read it
terraform refresh
terraform output app_url
```

The container has `--restart unless-stopped`, so it comes back automatically after a start.

---

## 6. Update the running app

After pushing a new `:latest` image:

```bash
ssh ec2-user@$(terraform output -raw public_ip) \
  'docker pull docker.io/jgaltidor/sudoku-solver-modern:latest && \
   docker rm -f sudoku && \
   docker run -d --name sudoku --restart unless-stopped -p 80:8000 \
     docker.io/jgaltidor/sudoku-solver-modern:latest'
```

Or replace the whole instance (re-runs the boot script):

```bash
cd deploy/terraform && terraform apply -replace=aws_instance.app
```

---

## 7. Tear down

```bash
cd deploy/terraform
terraform destroy
```

Removes the instance, security group, and key pair. Back to ~$0.

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
