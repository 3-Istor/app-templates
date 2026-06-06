## 1. Navigate to the template
```bash
cd templates/k3s-gitops-app
```

## 2. Initialize
```bash
export AWS_PROFILE="3-istor"

terraform init \
    -backend-config="bucket=3-istor-tf-infra-aws" \
    -backend-config="key=cnp/k3s-gitops-app/sandbox/my-app-v1.tfstate" \
    -backend-config="region=eu-west-3" \
    -backend-config="encrypt=true"
```

## 3. Apply
You must provide your Cloudflare credentials (the CMP backend does this automatically).
```bash
export AWS_PROFILE="3-istor"

terraform apply \
    -var="github_token=" \
    -var="github_owner=3-Istor" \
    -var="template_repo_name=template-html-css" \
    -var="app_name=my-app-v1" \
    -var="project_name=sandbox" \
    -var="vault_token=fixme" \
    -var="github_registry_token=fixme" \
    -var="github_registry_username=3-Istor" \
    -var="app_type=static" \
    -var="keycloak_admin_password=fixme" \
    -var="keycloak_admin_username=admin" \
    -var="keycloak_url=https://auth.3istor.com/" \
    -var="vault_url=https://vault.3istor.com" \
    -var="cloudflare_api_token=fixme" \
    -var="cloudflare_account_id=fixme" \
    -var="cloudflare_zone_id=fixme"
```

## 4. Destroy
```bash
terraform destroy \
    -var="github_token=" \
    -var="github_owner=3-Istor" \
    -var="template_repo_name=template-html-css" \
    -var="app_name=my-app-v1" \
    -var="project_name=sandbox" \
    -var="vault_token=fixme" \
    -var="github_registry_token=fixme" \
    -var="github_registry_username=3-Istor" \
    -var="app_type=static" \
    -var="keycloak_admin_password=fixme" \
    -var="keycloak_admin_username=admin" \
    -var="keycloak_url=https://auth.3istor.com/" \
    -var="vault_url=https://vault.3istor.com" \
    -var="cloudflare_api_token=fixme" \
    -var="cloudflare_account_id=fixme" \
    -var="cloudflare_zone_id=fixme"
```
