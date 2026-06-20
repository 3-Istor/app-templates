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

resource "vault_mount" "project_kv" {
  path        = "project-${var.project_name}"
  type        = "kv"
  options     = { version = "2" }
  description = "Isolated secrets engine for project ${var.project_name}"
}

resource "vault_policy" "project_developers" {
  name   = "project-${var.project_name}-dev-policy"
  policy = <<EOT
path "sys/mounts" {
  capabilities = ["read"]
}
path "sys/internal/ui/mounts/*" {
  capabilities = ["read"]
}

path "project-${var.project_name}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOT
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

# ==============================================================================
# TENANT REALM (End-User Identity)
# ==============================================================================

resource "keycloak_realm" "tenant_realm" {
  realm        = var.project_name
  enabled      = true
  display_name = "${title(var.project_name)} App Realm"

  login_theme = "keycloak-theme-kube-lab"
}

# Create a local admin for this specific tenant realm
resource "random_password" "tenant_admin_pwd" {
  length  = 16
  special = false
}

resource "keycloak_user" "tenant_admin" {
  realm_id = keycloak_realm.tenant_realm.id
  username = "admin"
  enabled  = true
  email    = "admin@${var.project_name}.local"

  initial_password {
    value     = random_password.tenant_admin_pwd.result
    temporary = false
  }
}

# Grant realm-admin rights to the tenant admin
data "keycloak_openid_client" "tenant_realm_management" {
  realm_id  = keycloak_realm.tenant_realm.id
  client_id = "realm-management"
}

data "keycloak_role" "tenant_realm_admin_role" {
  realm_id  = keycloak_realm.tenant_realm.id
  client_id = data.keycloak_openid_client.tenant_realm_management.id
  name      = "realm-admin"
}

resource "keycloak_user_roles" "tenant_admin_grants" {
  realm_id = keycloak_realm.tenant_realm.id
  user_id  = keycloak_user.tenant_admin.id
  role_ids = [data.keycloak_role.tenant_realm_admin_role.id]
}

# Store Tenant Realm Admin credentials in the Project's Vault path
resource "vault_kv_secret_v2" "tenant_realm_creds" {
  mount               = vault_mount.project_kv.path
  name                = "keycloak-tenant-admin"
  delete_all_versions = true
  data_json = jsonencode({
    realm_url = "https://admin-auth.3istor.com/admin/${keycloak_realm.tenant_realm.realm}/console/"
    username  = keycloak_user.tenant_admin.username
    password  = random_password.tenant_admin_pwd.result
  })
}

# ==============================================================================
# IDENTITY BROKERING (Allow Developers to log in with Platform accounts)
# ==============================================================================

# Register the Tenant Realm as a client in the Platform Realm (3istor)
resource "keycloak_openid_client" "tenant_broker_client" {
  realm_id              = var.keycloak_realm # "3istor"
  client_id             = "broker-${var.project_name}"
  name                  = "Broker for Tenant ${var.project_name}"
  enabled               = true
  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true
  valid_redirect_uris = [
    "https://auth.3istor.com/realms/${var.project_name}/broker/3istor-platform/endpoint"
  ]
}

# Configure the Tenant Realm to trust the Platform Realm
resource "keycloak_oidc_identity_provider" "platform_idp" {
  realm             = keycloak_realm.tenant_realm.id
  alias             = "3istor-platform"
  display_name      = "Log in with 3istor Platform"
  authorization_url = "https://auth.3istor.com/realms/${var.keycloak_realm}/protocol/openid-connect/auth"
  token_url         = "https://auth.3istor.com/realms/${var.keycloak_realm}/protocol/openid-connect/token"
  client_id         = keycloak_openid_client.tenant_broker_client.client_id
  client_secret     = keycloak_openid_client.tenant_broker_client.client_secret
  default_scopes    = "openid profile email"
}


# ==============================================================================
# Gatus
# ==============================================================================
resource "vault_kv_secret_v2" "project_system_secrets" {
  mount               = vault_mount.project_kv.path
  name                = "system/discord"
  delete_all_versions = true
  data_json = jsonencode({
    "webhook-url" = var.discord_webhook_url
  })
}

# ==============================================================================
# Base helm chart
# ==============================================================================

provider "github" {
  token = var.github_token
  owner = "3-Istor"
}

resource "github_repository_file" "argocd_project_app" {
  repository          = "cnp-projects"
  branch              = "main"
  file                = "projects/${var.project_name}.yaml"
  commit_message      = "feat: Bootstrap project ${var.project_name} [skip ci]"
  overwrite_on_create = true

  content = <<-EOT
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: ${var.project_name}-bootstrap
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: https://github.com/3-Istor/infra-templates.git
        targetRevision: HEAD
        path: charts/cnp-project-base
        helm:
          values: |
            projectName: "${var.project_name}"
            features:
              gatus: true
      destination:
        server: https://kubernetes.default.svc
        namespace: project-${var.project_name}-system
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
          - ServerSideApply=true
  EOT
}
