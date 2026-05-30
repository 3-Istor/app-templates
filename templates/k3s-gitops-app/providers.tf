terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.12"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.9"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.1"
    }
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.7"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.19.1"
    }
  }
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}

provider "vault" {
  address = var.vault_url
  token   = var.vault_token
}

provider "kubernetes" {
  config_path = "~/.kube/config" # Assuming local development, CMP will use cluster auth
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
