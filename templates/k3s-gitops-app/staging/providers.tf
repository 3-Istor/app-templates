terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.9"
    }
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.7"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.19.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }

  # No kubernetes provider, as in the parent module (D-02).

  backend "s3" {}
}

provider "vault" {
  address = var.vault_url
  token   = var.vault_token
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

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
