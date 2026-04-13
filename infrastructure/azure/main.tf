# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# PostgreSQL as Container
resource "azurerm_container_group" "postgresql" {
  name                = "postgresql-container"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  ip_address_type     = "Public"
  dns_name_label      = "postgresql-${var.environment}"
  restart_policy      = "Always"

  container {
    name   = "postgres"
    image  = "postgres:16-alpine"
    cpu    = 1
    memory = 1.5

    environment_variables = {
      "POSTGRES_USER"     = var.db_username
      "POSTGRES_PASSWORD" = var.db_password
      "POSTGRES_DB"       = "votes"
    }

    ports {
      port     = 5432
      protocol = "TCP"
    }
  }
}



# Container Instance: Kafka (KRaft mode - without Zookeeper)
resource "azurerm_container_group" "kafka" {
  name                = "kafka-container"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  ip_address_type     = "Public"
  dns_name_label      = "kafka-${var.environment}"

  container {
    name   = "kafka"
    image  = "confluentinc/cp-kafka:7.6.0"
    cpu    = "1"
    memory = "2"

    ports {
      port     = 9092
      protocol = "TCP"
    }

    environment_variables = {
      KAFKA_NODE_ID                    = "1"
      KAFKA_PROCESS_ROLES              = "broker,controller"
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR = "1"
      KAFKA_CONTROLLER_QUORUM_VOTERS   = "1@localhost:9093"
      KAFKA_LISTENERS                  = "PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093"
      KAFKA_ADVERTISED_LISTENERS       = "PLAINTEXT://kafka-${var.environment}.${var.location}.azurecontainer.io:9092"
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP = "CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT"
      KAFKA_INTER_BROKER_LISTENER_NAME = "PLAINTEXT"
      KAFKA_CONTROLLER_LISTENER_NAMES  = "CONTROLLER"
      KAFKA_NUM_PARTITIONS             = "3"
      CLUSTER_ID                       = "MkwNYQ3MR0KYjJAXO6e5pQ"
    }
  }
}


