# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.resource_group_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "main" {
  name                 = "default-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "aciDelegation"
    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# PostgreSQL Database Server
resource "azurerm_postgresql_server" "main" {
  name                = "microservices-db-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  administrator_login          = var.db_username
  administrator_login_password = var.db_password

  sku_name                     = "B_Gen5_1"
  storage_mb                   = 51200
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = true
  version                      = "11"

  ssl_enforcement_enabled          = true
  ssl_minimal_tls_version_enforced = "TLS1_2"

  public_network_access_enabled = true
}

# PostgreSQL Database
resource "azurerm_postgresql_database" "votes" {
  name                = "votes"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_postgresql_server.main.name
  charset             = "UTF8"
  collation           = "en_US.utf8"
}

# Firewall rule for PostgreSQL (allow Azure services)
resource "azurerm_postgresql_firewall_rule" "allow_azure" {
  name                = "AllowAzureServices"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_postgresql_server.main.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
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


