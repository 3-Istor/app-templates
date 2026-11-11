# terraform init -backend=false && terraform test (every provider is mocked).
mock_provider "keycloak" {}
mock_provider "vault" {}
mock_provider "random" {}

variables {
  project_name            = "test-hugo"
  keycloak_admin_password = "p"
  vault_token             = "t"
}

run "names_the_staging_realm" {
  command = plan

  assert {
    condition     = keycloak_realm.staging.realm == "test-hugo-staging"
    error_message = "the staging realm must be <project>-staging, apart from the production realm"
  }
  assert {
    condition     = keycloak_realm.staging.registration_allowed == false
    error_message = "nobody may self-register in staging"
  }
  assert {
    condition     = keycloak_openid_client.broker.client_id == "broker-test-hugo-staging"
    error_message = "the broker client must be named after the staging realm"
  }
  assert {
    condition     = keycloak_openid_client.broker.valid_redirect_uris == toset(["https://auth.3istor.com/realms/test-hugo-staging/broker/3istor-platform/endpoint"])
    error_message = "the broker may only redirect to the staging realm's endpoint"
  }
  assert {
    condition     = vault_kv_secret_v2.admin_creds.name == "keycloak-tenant-admin-staging"
    error_message = "the staging admin credentials must not overwrite the production ones"
  }

  assert {
    condition     = keycloak_oidc_identity_provider.platform.extra_config["allowAdminRoleMapping"] == "true"
    error_message = "the broker must be allowed to fill project-admins, which carries the realm admin roles"
  }

  assert {
    condition     = !contains(keys(data.keycloak_role.admin), "realm-admin") && !contains(keys(data.keycloak_role.admin), "impersonation")
    error_message = "the cmp-provisioner client can neither map realm-admin nor grant impersonation"
  }
  assert {
    condition     = length(data.keycloak_role.admin) == 20
    error_message = "the staging admins keep every role of realm-admin but impersonation"
  }
}
