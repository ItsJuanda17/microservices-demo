variable "resource_group_name" {
  type        = string
  description = "Name of the Azure resource group"
  default     = "microservices-taller"
}

variable "location" {
  type        = string
  description = "Azure region deployment location"
  default     = "eastus2"
}

variable "environment" {
  type        = string
  description = "Environment name (taller1, prod, dev, etc.)"
  default     = "taller1"
}

variable "db_username" {
  type        = string
  description = "PostgreSQL username"
  default     = "okteto"
}

variable "db_password" {
  type        = string
  description = "PostgreSQL password"
  sensitive   = true
  default     = "okteto"
}
