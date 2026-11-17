# terraform init -backend=false && terraform test (every provider is mocked).
mock_provider "github" {}
mock_provider "vault" {
  override_data {
    target = data.vault_kv_secret_v2.discord
    values = { data = { DISCORD_WEBHOOK_URL = "" } }
  }
}
mock_provider "keycloak" {}
mock_provider "cloudflare" {}
mock_provider "random" {}
mock_provider "null" {}

variables {
  github_token            = "t"
  github_owner            = "3-Istor"
  template_repo_name      = "template-app-webapp-python-fastapi-react"
  app_name                = "app-test"
  project_name            = "test-hugo"
  keycloak_admin_password = "p"
  vault_token             = "t"
  github_registry_token   = "t"
  cloudflare_api_token    = "t"
  cloudflare_account_id   = "a"
  cloudflare_zone_id      = "z"
}

run "fullstack_backend_is_instrumented" {
  assert {
    condition = alltrue([
      yamldecode(github_repository_file.values_backend[0].content).metrics.enabled,
      yamldecode(github_repository_file.values_backend[0].content).tracing.enabled,
      yamldecode(github_repository_file.values_backend[0].content).livenessProbe.httpGet.path == "/health",
      yamldecode(github_repository_file.values_backend[0].content).readinessProbe.httpGet.path == "/health",
    ])
    error_message = "a new backend must expose /metrics, send traces and be probed on /health (CNP-185 D11)"
  }
}

run "fullstack_frontend_is_probed" {
  assert {
    condition     = yamldecode(github_repository_file.values_frontend.content).readinessProbe.enabled
    error_message = "a new frontend must have its readiness probe rendered"
  }
}

run "public_app_has_a_role_on_the_other_public_mount" {
  variables { target_cloud = "aws" }

  assert {
    condition     = vault_kubernetes_auth_backend_role.app_role_peer[0].backend == "kubernetes-gcp" && vault_kubernetes_auth_backend_role.app_role.backend == "kubernetes-aws"
    error_message = "an aws app needs its role on kubernetes-gcp too"
  }
}

run "onprem_app_has_no_peer_role" {
  variables { target_cloud = "onprem" }

  assert {
    condition     = length(vault_kubernetes_auth_backend_role.app_role_peer) == 0
    error_message = "on-prem has a single mount"
  }
}
