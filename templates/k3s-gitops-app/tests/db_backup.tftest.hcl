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

run "onprem_database_is_backed_up" {
  variables {
    target_cloud = "onprem"
  }
  assert {
    condition     = yamldecode(github_repository_file.values_backend[0].content).db.backup.enabled == true
    error_message = "an on-prem backend database must be generated with backups on"
  }
}

run "aws_database_is_not_backed_up" {
  variables {
    target_cloud = "aws"
  }
  assert {
    condition     = yamldecode(github_repository_file.values_backend[0].content).db.backup.enabled == false
    error_message = "no bucket is served on AWS yet: backups must stay off"
  }
}

run "gcp_database_is_not_backed_up" {
  variables {
    target_cloud = "gcp"
  }
  assert {
    condition     = yamldecode(github_repository_file.values_backend[0].content).db.backup.enabled == false
    error_message = "no bucket is served on GCP yet: backups must stay off"
  }
}
