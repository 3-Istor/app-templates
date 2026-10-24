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
      version = "5.27.0"
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
  client_id = "admin-cli"
  url       = var.keycloak_url
  username  = var.keycloak_admin_username
  password  = var.keycloak_admin_password
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
