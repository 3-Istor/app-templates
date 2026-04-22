# AWS Nginx (Auto Scaling & Self-Healing) Template

Deploy a highly available, self-healing Nginx application on AWS.
This template uses an Auto Scaling Group and registers automatically to the shared ARCL Application Load Balancer. It also creates a Cloudflare DNS record dynamically.

## 0. Prerequisites
Ensure the ARCL Base Infrastructure is already deployed and its state is available in the S3 bucket.

## 1. Navigate to the template
```bash
cd templates/aws-nginx
```

## 2. Initialize
```bash
terraform init \
    -backend-config="bucket=3-istor-tf-infra-aws" \
    -backend-config="key=apps/nginx-test-01/terraform.tfstate" \
    -backend-config="region=eu-west-3" \
    -backend-config="encrypt=true"
```

## 3. Apply
You must provide your Cloudflare credentials (the CMP backend does this automatically).
```bash
terraform apply \
    -var="app_name=mon-app" \
    -var="instance_count=2" \
    -var="key_name=arcl" \
    -var="cloudflare_api_token=YOUR_TOKEN" \
    -var="cloudflare_zone_id=YOUR_ZONE_ID"
```

## 4. Destroy
```bash
terraform destroy \
    -var="app_name=mon-app" \
    -var="instance_count=2" \
    -var="key_name=arcl" \
    -var="cloudflare_api_token=YOUR_TOKEN" \
    -var="cloudflare_zone_id=YOUR_ZONE_ID"
```
