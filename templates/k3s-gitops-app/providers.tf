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
    null = {
      source  = "hashicorp/null"
      version = "~> 3.3"
    }
  }

  # No kubernetes provider, deliberately (D-02).
  #
  # This module used to declare provider "kubernetes" {} with no configuration,
  # authenticating in-cluster or from whatever kubeconfig the runner happened to
  # have, and writing a namespace, two secrets and three manifests straight into
  # the API server. Extending that to three clouds would mean standing,
  # high-privilege credentials for the on-prem runner on every remote API
  # server, a hard VPN dependency on the provisioning path, and partial applies
  # leaving objects on a remote cluster with no reconciler to converge them.
  #
  # Everything Kubernetes-shaped is now either a Vault secret plus a sync, or
  # desired state in Git that Argo CD converges. Argo CD is the only component
  # holding credentials on remote clusters, and it is the one designed to
  # reconcile continuously.
  #
  # If you find yourself adding the kubernetes provider back here, that is the
  # decision being reversed — go and reverse it in cnp-docs first.

  backend "s3" {}
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
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
