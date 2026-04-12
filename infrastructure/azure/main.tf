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

# Network Interface for ACI
resource "azurerm_network_interface" "aci" {
  name                = "aci-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "testConfiguration"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
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

# Container Instance: PostgreSQL
resource "azurerm_container_group" "postgres" {
  name                = "postgres-container"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  ip_address_type     = "Public"
  dns_name_label      = "postgres-${var.environment}"

  container {
    name   = "postgres"
    image  = "postgres:16"
    cpu    = "0.5"
    memory = "1"

    ports {
      port     = 5432
      protocol = "TCP"
    }

    environment_variables = {
      POSTGRES_USER     = var.db_username
      POSTGRES_PASSWORD = var.db_password
      POSTGRES_DB       = "votes"
    }

    volume {
      name                = "db-volume"
      mount_path          = "/var/lib/postgresql/data"
      storage_account_name = azurerm_storage_account.main.name
      storage_account_key = azurerm_storage_account.main.primary_access_key
      share_name          = azurerm_storage_share.db.name
    }
  }
}

# Container Instance: Kafka
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
      KAFKA_ZOOKEEPER_CONNECT  = "localhost:2181"
      KAFKA_ADVERTISED_LISTENERS = "PLAINTEXT://kafka-${var.environment}.${var.location}.azurecontainer.io:9092"
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR = "1"
      KAFKA_NUM_PARTITIONS = "3"
    }
  }
}

# Storage Account for volumes
resource "azurerm_storage_account" "main" {
  name                     = "microservicesdb${var.environment}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Storage Share for PostgreSQL
resource "azurerm_storage_share" "db" {
  name                 = "postgres-share"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 50
}
