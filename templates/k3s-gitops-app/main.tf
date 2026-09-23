locals {
  app_type   = var.template_repo_name == "template-app-webapp-python-fastapi-react" ? "fullstack" : "static"
  components = local.app_type == "fullstack" ? ["frontend", "backend"] : ["app"]

  hostname = "${var.app_name}-${var.project_name}.${var.domain}"

  # Everything that genuinely differs per provider on this path. It is a short
  # list because the module no longer creates cloud resources — the per-capability
  # split (network, compute, database, storage, exposure) lives in
  # project-bootstrap, which is where cloud resources are actually created.
  cloud_profile = {
    onprem = { storage_class = "local-path" }
    aws    = { storage_class = "gp3" }
    gcp    = { storage_class = "standard-rwo" }
  }
  storage_class = local.cloud_profile[var.target_cloud].storage_class

  # Uniform markers, per D-13. "Find everything belonging to project X on cloud
  # Y" has to be a query rather than guesswork.
  marker = "cnp.project=${var.project_name} cnp.cloud=${var.target_cloud} cnp.env=${var.environment}"
}

# ==============================================================================
# 1. GITHUB PRIVATE REPOSITORY PROVISIONING
# ==============================================================================

resource "github_repository" "app" {
  name        = var.app_name
  description = "Provisioned by CNP for Project ${var.project_name}"
  visibility  = "private"

  template {
    owner                = var.github_owner
    repository           = var.template_repo_name
    include_all_branches = false
  }
}

resource "github_repository_file" "values_backend" {
  count      = local.app_type == "fullstack" ? 1 : 0
  repository = github_repository.app.name
  branch     = "main"
  file       = "deploy/values-backend.yaml"
  content = templatefile("${path.module}/templates/values-backend.yaml.tpl", {
    github_owner  = lower(var.github_owner)
    app_name      = lower(var.app_name)
    project_name  = var.project_name
    storage_class = local.storage_class
  })
  commit_message      = "chore: bootstrap cnp backend variables [skip ci]"
  overwrite_on_create = true
}

resource "github_repository_file" "values_frontend" {
  repository = github_repository.app.name
  branch     = "main"
  file       = local.app_type == "fullstack" ? "deploy/values-frontend.yaml" : "deploy/values.yaml"
  content = templatefile(
    local.app_type == "fullstack" ? "${path.module}/templates/values-frontend.yaml.tpl" : "${path.module}/templates/values-static.yaml.tpl",
    {
      github_owner  = lower(var.github_owner)
      app_name      = lower(var.app_name)
      project_name  = var.project_name
      hostname      = local.hostname
      storage_class = local.storage_class
    }
  )
  commit_message      = "chore: bootstrap cnp application variables [skip ci]"
  overwrite_on_create = true
}

# ==============================================================================
# 2. KEYCLOAK OIDC SSO CLIENT
# ==============================================================================

resource "keycloak_openid_client" "app_client" {
  realm_id                     = var.keycloak_realm_id != "" ? var.keycloak_realm_id : var.project_name
  client_id                    = "cnp-${var.project_name}-${var.app_name}"
  name                         = "SSO Client for ${var.app_name}"
  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  direct_access_grants_enabled = false

  valid_redirect_uris = [
    "https://${local.hostname}/oauth2/callback"
  ]

  valid_post_logout_redirect_uris = [
    "https://${local.hostname}/"
  ]
}

# ==============================================================================
# 3. SECRETS — everything Kubernetes needs, delivered through Vault
# ==============================================================================

resource "random_password" "db_password" {
  length  = 24
  special = false
}

# Application secrets and the Keycloak client secret. One value, one writer: the
# secrets operator syncs it into the namespace, keycloak-config-cli creates the
# client with that exact secret, and Envoy's SecurityPolicy reads the same
# Kubernetes Secret.
resource "vault_kv_secret_v2" "app_secrets" {
  mount               = "project-${var.project_name}"
  name                = var.app_name
  delete_all_versions = true

  custom_metadata {
    data = {
      "cnp.project" = var.project_name
      "cnp.cloud"   = var.target_cloud
      "cnp.env"     = var.environment
    }
  }

  data_json = jsonencode({
    username      = "app"
    password      = random_password.db_password.result
    client-secret = keycloak_openid_client.app_client.client_secret
  })
}

# The GHCR pull secret. Used to be written straight into the app namespace's
# etcd as a dockerconfigjson Secret; it now goes to Vault and the secrets
# operator materialises it on whichever cluster the app lands on.
resource "vault_kv_secret_v2" "app_registry" {
  mount               = "project-${var.project_name}"
  name                = "${var.app_name}/registry"
  delete_all_versions = true

  data_json = jsonencode({
    ".dockerconfigjson" = jsonencode({
      auths = {
        # containerd on K3s wants the full-URL key as well as the bare host.
        for host in ["ghcr.io", "https://ghcr.io"] : host => {
          username = var.github_registry_username
          password = var.github_registry_token
          auth     = base64encode("${var.github_registry_username}:${var.github_registry_token}")
        }
      }
    })
  })
}

# Vault auth role for this app's secrets.
#
# One Kubernetes auth mount per cluster (D-07): a single mount is configured for
# the on-prem API server's token issuer and CA, and a second cluster's service
# account tokens will not validate against it.
resource "vault_kubernetes_auth_backend_role" "app_role" {
  # D-07 is about the mount, not the name: one mount per cluster, because a
  # mount is tied to one API server's token issuer/CA. Today there is one
  # cluster (on-prem), so its vault-secrets-operator has one fixed
  # VAULT_KUBERNETES_PATH (auth/kubernetes) — the role has to live there, not
  # under a cloud-suffixed mount nothing authenticates against. Naming the
  # mount per-cloud only becomes correct once a second cluster (and its own
  # operator instance) actually exists.
  backend                          = "kubernetes"
  role_name                        = "${var.project_name}-${var.app_name}-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400
  token_policies                   = ["project-${var.project_name}-dev-policy"]
}

# ==============================================================================
# 4. PUBLIC HOSTNAME
# ==============================================================================

# The project owns one tunnel and one connector (D-06); an application adds a
# hostname to it rather than standing up a tunnel of its own. A project with two
# apps used to run at least two connectors and rely on a third, shared one.
#
# The connector's routing table is Git state, rendered by cnp-project-base from
# the project's registry record — which is why nothing here writes an ingress
# rule to the Cloudflare API.
data "cloudflare_zero_trust_tunnel_cloudflared" "project_tunnel" {
  account_id = var.cloudflare_account_id

  filter = {
    name = "cnp-${var.project_name}-tunnel"
  }
}

resource "cloudflare_dns_record" "app_cname" {
  zone_id = var.cloudflare_zone_id
  name    = "${var.app_name}-${var.project_name}"
  content = "${data.cloudflare_zero_trust_tunnel_cloudflared.project_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  ttl     = 1
  comment = local.marker
}

# ==============================================================================
# 5. CLEANUP: GHCR PACKAGES DELETION (On Destroy)
# ==============================================================================

resource "null_resource" "delete_ghcr_packages" {
  triggers = {
    app_name     = var.app_name
    github_owner = var.github_owner
    app_type     = local.app_type
    github_token = var.github_registry_token
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      #!/bin/bash
      set -uo pipefail

      TOKEN="${self.triggers.github_token}"

      if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
        echo "GitHub Classic PAT token is missing from state. Cannot delete GHCR packages."
        exit 0
      fi

      OWNER="${self.triggers.github_owner}"
      APP_NAME=$(echo "${self.triggers.app_name}" | tr '[:upper:]' '[:lower:]')

      delete_package() {
        local encoded_pkg
        encoded_pkg=$(echo "$1" | sed 's/\//%2F/g')

        curl -s -o /dev/null -w "%%{http_code} $1\n" -X DELETE \
          -H "Accept: application/vnd.github.v3+json" \
          -H "Authorization: Bearer $TOKEN" \
          "https://api.github.com/orgs/$OWNER/packages/container/$encoded_pkg"
      }

      if [ "${self.triggers.app_type}" = "fullstack" ]; then
        delete_package "$APP_NAME/frontend"
        delete_package "$APP_NAME/backend"
      else
        delete_package "$APP_NAME"
      fi
    EOT
  }
}
