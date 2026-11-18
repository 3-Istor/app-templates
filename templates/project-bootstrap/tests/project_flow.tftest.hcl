# terraform init -backend=false && terraform test (every provider is mocked).
mock_provider "keycloak" {}
mock_provider "vault" {}
mock_provider "cloudflare" {}
mock_provider "grafana" {}
mock_provider "random" {}
mock_provider "time" {}

override_resource {
  target          = keycloak_authentication_flow.project_flow
  override_during = plan
  values = {
    id = "project-flow-id"
  }
}

variables {
  project_name           = "test-hugo"
  vault_token            = "t"
  discord_webhook_url    = "https://discord.invalid/webhook"
  cloudflare_api_token   = "c"
  cloudflare_account_id  = "a"
  cloudflare_zone_id     = "z"
  grafana_admin_password = "g"
  loki_password          = "l"
}

run "binds_the_project_flow_to_the_broker" {
  command = plan

  assert {
    condition     = one([for o in keycloak_openid_client.tenant_broker_client.authentication_flow_binding_overrides : o.browser_id]) == keycloak_authentication_flow.project_flow.id
    error_message = "without the project flow any platform account logs in to the project realm"
  }
  assert {
    condition     = keycloak_authentication_execution_config.project_condition_role_config.config.condUserRole == "project-test-hugo-access"
    error_message = "the flow must deny users without the project access role"
  }
  assert {
    condition     = keycloak_authentication_subflow.second_factor.requirement == "CONDITIONAL" && keycloak_authentication_execution_config.project_condition_no_passkey.config == tomap({ credentials = "webauthn-passwordless", included = "false" })
    error_message = "a passkey must skip the OTP, as in the platform flow v5"
  }
}

run "offhours_login_goes_through_the_tenant_realm" {
  command = plan

  assert {
    condition     = keycloak_openid_client.offhours_client.valid_redirect_uris == toset(["https://offhours-test-hugo.3istor.com/oauth2/callback"])
    error_message = "the Gateway's OIDC callback for offhours-<project> must be allowed"
  }
  assert {
    condition     = contains(keycloak_openid_client_default_scopes.offhours_client_scopes.default_scopes, "groups")
    error_message = "offhours-guard reads project membership from the groups claim"
  }
  assert {
    condition     = vault_kv_secret_v2.offhours_oidc.name == "system/offhours-oidc"
    error_message = "the project system role only reads system/*, where cnp-project-base syncs the secret from"
  }
}
