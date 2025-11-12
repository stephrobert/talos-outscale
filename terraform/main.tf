terraform {
  required_version = ">= 1.0"

  required_providers {
    outscale = {
      source  = "outscale/outscale"
      version = "~> 0.12"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

provider "outscale" {
  access_key_id = var.access_key_id
  secret_key_id = var.secret_key_id
  region        = var.region
}

data "http" "my_public_ip" {
  url = "https://ifconfig.me/ip"
}

locals {
  my_ip_cidr = "${chomp(data.http.my_public_ip.response_body)}/32"

  common_tags = [
    {
      key   = "Cluster"
      value = var.cluster_name
    },
    {
      key   = "Environment"
      value = var.environment
    },
    {
      key   = "ManagedBy"
      value = "Terraform"
    }
  ]
}
