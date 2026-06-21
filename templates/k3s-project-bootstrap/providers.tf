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
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.19.1"
    }
  }

  backend "s3" {}
}

provider "keycloak" {
  client_id = "admin-cli"
  url       = var.keycloak_url
  username  = var.keycloak_admin_username
  password  = var.keycloak_admin_password
}

provider "vault" {
  address = var.vault_url
  token   = var.vault_token
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
