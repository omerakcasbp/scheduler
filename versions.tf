terraform {
  required_version = ">= 0.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.9"
    }

    local = {
      version = "~> 2.4.0"
    }
  }
}

