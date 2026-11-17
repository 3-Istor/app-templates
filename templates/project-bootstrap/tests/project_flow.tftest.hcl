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

run "public_project_has_a_role_on_the_other_public_mount" {
  command   = plan
  variables { target_cloud = "aws" }

  assert {
    condition     = vault_kubernetes_auth_backend_role.project_system_role_peer[0].backend == "kubernetes-gcp" && vault_kubernetes_auth_backend_role.project_system_role.backend == "kubernetes-aws"
    error_message = "an aws project needs its role on kubernetes-gcp too"
  }
}

run "onprem_project_has_no_peer_role" {
  command   = plan
  variables { target_cloud = "onprem" }

  assert {
    condition     = length(vault_kubernetes_auth_backend_role.project_system_role_peer) == 0
    error_message = "on-prem has a single mount"
  }
}
