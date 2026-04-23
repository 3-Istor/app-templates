# Hybrid Full Stack App (AWS FastAPI + OpenStack PostgreSQL HA)

This template demonstrates a true Multi-Cloud architecture.
It deploys a highly available FastAPI application on AWS (using an Auto Scaling Group) connected to a resilient Patroni PostgreSQL cluster on OpenStack. Communication between the two clouds relies on a pre-existing WireGuard VPN tunnel.

## 0. Prerequisites
- The **OpenStack & AWS Base Infrastructures** must be already deployed (including the WireGuard VPN).
- Your terminal must have OpenStack credentials loaded (`source admin-openrc.sh`).
- Your terminal must have AWS credentials configured (`aws configure`).
- You must have your Cloudflare API Token and Zone ID ready.
- You must have a Git repository containing the FastAPI code.

## 1. Navigate to the template
```bash
cd templates/aws-global-hybrid
```

## 2. Initialize
We use the AWS S3 bucket to store the state, ensuring consistency across environments.

```bash
terraform init \
    -backend-config="bucket=3-istor-tf-infra-aws" \
    -backend-config="key=apps/hybrid-test-01/terraform.tfstate" \
    -backend-config="region=eu-west-3" \
    -backend-config="encrypt=true"
```

## 3. Plan
Generate an execution plan. Replace the placeholder values with your actual data.

```bash
terraform plan \
    -var="app_name=hybrid-demo" \
    -var="project_name=3-istor-cloud" \
    -var="app_instance_count=2" \
    -var="db_instance_count=2" \
    -var="git_repo_url=https://github.com/3-Istor/demo-app.git" \
    -var="git_branch=main" \
    -var="aws_key_name=arcl" \
    -var="cloudflare_api_token=YOUR_CF_TOKEN" \
    -var="cloudflare_zone_id=YOUR_CF_ZONE_ID" \
    -out=tfplan
```

## 4. Apply
Deploy the hybrid infrastructure. Thanks to explicit port creation, the AWS Web Nodes and the OpenStack Database cluster are provisioned in parallel.

```bash
terraform apply tfplan
```

*Wait for completion (approx. 3-4 minutes). Open the outputted `app_url` (e.g., `https://hybrid-demo.3istor.com`) in your browser to see the live Multi-Cloud application.*

## 5. Destroy
Clean up all resources across both AWS and OpenStack.

```bash
terraform destroy \
    -var="app_name=hybrid-demo" \
    -var="project_name=3-istor-cloud" \
    -var="app_instance_count=2" \
    -var="db_instance_count=2" \
    -var="git_repo_url=https://github.com/YOUR_USER/fastapi-resilience-demo.git" \
    -var="git_branch=main" \
    -var="aws_key_name=arcl" \
    -var="cloudflare_api_token=YOUR_CF_TOKEN" \
    -var="cloudflare_zone_id=YOUR_CF_ZONE_ID"
```
