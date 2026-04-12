terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "environment" {
  description = "Environment name"
  default     = "dev"
}

variable "location" {
  description = "Azure region"
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Resource group name"
  default     = "microservices-demo-rg"
}

variable "db_username" {
  description = "PostgreSQL admin username"
  default     = "postgres"
}

variable "db_password" {
  description = "PostgreSQL admin password"
  sensitive   = true
}

variable "github_registry" {
  description = "GitHub Container Registry URL"
  default     = "ghcr.io"
}

variable "github_username" {
  description = "GitHub username for registry access"
  sensitive   = true
}

variable "github_token" {
  description = "GitHub token for registry access"
  sensitive   = true
}
