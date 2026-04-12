# Container Instance: Vote Service
resource "azurerm_container_group" "vote" {
  name                = "vote-service"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  ip_address_type     = "Public"
  dns_name_label      = "vote-${var.environment}"

  image_registry_credential {
    server            = var.github_registry
    username          = var.github_username
    password          = var.github_token
  }

  container {
    name   = "vote"
    image  = "${var.github_registry}/itsJuanda17/microservices-demo/vote:latest"
    cpu    = "1"
    memory = "1.5"

    ports {
      port     = 8080
      protocol = "TCP"
    }

    environment_variables = {
      KAFKA_BROKER = "kafka-${var.environment}.${var.location}.azurecontainer.io:9092"
      KAFKA_TOPIC  = "votes"
    }
  }
}

# Container Instance: Worker Service
resource "azurerm_container_group" "worker" {
  name                = "worker-service"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  ip_address_type     = "Public"
  dns_name_label      = "worker-${var.environment}"

  image_registry_credential {
    server            = var.github_registry
    username          = var.github_username
    password          = var.github_token
  }

  container {
    name   = "worker"
    image  = "${var.github_registry}/itsJuanda17/microservices-demo/worker:latest"
    cpu    = "1"
    memory = "1.5"

    environment_variables = {
      KAFKA_BROKER       = "kafka-${var.environment}.${var.location}.azurecontainer.io:9092"
      KAFKA_GROUP        = "worker-group"
      KAFKA_TOPIC        = "votes"
      DATABASE_URL       = "postgres://${var.db_username}:${var.db_password}@${azurerm_postgresql_server.main.fqdn}:5432/votes"
      CIRCUIT_BREAKER_THRESHOLD = "5"
      CIRCUIT_BREAKER_TIMEOUT   = "10"
    }
  }
}

# Container Instance: Result Service
resource "azurerm_container_group" "result" {
  name                = "result-service"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  ip_address_type     = "Public"
  dns_name_label      = "result-${var.environment}"

  image_registry_credential {
    server            = var.github_registry
    username          = var.github_username
    password          = var.github_token
  }

  container {
    name   = "result"
    image  = "${var.github_registry}/itsJuanda17/microservices-demo/result:latest"
    cpu    = "1"
    memory = "1.5"

    ports {
      port     = 80
      protocol = "TCP"
    }

    environment_variables = {
      DATABASE_URL = "postgres://${var.db_username}:${var.db_password}@${azurerm_postgresql_server.main.fqdn}:5432/votes"
      NODE_ENV     = var.environment
      CIRCUIT_BREAKER_THRESHOLD = "5"
      CIRCUIT_BREAKER_TIMEOUT   = "10"
    }
  }
}
