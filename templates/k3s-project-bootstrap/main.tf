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
# Create a Vault Policy for Human Developers (UI Access to their folder)
resource "vault_policy" "project_developers" {
  name   = "project-${var.project_name}-dev-policy"
  policy = <<EOT
path "kvv2/metadata/projects/${var.project_name}" {
  capabilities = ["list", "read"]
}

path "kvv2/metadata/projects/${var.project_name}/*" {
  capabilities = ["list", "read", "delete"]
}

path "kvv2/data/projects/${var.project_name}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
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

# ==============================================================================
# 4. PROJECT-SPECIFIC ACCESS ROLE AND AUTHENTICATION FLOW
# ==============================================================================

# Create the specific access role for this project
resource "keycloak_role" "project_access" {
  realm_id    = var.keycloak_realm
  name        = "project-${var.project_name}-access"
  description = "Access role required for applications under the ${var.project_name} project"
}

data "keycloak_role" "openid_client_access" {
  realm_id = var.keycloak_realm
  name     = "openid_client_access"
}

# Assign the project access role to project members
resource "keycloak_group_roles" "members_project_access" {
  realm_id = var.keycloak_realm
  group_id = keycloak_group.project_members.id
  role_ids = [
    keycloak_role.project_access.id,
    data.keycloak_role.openid_client_access.id
  ]
}

resource "keycloak_group_roles" "admins_project_access" {
  realm_id = var.keycloak_realm
  group_id = keycloak_group.project_admins.id
  role_ids = [
    keycloak_role.project_access.id,
    data.keycloak_role.openid_client_access.id
  ]
}

# -----------------------------------------------------------------------------
# PHASE 0: ROOT AUTHENTICATION FLOW
# -----------------------------------------------------------------------------
resource "keycloak_authentication_flow" "project_flow" {
  realm_id    = var.keycloak_realm
  alias       = "browser-project-${var.project_name}"
  description = "Complete Flow: Authentication Wrapper followed by Project RBAC Wrapper for ${var.project_name}"
}

# -----------------------------------------------------------------------------
# PHASE 1: LOGIN WRAPPER
# Groups every authentication method.
# If ANY method succeeds, the user is authenticated.
# -----------------------------------------------------------------------------
resource "keycloak_authentication_subflow" "login_wrapper" {
  realm_id          = var.keycloak_realm
  parent_flow_alias = keycloak_authentication_flow.project_flow.alias
  alias             = "login-wrapper-project-${var.project_name}"
  provider_id       = "basic-flow"
  requirement       = "REQUIRED"
  priority          = 10
}

# -----------------------------------------------------------------------------
# PHASE 1.1: SSO AUTHENTICATION METHODS
# -----------------------------------------------------------------------------

# Checks if the user already has a valid Keycloak SSO cookie.
resource "keycloak_authentication_execution" "project_cookie" {
  realm_id          = var.keycloak_realm
  parent_flow_alias = keycloak_authentication_subflow.login_wrapper.alias
  authenticator     = "auth-cookie"
  requirement       = "ALTERNATIVE"
  priority          = 10
}

# Checks for Kerberos ticket (Active Directory SSO)
resource "keycloak_authentication_execution" "project_kerberos" {
  realm_id          = var.keycloak_realm
  parent_flow_alias = keycloak_authentication_subflow.login_wrapper.alias
  authenticator     = "auth-spnego"
  requirement       = "ALTERNATIVE"
  priority          = 20
}

# Redirect to external identity provider if configured
resource "keycloak_authentication_execution" "project_idp_redirector" {
  realm_id          = var.keycloak_realm
  parent_flow_alias = keycloak_authentication_subflow.login_wrapper.alias
  authenticator     = "identity-provider-redirector"
  requirement       = "ALTERNATIVE"
  priority          = 30
}

# -----------------------------------------------------------------------------
# PHASE 1.2: MANUAL LOGIN FALLBACK
# If no SSO method worked, fallback to username/password login
# -----------------------------------------------------------------------------
resource "keycloak_authentication_subflow" "forms_wrapper" {
  realm_id          = var.keycloak_realm
  parent_flow_alias = keycloak_authentication_subflow.login_wrapper.alias
  alias             = "forms-wrapper-project-${var.project_name}"
  provider_id       = "basic-flow"
  requirement       = "ALTERNATIVE"
  priority          = 40
}

# Standard Keycloak login page
resource "keycloak_authentication_execution" "project_username_password" {
  realm_id          = var.keycloak_realm
  parent_flow_alias = keycloak_authentication_subflow.forms_wrapper.alias
  authenticator     = "auth-username-password-form"
  requirement       = "REQUIRED"
  priority          = 10
}

# -----------------------------------------------------------------------------
# PHASE 1.3: MULTI FACTOR AUTHENTICATION
# Triggered after successful username/password authentication. Mandatory for all.
# -----------------------------------------------------------------------------
resource "keycloak_authentication_subflow" "mandatory_otp" {
  realm_id          = var.keycloak_realm
  parent_flow_alias = keycloak_authentication_subflow.forms_wrapper.alias
  alias             = "mandatory-otp-project-${var.project_name}"
  provider_id       = "basic-flow"
  requirement       = "REQUIRED"
  priority          = 20
}

# Ask for OTP token.
resource "keycloak_authentication_execution" "project_otp_form" {
  realm_id          = var.keycloak_realm
  parent_flow_alias = keycloak_authentication_subflow.mandatory_otp.alias
  authenticator     = "auth-otp-form"
  requirement       = "REQUIRED"
  priority          = 10
}

# -----------------------------------------------------------------------------
# PHASE 2: RBAC WRAPPER
# The user is authenticated at this point.
# We now verify if the user is authorized to access this specific project's applications.
# -----------------------------------------------------------------------------
resource "keycloak_authentication_subflow" "rbac_deny_wrapper" {
  realm_id          = var.keycloak_realm
  parent_flow_alias = keycloak_authentication_flow.project_flow.alias
  alias             = "rbac-deny-wrapper-project-${var.project_name}"
  provider_id       = "basic-flow"
  requirement       = "CONDITIONAL"
  priority          = 20
}

# Check if user has required role
resource "keycloak_authentication_execution" "project_condition_role" {
  realm_id          = var.keycloak_realm
  parent_flow_alias = keycloak_authentication_subflow.rbac_deny_wrapper.alias
  authenticator     = "conditional-user-role"
  requirement       = "REQUIRED"
  priority          = 10
}

resource "keycloak_authentication_execution_config" "project_condition_role_config" {
  realm_id     = var.keycloak_realm
  execution_id = keycloak_authentication_execution.project_condition_role.id
  alias        = "check-role-project-${var.project_name}"

  config = {
    condUserRole = keycloak_role.project_access.name
    negate       = "true" # Trigger subflow if the user lacks the role
  }
}

# If user does NOT have required role -> deny access
resource "keycloak_authentication_execution" "project_deny_access" {
  realm_id          = var.keycloak_realm
  parent_flow_alias = keycloak_authentication_subflow.rbac_deny_wrapper.alias
  authenticator     = "deny-access-authenticator"
  requirement       = "REQUIRED"
  priority          = 20
}

data "vault_auth_backend" "oidc" {
  path = "oidc"
}

resource "vault_identity_group" "project_devs" {
  name     = "project-${var.project_name}-devs"
  type     = "external"
  policies = [vault_policy.project_developers.name]
}

resource "vault_identity_group_alias" "project_admins_alias" {
  name           = "project-${var.project_name}-admins"
  mount_accessor = data.vault_auth_backend.oidc.accessor
  canonical_id   = vault_identity_group.project_devs.id
}

resource "vault_identity_group_alias" "project_members_alias" {
  name           = "project-${var.project_name}-members"
  mount_accessor = data.vault_auth_backend.oidc.accessor
  canonical_id   = vault_identity_group.project_devs.id
}
