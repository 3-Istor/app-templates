# K3s Kubernetes Cluster Template

Deploy a lightweight, production-ready Kubernetes (K3s) cluster on OpenStack.
This template is optimized for use with ArgoCD.

## 0. Navigate to the template
```bash
cd templates/openstack-k3s
```

## 1. Initialize
```sh
terraform init \
    -backend-config="bucket=3-istor-tf-infra" \
    -backend-config="key=apps/k3s-test-01/terraform.tfstate" \
    -backend-config="region=eu-west-3" \
    -backend-config="encrypt=true"
```

## 2. Apply
```sh
terraform apply \
    -var="app_name=my-k3s-cluster" \
    -var="project_name=3-istor-cloud"
```

## 3. Retrieve the Kubeconfig
Once the deployment is complete, Terraform will output a specific command to fetch the `kubeconfig.yaml` file from the VM and replace the local IP with the Floating IP automatically.

Copy and paste the output of `kubeconfig_fetch_command` in your terminal. It will look like this:
```bash
ssh ubuntu@<FLOATING_IP> 'cat /etc/rancher/k3s/k3s.yaml' > kubeconfig.yaml && sed -i 's/127.0.0.1/<FLOATING_IP>/g' kubeconfig.yaml
```

You can now use `kubectl` locally:
```bash
export KUBECONFIG=$(pwd)/kubeconfig.yaml
kubectl get nodes
kubectl get pods -A
```

NB: Don't forget to update your `~/.ssh/config` file with the appropriate SSH configuration for the VM, including the necessary port forwarding for Kubernetes API access.
```
LocalForward 6443 <FLOATING_IP>:6443
```


## 4. Destroy the cluster
```bash
terraform destroy \
    -var="app_name=my-k3s-cluster" \
    -var="project_name=3-istor-cloud"
```
