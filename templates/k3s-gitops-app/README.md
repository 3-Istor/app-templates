## 1. Navigate to the template
```bash
cd templates/k3s-gitops-app
```

## 2. Initialize
```bash
export AWS_PROFILE="3-istor"

terraform init \
    -backend-config="bucket=istor-cnp-tfstate-757826" \
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
# Import d’un repository existant

Le module accepte `repository_mode = "existing"` et
`existing_repository_url = "https://github.com/owner/repository"`.
Ce mode réutilise un projet déjà provisionné et un repo préparé par la CI centrale
CNP. CMP crée les `tfvars` dans une copie isolée du module, après validation des
permissions et des scans.

En mode import, les ressources GitHub qui créent le repo, ses fichiers, le workflow
et le secret Discord ont un `count` de zéro. Le provisioner de suppression des
packages GHCR a aussi un `count` de zéro. Le repo source et ses packages ne sont
donc pas gérés par le cycle Terraform de cette application.

Le mode par défaut reste `create` pour le catalogue. Les blocs `moved` conservent
les adresses des ressources déjà présentes dans les anciens states.

Tests sans cloud réel : `terraform init -backend=false`, `terraform validate`,
puis `terraform test`. Les quatre scénarios utilisent des fournisseurs simulés.

## 5. Staging environment (`staging/`)

A separate root module, applied by the CMP when an app opts into staging and
destroyed when it opts out. State key: `cnp/projects/<project>/<app>/staging`.

It creates what staging must not share with prod: the OIDC client
`cnp-<project>-<app>-stg`, the Vault secrets under `<app>/staging`, a Vault
policy and role that can read only that subtree, and the CNAME
`<app>-<project>-staging`. The namespace, tunnel route and Argo CD
Applications follow from the registry record, the `deploy/env/` files from the
CMP. It needs the same variables as the parent module, minus the GitHub ones.
