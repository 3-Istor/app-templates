# Full Stack App (Web + HA DB) Template

Deploy a resilient Python Web App automatically connected to a Patroni HA PostgreSQL cluster on OpenStack.
The web application nodes and the database nodes (including the Load Balancer IP) are provisioned in parallel to speed up the deployment time. The Python service is configured to wait and reconnect automatically until the database cluster leader is elected.

## 0. Navigate to the template
```bash
cd templates/openstack-global-app
```

## 1. Initialize
Ensure you have sourced your `admin-openrc.sh` before running these commands.

```bash
terraform init \
    -backend-config="bucket=3-istor-tf-infra-aws" \
    -backend-config="key=apps/global-test-01/terraform.tfstate" \
    -backend-config="region=eu-west-3" \
    -backend-config="encrypt=true"
```

## 2. Plan
Generate and save the execution plan to a file named `tfplan`. You can override default variables here if needed.

```bash
terraform plan \
    -var="app_name=my-global-app" \
    -var="project_name=3-istor-cloud" \
    -var="app_instance_count=2" \
    -var="db_instance_count=2" \
    -out=tfplan
```

## 3. Apply
Execute the previously generated plan. Since the plan is already saved, Terraform will not ask for confirmation.

```bash
terraform apply tfplan
```

*Once the apply is complete, Terraform will output the `app_public_url`. You can open this URL in your browser to see the resilience demo app.*

## 4. Destroy
Tear down the entire infrastructure. Make sure to pass the exact same variables used during the plan phase.

```bash
terraform destroy \
    -var="app_name=my-global-app" \
    -var="project_name=3-istor-cloud" \
    -var="app_instance_count=2" \
    -var="db_instance_count=2"
```
