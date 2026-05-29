# ==============================================================================
# 1. KEYCLOAK IDENTITY GROUPS
# ==============================================================================

# Create Project Members Group
resource "keycloak_group" "project_members" {
  realm_id = var.keycloak_realm
  name     = "project-${var.project_name}-members"
}

# Create Project Admins Group
resource "keycloak_group" "project_admins" {
  realm_id = var.keycloak_realm
  name     = "project-${var.project_name}-admins"
}

# ==============================================================================
# 2. VAULT SECRETS ISOLATION
# ==============================================================================

# Create a Vault Policy for Human Developers (UI Access to their folder)
resource "vault_policy" "project_developers" {
  name   = "project-${var.project_name}-dev-policy"
  policy = <<EOT
# Allow managing secrets in their project folder
path "kvv2/data/projects/${var.project_name}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
# Allow listing the project folder itself
path "kvv2/metadata/projects/${var.project_name}/*" {
  capabilities = ["list", "read", "delete"]
}
EOT
}

# ==============================================================================
# 3. ARGOCD SANDBOX (AppProject)
# ==============================================================================

resource "kubernetes_manifest" "argocd_project" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = var.project_name
      namespace = "argocd"
      annotations = {
        "cnp.3istor.com/description" = var.project_description
      }
    }
    spec = {
      description = "Isolated boundaries for project ${var.project_name}"

      # Allow pulling from any GitHub repository
      sourceRepos = ["*"]

      # Restrict deployments strictly to namespaces starting with the project name
      destinations = [
        {
          namespace = "${var.project_name}-*"
          server    = "https://kubernetes.default.svc"
        }
      ]

      # Define allowed cluster-scoped resources (e.g., Namespaces, CRDs)
      clusterResourceWhitelist = [
        {
          group = ""
          kind  = "Namespace"
        }
      ]

      # RBAC: Map Keycloak groups to ArgoCD roles
      roles = [
        {
          name        = "project-admins"
          description = "Admin privileges for ${var.project_name}"
          policies = [
            "p, proj:${var.project_name}:project-admins, applications, *, ${var.project_name}/*, allow"
          ]
          # Maps to the Keycloak group created above
          groups = ["project-${var.project_name}-admins"]
        },
        {
          name        = "project-members"
          description = "Read-only privileges for ${var.project_name}"
          policies = [
            "p, proj:${var.project_name}:project-members, applications, get, ${var.project_name}/*, allow"
          ]
          # Maps to the Keycloak group created above
          groups = ["project-${var.project_name}-members"]
        }
      ]
    }
  }
}
