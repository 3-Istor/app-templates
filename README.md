# Application as a Service (AaaS) Templates

This repository lists all the Terraform templates used by the ARCL CMP to deploy applications on OpenStack and AWS.
It is designed to be modular, reusable, and easily testable both manually and through the CMP.

## 🏗️ Architecture Overview

The repository is highly modular and follows a strict separation of concerns, divided into two main categories: **Modules** and **Templates**.

### 1. Modules (`/modules`)
Modules are isolated, reusable building blocks. They do not know about the final project context.
*   **`/infra`**: Contains pure infrastructure definitions (VMs, Load Balancers, Auto Scaling Groups, Security Groups). **No software configuration here.**
*   **`/software`**: Contains only `cloud-init` configurations to install and configure software (Nginx, WordPress, DBs). **No cloud resources are created here.**

### 2. Templates (`/templates`)
Templates are the entry points. They act as "Glue", combining a specific software configuration with a specific cloud infrastructure.
*The ARCL CMP uses these templates as the root execution path.*

## 🚀 Manual Deployment & Testing

You can use these templates manually (simulating the CMP behavior).
Ensure you have sourced your `admin-openrc.sh` from Cloud Git repo before starting.

1.  **Navigate to the desired template:**
    ```bash
    cd templates/openstack-nginx
    ```

2.  **Initialize the backend dynamically (S3 State Lock):**
    ```bash
    terraform init \
      -backend-config="bucket=3-istor-tf-infra-aws" \
      -backend-config="key=apps/test-manuelle-01/terraform.tfstate" \
      -backend-config="region=eu-west-3" \
      -backend-config="encrypt=true"
    ```

3.  **Deploy with custom variables:**
    ```bash
    terraform apply \
      -var="app_name=my-test-app" \
      -var="instance_count=2" \
      -var="project_name=3-istor-cloud"
    ```

4.  **Destroy the app:**
    ```bash
    terraform destroy \
      -var="app_name=my-test-app" \
      -var="instance_count=2" \
      -var="project_name=3-istor-cloud"
    ```

## 🧠 Design for Failure (Saga Pattern)
When used by the CMP, dynamic backend states are stored securely in S3. If a hybrid deployment fails (e.g., OpenStack succeeds but AWS fails), the CMP will trigger a rollback `terraform destroy` on the specific template to maintain a perfectly clean state, ensuring zero orphaned resources.
