terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.7"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.9"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }

  backend "s3" {}
}

provider "keycloak" {
  # The cmp-provisioner client (client credentials) when its secret is given,
  # else the legacy master admin user.
  client_id     = var.keycloak_client_secret != "" ? var.keycloak_client_id : "admin-cli"
  client_secret = var.keycloak_client_secret != "" ? var.keycloak_client_secret : null
  username      = var.keycloak_client_secret != "" ? null : var.keycloak_admin_username
  password      = var.keycloak_client_secret != "" ? null : var.keycloak_admin_password
  url           = var.keycloak_url
}

provider "vault" {
  address = var.vault_url
  token   = var.vault_token
}
