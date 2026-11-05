# ponytail: copy of project-bootstrap's tenant realm; share a module once both can be planned safely.

# ==============================================================================
# STAGING REALM (end users of the staging environments, apart from production)
# ==============================================================================

resource "keycloak_realm" "staging" {
  realm        = "${var.project_name}-staging"
  enabled      = true
  display_name = "${title(var.project_name)} App Realm (staging)"

  # Explicit: staging must never take sign-ups, whatever the provider default is.
  registration_allowed = false

  login_theme = "keycloak-theme-kube-lab"
}

resource "keycloak_realm_events" "staging" {
  realm_id = keycloak_realm.staging.id

  events_enabled    = true
  events_expiration = 2592000 # 30 days, matching the Loki retention

  admin_events_enabled         = true
  admin_events_details_enabled = false

  events_listeners = ["jboss-logging"]
}

resource "random_password" "admin" {
  length  = 16
  special = false
}

resource "keycloak_user" "admin" {
  realm_id = keycloak_realm.staging.id
  username = "admin"
  enabled  = true
  email    = "admin@${var.project_name}-staging.local"

  initial_password {
    value     = random_password.admin.result
    temporary = false
  }

  # Keycloak 26.5 answers 500 (NPE in UserCacheManager.fullUserInvalidation) when a user is
  # created while the realm's first identity provider is being added.
  depends_on = [keycloak_oidc_identity_provider.platform]
}

data "keycloak_openid_client" "realm_management" {
  realm_id  = keycloak_realm.staging.id
  client_id = "realm-management"
}

data "keycloak_role" "realm_admin" {
  realm_id  = keycloak_realm.staging.id
  client_id = data.keycloak_openid_client.realm_management.id
  name      = "realm-admin"
}

resource "keycloak_user_roles" "admin_grants" {
  realm_id = keycloak_realm.staging.id
  user_id  = keycloak_user.admin.id
  role_ids = [data.keycloak_role.realm_admin.id]
}

# The project's KV mount is created by project-bootstrap.
resource "vault_kv_secret_v2" "admin_creds" {
  mount               = "project-${var.project_name}"
  name                = "keycloak-tenant-admin-staging"
  delete_all_versions = true
  data_json = jsonencode({
    realm_url = "https://admin-auth.3istor.com/admin/${keycloak_realm.staging.realm}/console/"
    username  = keycloak_user.admin.username
    password  = random_password.admin.result
  })
}

# ==============================================================================
# IDENTITY BROKERING (developers log in with their platform accounts)
# ==============================================================================

resource "keycloak_openid_client" "broker" {
  realm_id              = var.keycloak_realm
  client_id             = "broker-${var.project_name}-staging"
  name                  = "Broker for Tenant ${var.project_name} (staging)"
  enabled               = true
  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true
  valid_redirect_uris = [
    "https://auth.3istor.com/realms/${var.project_name}-staging/broker/3istor-platform/endpoint"
  ]
}

resource "keycloak_oidc_identity_provider" "platform" {
  realm             = keycloak_realm.staging.id
  alias             = "3istor-platform"
  display_name      = "Log in with 3istor Platform"
  authorization_url = "https://auth.3istor.com/realms/${var.keycloak_realm}/protocol/openid-connect/auth"
  token_url         = "https://auth.3istor.com/realms/${var.keycloak_realm}/protocol/openid-connect/token"
  client_id         = keycloak_openid_client.broker.client_id
  client_secret     = keycloak_openid_client.broker.client_secret
  default_scopes    = "openid profile email"
}

# ==============================================================================
# PROJECT GROUPS IN THE STAGING REALM (app access by membership)
# ==============================================================================

# An app's SecurityPolicy can only allow groups of the app's own realm, so each
# broker login copies the platform membership into these groups.
resource "keycloak_group" "project_members" {
  realm_id = keycloak_realm.staging.id
  name     = "project-members"
}

resource "keycloak_group" "project_admins" {
  realm_id = keycloak_realm.staging.id
  name     = "project-admins"
}

# FORCE re-evaluates the claim at every broker login, so removing someone from
# the platform group takes their access away at their next login.
resource "keycloak_custom_identity_provider_mapper" "platform_members" {
  realm                    = keycloak_realm.staging.id
  name                     = "platform-project-members"
  identity_provider_alias  = keycloak_oidc_identity_provider.platform.alias
  identity_provider_mapper = "oidc-advanced-group-idp-mapper"
  extra_config = {
    claims                   = jsonencode([{ key = "groups", value = "project-${var.project_name}-members" }])
    "are.claim.values.regex" = "false"
    group                    = "/${keycloak_group.project_members.name}"
    syncMode                 = "FORCE"
  }
}

resource "keycloak_custom_identity_provider_mapper" "platform_admins" {
  realm                    = keycloak_realm.staging.id
  name                     = "platform-project-admins"
  identity_provider_alias  = keycloak_oidc_identity_provider.platform.alias
  identity_provider_mapper = "oidc-advanced-group-idp-mapper"
  extra_config = {
    claims                   = jsonencode([{ key = "groups", value = "project-${var.project_name}-admins" }])
    "are.claim.values.regex" = "false"
    group                    = "/${keycloak_group.project_admins.name}"
    syncMode                 = "FORCE"
  }
}

# The platform realm must put the groups in the token it issues to the broker client.
resource "keycloak_openid_client_default_scopes" "broker" {
  realm_id  = var.keycloak_realm
  client_id = keycloak_openid_client.broker.id
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

# Apps of this realm read the groups claim from their access token.
resource "keycloak_openid_client_scope" "groups" {
  realm_id               = keycloak_realm.staging.id
  name                   = "groups"
  include_in_token_scope = true
}

resource "keycloak_openid_group_membership_protocol_mapper" "groups" {
  realm_id        = keycloak_realm.staging.id
  client_scope_id = keycloak_openid_client_scope.groups.id
  name            = "groups"
  claim_name      = "groups"
  full_path       = false
}
