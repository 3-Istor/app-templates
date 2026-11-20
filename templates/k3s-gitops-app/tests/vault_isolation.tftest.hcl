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

run "the_app_role_gets_the_app_policy_only" {
  command = plan

  assert {
    condition     = vault_kubernetes_auth_backend_role.app_role.token_policies == toset(["project-test-hugo-app-app-test-policy"])
    error_message = "The app's VSO role must carry its own policy, not the project's."
  }
}

run "the_app_policy_reads_the_app_subtree_only" {
  command = plan

  assert {
    condition = (
      strcontains(vault_policy.app.policy, "path \"project-test-hugo/data/app-test\" {")
      && strcontains(vault_policy.app.policy, "path \"project-test-hugo/data/app-test/*\" {")
      && strcontains(vault_policy.app.policy, "path \"project-test-hugo/metadata/app-test/*\" {")
      && !strcontains(vault_policy.app.policy, "project-test-hugo/*")
      && !strcontains(vault_policy.app.policy, "\"update\"")
    )
    error_message = "The app policy must read its own subtree and nothing else."
  }
}
