# terraform init -backend=false && terraform test (every provider is mocked).
mock_provider "vault" {}
mock_provider "keycloak" {}
mock_provider "cloudflare" {}
mock_provider "random" {}

variables {
  app_name              = "app-test"
  project_name          = "test-hugo"
  vault_token           = "t"
  github_registry_token = "t"
  cloudflare_api_token  = "t"
  cloudflare_account_id = "a"
  cloudflare_zone_id    = "z"
}

run "public_staging_has_a_role_on_the_other_public_mount" {
  variables { target_cloud = "gcp" }

  assert {
    condition     = vault_kubernetes_auth_backend_role.staging_role_peer[0].backend == "kubernetes-aws" && vault_kubernetes_auth_backend_role.staging_role.backend == "kubernetes-gcp"
    error_message = "a gcp staging environment needs its role on kubernetes-aws too"
  }
}

run "onprem_staging_has_no_peer_role" {
  variables { target_cloud = "onprem" }

  assert {
    condition     = length(vault_kubernetes_auth_backend_role.staging_role_peer) == 0
    error_message = "on-prem has a single mount"
  }
}
