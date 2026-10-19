# The staging environment of an app that already exists (k3s-gitops-app).
#
# Applied by the CMP when an app opts into staging, with its own state key
# (cnp/projects/<project>/<app>/staging), and destroyed when it opts out. It
# creates only what must not be shared with prod: an OIDC client, the app's
# secrets and a Vault role that can read nothing else, and a hostname. The
# namespace, tunnel route and Argo CD Applications come from the registry
# record, the deploy/env/staging files from the CMP.

locals {
  hostname = "${var.app_name}-${var.project_name}-staging.${var.domain}"
  mount    = "project-${var.project_name}"
  path     = "${var.app_name}/staging"
  marker   = "cnp.project=${var.project_name} cnp.cloud=${var.target_cloud} cnp.env=staging"
}

resource "keycloak_openid_client" "staging_client" {
  realm_id                     = var.keycloak_realm_id != "" ? var.keycloak_realm_id : var.project_name
  client_id                    = "cnp-${var.project_name}-${var.app_name}-stg"
  name                         = "SSO Client for ${var.app_name} (staging)"
  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  direct_access_grants_enabled = false

  valid_redirect_uris             = ["https://${local.hostname}/oauth2/callback"]
  valid_post_logout_redirect_uris = ["https://${local.hostname}/"]
}

resource "keycloak_openid_client_default_scopes" "staging_client_scopes" {
  realm_id  = keycloak_openid_client.staging_client.realm_id
  client_id = keycloak_openid_client.staging_client.id
  default_scopes = [
    "acr",
    "basic",
    "email",
    "groups",
    "profile",
    "roles",
    "web-origins",
  ]
}

resource "random_password" "db_password" {
  length  = 24
  special = false
}

resource "vault_kv_secret_v2" "staging_secrets" {
  mount               = local.mount
  name                = local.path
  delete_all_versions = true

  custom_metadata {
    data = {
      "cnp.project" = var.project_name
      "cnp.cloud"   = var.target_cloud
      "cnp.env"     = "staging"
    }
  }

  data_json = jsonencode({
    username      = "app"
    password      = random_password.db_password.result
    client-secret = keycloak_openid_client.staging_client.client_secret
  })
}

resource "vault_kv_secret_v2" "staging_registry" {
  mount               = local.mount
  name                = "${local.path}/registry"
  delete_all_versions = true

  data_json = jsonencode({
    ".dockerconfigjson" = jsonencode({
      auths = {
        for host in ["ghcr.io", "https://ghcr.io"] : host => {
          username = var.github_registry_username
          password = var.github_registry_token
          auth     = base64encode("${var.github_registry_username}:${var.github_registry_token}")
        }
      }
    })
  })
}

# The prod role gets the project developers' policy, which covers every path
# of the project. Staging gets its own subtree only, so a staging pod can never
# read a prod secret.
resource "vault_policy" "staging" {
  name   = "project-${var.project_name}-${var.app_name}-staging-policy"
  policy = <<EOT
path "${local.mount}/data/${local.path}" {
  capabilities = ["read"]
}
path "${local.mount}/data/${local.path}/*" {
  capabilities = ["read"]
}
path "${local.mount}/metadata/${local.path}" {
  capabilities = ["read", "list"]
}
path "${local.mount}/metadata/${local.path}/*" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "staging_role" {
  backend                          = var.target_cloud == "onprem" ? "kubernetes" : "kubernetes-${var.target_cloud}"
  role_name                        = "${var.project_name}-${var.app_name}-staging-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400
  token_policies                   = [vault_policy.staging.name]
}

data "cloudflare_zero_trust_tunnel_cloudflared" "project_tunnel" {
  account_id = var.cloudflare_account_id

  filter = {
    name = "cnp-${var.project_name}-tunnel"
  }
}

resource "cloudflare_dns_record" "staging_cname" {
  zone_id = var.cloudflare_zone_id
  name    = "${var.app_name}-${var.project_name}-staging"
  content = "${data.cloudflare_zero_trust_tunnel_cloudflared.project_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  ttl     = 1
  comment = local.marker
}
