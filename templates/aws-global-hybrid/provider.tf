terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.4.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "openstack" {
  user_name   = "admin"
  tenant_name = var.project_name
  auth_url    = "http://localhost:5000/v3"

  endpoint_overrides = {
    "identity"      = "http://localhost:5000/v3/"
    "network"       = "http://localhost:9696/v2.0/"
    "compute"       = "http://localhost:8774/v2.1/"
    "image"         = "http://localhost:9292/v2/"
    "load-balancer" = "http://localhost:9876/v2/"
  }
}
