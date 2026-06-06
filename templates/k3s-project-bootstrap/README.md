## 1. Navigate to the template
```bash
cd templates/k3s-project-bootstrap
```

## 2. Initialize
```bash
export AWS_PROFILE="3-istor"

terraform init \
    -backend-config="bucket=3-istor-tf-infra-aws" \
    -backend-config="key=cnp/k3s-project-bootstrap/sandbox/project.tfstate" \
    -backend-config="region=eu-west-3" \
    -backend-config="encrypt=true"
```

## 3. Apply
You must provide your Cloudflare credentials (the CMP backend does this automatically).
```bash
export AWS_PROFILE="3-istor"

terraform apply \
    -var="project_name=sandbox" \
    -var="keycloak_url=https://admin-auth.3istor.com" \
    -var="keycloak_admin_username=admin"  \
    -var="keycloak_admin_password=fixme" \
    -var="vault_url=https://vault.3istor.com" \
    -var="vault_token=fixme"
```

## 4. Destroy
```bash
terraform destroy \
    -var="project_name=sandbox" \
    -var="keycloak_url=https://admin-auth.3istor.com" \
    -var="keycloak_admin_username=admin"  \
    -var="keycloak_admin_password=fixme" \
    -var="vault_url=https://vault.3istor.com" \
    -var="vault_token=fixme"
```
