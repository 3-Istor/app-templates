# 0. Navigate to the desired template
```bash
cd templates/openstack-web-git
```

# 1. Initialize
```sh
terraform init \
    -backend-config="bucket=3-istor-tf-infra-aws" \
    -backend-config="key=apps/git-test-01/terraform.tfstate" \
    -backend-config="region=eu-west-3" \
    -backend-config="encrypt=true"
```

# 2. Apply with your Git Repository URL
```sh
terraform apply \
    -var="app_name=my-git-website" \
    -var="git_repo_url=https://github.com/TheGostsniperfr/portfolio.git" \
    -var="git_branch=website" \
    -var="instance_count=2" \
    -var="project_name=3-istor-cloud"
```
# 3. Destroy the app
```bash
    terraform destroy \
    -var="app_name=my-git-website" \
    -var="instance_count=2" \
    -var="project_name=3-istor-cloud"
```
