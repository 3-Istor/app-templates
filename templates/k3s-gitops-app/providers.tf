terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
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
