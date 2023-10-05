terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.19.0"

      configuration_aliases = [ aws.alternate ]
    }
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "16.4.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
  }
}