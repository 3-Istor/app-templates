# terraform init -backend=false && terraform test (every provider is mocked).
mock_provider "github" {
  override_data {
    target = data.github_branch.main
    values = { sha = "90343996e5b166c9efb4fe5b6aa391b298a1b690" }
  }
}
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

run "an_unreadable_main_stops_before_any_commit" {
  override_data {
    target = data.github_branch.main
    values = { sha = "" }
  }
  expect_failures = [terraform_data.initial_commit]
}

run "fullstack_values_use_the_initial_commit_sha" {
  assert {
    condition     = strcontains(github_repository_file.values_backend[0].content, "tag: \"sha-9034399\"")
    error_message = "backend values must use sha-9034399"
  }
  assert {
    condition     = strcontains(github_repository_file.values_frontend.content, "tag: \"sha-9034399\"")
    error_message = "frontend values must use sha-9034399"
  }
  assert {
    condition     = !strcontains(github_repository_file.values_backend[0].content, "latest") && !strcontains(github_repository_file.values_frontend.content, "latest")
    error_message = "no generated value may reference latest"
  }
}

run "a_later_apply_keeps_the_initial_sha" {
  # main moved on (bootstrap commits, Dependabot merges) since the repo was created.
  override_data {
    target = data.github_branch.main
    values = { sha = "d660134aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" }
  }
  assert {
    condition     = strcontains(github_repository_file.values_backend[0].content, "tag: \"sha-9034399\"")
    error_message = "a re-apply must keep the initial commit's sha"
  }
}

run "static_values_use_the_initial_commit_sha" {
  variables {
    template_repo_name = "template-html-css"
  }
  assert {
    condition     = strcontains(github_repository_file.values_frontend.content, "tag: \"sha-9034399\"") && !strcontains(github_repository_file.values_frontend.content, "latest")
    error_message = "static values must use sha-9034399, never latest"
  }
}
