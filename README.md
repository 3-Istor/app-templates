# app-templates

## Rôle

Catalogue des plans de provisioning exécutés par CMP. Les templates assemblent les modules d’infrastructure et de configuration ; `project-bootstrap` prépare un projet et `k3s-gitops-app` initialise une application GitOps.

## Technologies

Terraform/HCL, manifests JSON, templates cloud-init et YAML, scripts Shell ; providers OpenStack, AWS, GitHub, Keycloak, Vault et Cloudflare selon le template.

## Entrées

| Origine / destinataire | Contenu et transmission |
| --- | --- |
| CMP | Variables du projet et de l’application, cloud cible, paramètres et accès nécessaires à l’exécution Terraform. |
| template-html-css / template-app-webapp-python-fastapi-react | Dépôt source choisi via `template_repo_name` ; copie par le mécanisme GitHub repository template. |
| Cloud / services externes | Infrastructure cloud et API accessibles, identité, secrets et DNS nécessaires aux providers. |

## Sorties et consommateurs

| Origine / destinataire | Contenu et transmission |
| --- | --- |
| CMP | Catalogue `manifest.json` et plans Terraform récupérés par clone Git ; outputs de l’exécution. |
| Dépôts applicatifs | Dépôts privés initialisés à partir du template choisi et fichiers `deploy/*.yaml` configurés. |
| Services cloud / identité / secrets | Ressources provisionnées par le template sélectionné. Sur le chemin `k3s-gitops-app`, GitHub, Keycloak, Vault et DNS sont configurés ; les objets applicatifs Kubernetes sont générés par Argo CD depuis le registre. |

## Documentation CNP

[Fiche `app-templates` et workflows inter-repo](https://github.com/3-Istor/cnp-docs/blob/main/docs/04-templates/00-github-repositories-landscape.md#app-templates).

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
Configurer les accès OpenStack/AWS avant de démarrer. Le socle et les procédures OpenStack sont documentés dans [Cloud](https://github.com/3-Istor/Cloud).

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
Les templates déclarent un backend S3 ; CMP fournit la configuration de state lors de l’exécution. Les chemins de compensation et de destruction sont implémentés côté CMP. Vérifier les journaux et le state après un échec : leur présence ne garantit pas à elle seule l’absence de ressources orphelines.
