locals {
  app_type   = var.template_repo_name == "template-app-webapp-python-fastapi-react" ? "fullstack" : "static"
  components = local.app_type == "fullstack" ? ["frontend", "backend"] : ["app"]
}

# ==============================================================================
# 1. GITHUB PRIVATE REPOSITORY PROVISIONING
# ==============================================================================

# Create the private repository using the specified template
resource "github_repository" "app" {
  name        = var.app_name
  description = "Provisioned by CNP for Project ${var.project_name}"
  visibility  = "private"

  template {
    owner                = "3-Istor"
    repository           = var.template_repo_name
    include_all_branches = false
  }
}

# Dynamically inject the backend values file if the app is a full-stack type
resource "github_repository_file" "values_backend" {
  count      = local.app_type == "fullstack" ? 1 : 0
  repository = github_repository.app.name
  branch     = "main"
  file       = "deploy/values-backend.yaml"
  content = templatefile("${path.module}/templates/values-backend.yaml.tpl", {
    github_owner = lower(var.github_owner)
    app_name     = lower(var.app_name)
    project_name = var.project_name
  })
  commit_message      = "chore: bootstrap cnp backend variables [skip ci]"
  overwrite_on_create = true
}

# Dynamically inject the frontend/static values file
resource "github_repository_file" "values_frontend" {
  repository = github_repository.app.name
  branch     = "main"
  file       = local.app_type == "fullstack" ? "deploy/values-frontend.yaml" : "deploy/values.yaml"
  content = templatefile(
    local.app_type == "fullstack" ? "${path.module}/templates/values-frontend.yaml.tpl" : "${path.module}/templates/values-static.yaml.tpl",
    {
      github_owner = lower(var.github_owner)
      app_name     = lower(var.app_name)
      project_name = var.project_name
    }
  )
  commit_message      = "chore: bootstrap cnp application variables [skip ci]"
  overwrite_on_create = true
}

# ==============================================================================
# 2. KEYCLOAK OIDC SSO CLIENT (With Project-Level Authorization)
# ==============================================================================

# Create the dedicated OIDC Client for this project's application
resource "keycloak_openid_client" "app_client" {
  realm_id                     = var.project_name
  client_id                    = "cnp-${var.project_name}-${var.app_name}"
  name                         = "SSO Client for ${var.app_name}"
  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  direct_access_grants_enabled = false

  valid_redirect_uris = [
    "https://${var.app_name}-${var.project_name}.3istor.com/oauth2/callback"
  ]

  valid_post_logout_redirect_uris = [
    "https://${var.app_name}-${var.project_name}.3istor.com/"
  ]
}

# ==============================================================================
# 3. SECRETS & VAULT CONFIGURATION
# ==============================================================================

# Generate a secure random password for the application database
resource "random_password" "db_password" {
  length  = 24
  special = false
}

# Write application secrets AND the Keycloak Client Secret to Vault's subfolder!
# This allows Envoy Gateway (via VSO) to authenticate users for this app
resource "vault_kv_secret_v2" "app_secrets" {
  mount               = "project-${var.project_name}"
  name                = var.app_name
  delete_all_versions = true
  data_json = jsonencode({
    username      = "app" #pour cnpg
    password      = random_password.db_password.result
    client-secret = keycloak_openid_client.app_client.client_secret # Injected for Envoy Gateway OIDC
  })
}

# CREATE THE VAULT KUBERNETES ROLE (This resolves the VSO bug!)
# This binds strictly to the vault-secrets-operator ServiceAccount within the target namespace context
resource "vault_kubernetes_auth_backend_role" "vso_role" {
  backend                          = "kubernetes"
  role_name                        = "${var.project_name}-${var.app_name}-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400
  token_policies                   = ["project-${var.project_name}-dev-policy"] # Bound to the parent project policy
}

# ==============================================================================
# 4. KUBERNETES TARGET NAMESPACE & REGISTRY AUTHENTICATION (Day-0 Bootstrap)
# ==============================================================================

# Explicitly create the namespace to bootstrap secrets before pods are deployed
resource "kubernetes_namespace_v1" "app_ns" {
  metadata {
    name = "${var.project_name}-${var.app_name}"
    labels = {
      prod-gateway-access = "true"
    }
  }
}

# Generate the app-registry secret dynamically using the Classic packages pull PAT (K3s/Containerd compliant)
resource "kubernetes_secret_v1" "app_registry" {
  metadata {
    name      = "app-registry"
    namespace = kubernetes_namespace_v1.app_ns.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    # Let the provider handle the outer Base64 encoding automatically
    ".dockerconfigjson" = jsonencode({
      auths = {
        # 1. Standard key
        "ghcr.io" = {
          username = var.github_registry_username
          password = var.github_registry_token
          auth     = base64encode("${var.github_registry_username}:${var.github_registry_token}")
        },
        # 2. Full URL key (often required by containerd/K3s)
        "https://ghcr.io" = {
          username = var.github_registry_username
          password = var.github_registry_token
          auth     = base64encode("${var.github_registry_username}:${var.github_registry_token}")
        }
      }
    })
  }
}

# ==============================================================================
# 5. DEDICATED CLOUDFLARE MICRO-TUNNEL (Fully Automated Day-0)
# ==============================================================================

# Generate a random password for the dedicated tunnel secret
resource "random_password" "tunnel_secret" {
  length  = 64
  special = false
}

# Create a dedicated Cloudflare Tunnel for this specific application
resource "cloudflare_zero_trust_tunnel_cloudflared" "app_tunnel" {
  account_id    = var.cloudflare_account_id
  name          = "cnp-${var.project_name}-${var.app_name}-tunnel"
  config_src    = "cloudflare"
  tunnel_secret = base64encode(random_password.tunnel_secret.result)
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "app_tunnel_config" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.app_tunnel.id

  config = {
    ingress = [
      {
        hostname = "${var.app_name}-${var.project_name}.3istor.com"
        service  = "http://envoy-gateway-infra-shared-gateway-ac1e5388.envoy-gateway-system.svc.cluster.local:80"
      },
      {
        service = "http_status:404"
      }
    ]
  }
}

# Create the explicit, secure DNS CNAME record pointing to the dedicated tunnel
resource "cloudflare_dns_record" "app_cname" {
  zone_id = var.cloudflare_zone_id
  name    = "${var.app_name}-${var.project_name}"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.app_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  ttl     = 1
}

# Write the Tunnel Token into a Kubernetes Secret inside the application namespace
resource "kubernetes_secret_v1" "tunnel_token" {
  metadata {
    name      = "cloudflare-tunnel-token"
    namespace = kubernetes_namespace_v1.app_ns.metadata[0].name
  }

  type = "Opaque"

  data = {
    token = base64encode(jsonencode({
      a = var.cloudflare_account_id
      t = cloudflare_zero_trust_tunnel_cloudflared.app_tunnel.id
      s = base64encode(random_password.tunnel_secret.result)
    }))
  }
}

resource "time_sleep" "wait_for_tunnel_disconnect" {
  depends_on = [
    cloudflare_zero_trust_tunnel_cloudflared.app_tunnel,
    cloudflare_zero_trust_tunnel_cloudflared_config.app_tunnel_config
  ]

  create_duration  = "0s"
  destroy_duration = "45s"
}

# ==============================================================================
# 6. ARGOCD DELIVERY (GITOPS APPLICATIONS)
# ==============================================================================


resource "kubernetes_manifest" "argocd_application" {
  for_each   = toset(local.components)
  depends_on = [time_sleep.wait_for_tunnel_disconnect]

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "${var.project_name}-${var.app_name}-${each.value}"
      namespace = "argocd"
      annotations = {
        # Required for Kyverno compliance and to prevent sync-loops with mutating webhooks
        "argocd.argoproj.io/compare-options" = "ServerSideDiff=true,IncludeMutationWebhook=true"
      }
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }
    spec = {
      project = var.project_name

      # Combined Sources: Central Helm Chart + Developer's custom values.yaml
      sources = [
        {
          # Source 1: The shared, generic Helm Chart
          repoURL        = "https://github.com/3-Istor/infra-templates.git"
          targetRevision = "HEAD"
          path           = "." # Root of infra-templates containing Chart.yaml
          ref            = ""
          helm = {
            valueFiles = [
              local.app_type == "fullstack" ? "$values/deploy/values-${each.value}.yaml" : "$values/deploy/values.yaml"
            ]
          }
        },
        {
          # Source 2: The developer's repository (private code + deploy/values.yaml)
          repoURL        = github_repository.app.html_url
          targetRevision = "HEAD"
          path           = ""
          ref            = "values"
          helm = {
            valueFiles = []
          }
        }
      ]

      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace_v1.app_ns.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "ServerSideApply=true",
          "RespectIgnoreDifferences=true"
        ]
      }
      ignoreDifferences = [
        {
          group = "apps"
          kind  = "Deployment"
          jsonPointers = [
            "/spec/replicas"
          ]
        }
      ]
    }
  }

  field_manager {
    force_conflicts = true
  }
}

# ==============================================================================
# 7. ARGOCD IMAGE UPDATER CONFIGURATION
# ==============================================================================

resource "kubernetes_manifest" "argocd_image_updater" {
  for_each   = toset(local.components)
  depends_on = [time_sleep.wait_for_tunnel_disconnect]

  manifest = {
    apiVersion = "argocd-image-updater.argoproj.io/v1alpha1"
    kind       = "ImageUpdater"
    metadata = {
      name      = "${var.project_name}-${var.app_name}-${each.value}-updater"
      namespace = "argocd"
    }
    spec = {
      applicationRefs = [
        {
          namePattern = "${var.project_name}-${var.app_name}-${each.value}"

          images = [
            {
              alias     = "app-image"
              imageName = each.value == "app" ? lower("ghcr.io/${var.github_owner}/${var.app_name}") : lower("ghcr.io/${var.github_owner}/${var.app_name}/${each.value}")

              pullSecret = "secret:${var.project_name}-${var.app_name}/app-registry"

              manifestTargets = {
                helm = {
                  name = "image.repository"
                  tag  = "image.tag"
                }
              }

              commonUpdateSettings = {
                updateStrategy = "newest-build"
                allowTags      = "regexp:^sha-[a-f0-9]+$"
              }
            }
          ]

          writeBackConfig = {
            method = "git:secret:argocd/private-repo-creds"
            gitConfig = {
              branch          = "main"
              writeBackTarget = local.app_type == "fullstack" ? "helmvalues:/deploy/values-${each.value}.yaml" : "helmvalues:/deploy/values.yaml"
              pullRequest = {
                github = {}
              }
            }
          }
        }
      ]
    }
  }
}

# ==============================================================================
# 8. CLEANUP: GHCR PACKAGES DELETION (On Destroy)
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

      TOKEN="${self.triggers.github_token}"

      if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
        echo "⚠️ GitHub Classic PAT token is missing from state. Cannot delete GHCR packages."
        exit 0
      fi

      # Preserve exact case for the organization owner, force lowercase for the package name
      OWNER="${self.triggers.github_owner}"
      APP_NAME=$(echo "${self.triggers.app_name}" | tr '[:upper:]' '[:lower:]')

      delete_package() {
        local pkg_name=$1
        local encoded_pkg=$(echo "$pkg_name" | sed 's/\//%2F/g')

        RESPONSE=$(curl -s -w "\nHTTP_STATUS:%%{http_code}" -X DELETE \
          -H "Accept: application/vnd.github.v3+json" \
          -H "Authorization: Bearer $TOKEN" \
          "https://api.github.com/orgs/$OWNER/packages/container/$encoded_pkg")
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
