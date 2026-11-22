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

run "onprem_app_has_roles_on_both_cloud_mounts" {
  variables {
    target_cloud = "onprem"
  }
  assert {
    condition     = keys(vault_kubernetes_auth_backend_role.app_role_away) == ["kubernetes-aws", "kubernetes-gcp"]
    error_message = "an on-prem app needs its role on the aws and gcp mounts for a move"
  }
}

run "aws_app_has_a_role_on_the_onprem_mount" {
  variables {
    target_cloud = "aws"
  }
  assert {
    condition     = keys(vault_kubernetes_auth_backend_role.app_role_away) == ["kubernetes"] && vault_kubernetes_auth_backend_role.app_role_peer[0].backend == "kubernetes-gcp"
    error_message = "a cloud app needs its role on kubernetes, and keeps its peer role"
  }
}
