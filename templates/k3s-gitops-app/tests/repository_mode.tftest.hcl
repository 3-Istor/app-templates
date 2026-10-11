mock_provider "github" {}
mock_provider "vault" {
  mock_data "vault_kv_secret_v2" {
    defaults = { data = { DISCORD_WEBHOOK_URL = "test" } }
  }
}
mock_provider "keycloak" {}
mock_provider "cloudflare" {}
mock_provider "random" {}
mock_provider "null" {}

variables {
  github_token            = "test"
  github_owner            = "example"
  app_name                = "web"
  project_name            = "sandbox"
  keycloak_admin_password = "test"
  vault_token             = "test"
  github_registry_token   = "test"
  cloudflare_api_token    = "test"
  cloudflare_account_id   = "00000000000000000000000000000000"
  cloudflare_zone_id      = "00000000000000000000000000000000"
}

run "import_never_manages_source_or_packages" {
  command = plan
  variables {
    repository_mode         = "existing"
    existing_repository_url = "https://github.com/example/original-repo"
  }
  assert {
    condition     = length(github_repository.app) == 0 && length(github_repository_file.values_frontend) == 0 && length(github_repository_file.values_backend) == 0 && length(github_repository_file.security_workflow) == 0 && length(github_actions_secret.discord_webhook_url) == 0 && length(null_resource.delete_ghcr_packages) == 0
    error_message = "Import must not create, edit or destroy source GitHub resources or existing packages."
  }
  assert {
    condition     = output.github_repo_url == "https://github.com/example/original-repo"
    error_message = "The original repository URL must reach CMP and the registry."
  }
}

run "catalog_still_creates_repository" {
  command = plan
  variables {
    template_repo_name = "template-html-css"
  }
  assert {
    condition     = length(github_repository.app) == 1 && length(github_repository_file.values_frontend) == 1 && length(github_repository_file.security_workflow) == 1
    error_message = "Catalog creation must retain its original behavior."
  }
}

run "missing_import_url_is_rejected" {
  command = plan
  variables {
    repository_mode = "existing"
  }
  expect_failures = [var.existing_repository_url]
}
