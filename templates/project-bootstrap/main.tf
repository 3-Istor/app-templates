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
  description = "Isolated secrets engine for project ${var.project_name} on ${var.target_cloud}"
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

  depends_on = [
    keycloak_user.tenant_admin,
    data.keycloak_role.tenant_realm_admin_role
  ]
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
    "DISCORD_WEBHOOK_URL" = var.discord_webhook_url
  })
}

resource "vault_policy" "project_system_policy" {
  name   = "project-${var.project_name}-system-policy"
  policy = <<EOT
# Pour un moteur KV v2, Vault exige d'ajouter "/data/" juste après le nom du mount
path "project-${var.project_name}/data/system/*" {
  capabilities = ["read"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "project_system_role" {
  # Every cluster's vault-secrets-operator authenticates against a single,
  # fixed mount ("auth/kubernetes") set once at operator startup, so the role
  # itself has to live under that same mount regardless of target_cloud — a
  # per-cloud mount only makes sense once each cloud runs its own cluster
  # (and thus its own operator instance with its own VAULT_KUBERNETES_PATH).
  # Revisit when an AWS/GCP cluster actually exists.
  backend                          = "kubernetes"
  role_name                        = "project-${var.project_name}-system-role"
  bound_service_account_names      = ["vault-secrets-operator"]
  bound_service_account_namespaces = ["vault-secrets-operator"]
  token_ttl                        = 86400
  token_policies                   = [vault_policy.project_system_policy.name]
}

# ==============================================================================
# PROJECT INGRESS — one tunnel per project (D-06)
# ==============================================================================

# Previously: the project's status- and offhours- hostnames pointed at a shared
# account-wide tunnel named 3istor-cloud-tunnel, while each application created
# a tunnel of its own. Three regimes, none of them per project.
#
# Now the project owns exactly one tunnel. Applications add hostnames to it.
# Its routing table is not configured here: it is rendered from the project's
# registry record by cnp-project-base and delivered by Argo CD, so adding a
# route to a running project no longer requires the on-prem runner.
resource "random_password" "tunnel_secret" {
  length  = 64
  special = false
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "project_tunnel" {
  account_id    = var.cloudflare_account_id
  name          = "cnp-${var.project_name}-tunnel"
  config_src    = "local"
  tunnel_secret = base64encode(random_password.tunnel_secret.result)
}

# The connector reads this from a Kubernetes Secret the operator syncs. It used
# to be written straight into etcd by the application module (D-02).
resource "vault_kv_secret_v2" "project_tunnel_token" {
  mount               = vault_mount.project_kv.path
  name                = "system/tunnel"
  delete_all_versions = true
  data_json = jsonencode({
    token = base64encode(jsonencode({
      a = var.cloudflare_account_id
      t = cloudflare_zero_trust_tunnel_cloudflared.project_tunnel.id
      s = base64encode(random_password.tunnel_secret.result)
    }))
  })
}

locals {
  tunnel_cname = "${cloudflare_zero_trust_tunnel_cloudflared.project_tunnel.id}.cfargotunnel.com"
  marker       = "cnp.project=${var.project_name} cnp.cloud=${var.target_cloud}"
}

resource "cloudflare_dns_record" "project_status_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "status-${var.project_name}"
  content = local.tunnel_cname
  type    = "CNAME"
  proxied = true
  ttl     = 1
  comment = local.marker
}

resource "cloudflare_dns_record" "project_offhours_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "offhours-${var.project_name}"
  content = local.tunnel_cname
  type    = "CNAME"
  proxied = true
  ttl     = 1
  comment = local.marker
}

# ==============================================================================
# Note on the project's Argo CD objects
# ==============================================================================
#
# This module used to write cnp-projects/projects/<name>.yaml — a hand-rolled
# Argo CD Application pinned to https://kubernetes.default.svc.
#
# It no longer does. CMP writes the project's record to
# cnp-projects/registry/projects/<name>.yaml (D-01) and the ApplicationSet in
# K3s generates the Applications from it, addressing the cluster by name (D-03).
# Two writers of the same concept is how a registry and reality drift apart.
