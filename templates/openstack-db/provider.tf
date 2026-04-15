terraform {
  required_version = ">= 1.5"
  backend "s3" {}

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
  }
}
