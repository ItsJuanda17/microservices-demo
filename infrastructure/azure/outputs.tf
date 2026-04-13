# Infrastructure Pipeline - Production Terraform Execution Ready

output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "Name of the resource group"
}

output "resource_group_id" {
  value       = azurerm_resource_group.main.id
  description = "ID of the resource group"
}

output "postgresql_container_fqdn" {
  value       = azurerm_container_group.postgresql.fqdn
  description = "PostgreSQL container FQDN"
}

output "postgresql_container_ip" {
  value       = azurerm_container_group.postgresql.ip_address
  description = "PostgreSQL container IP address"
}

output "postgresql_port" {
  value       = 5432
  description = "PostgreSQL port"
}

output "kafka_host" {
  value       = azurerm_container_group.kafka.fqdn
  description = "Kafka container FQDN"
}

output "kafka_port" {
  value       = 9092
  description = "Kafka port"
}

output "vote_service_url" {
  value       = "http://${azurerm_container_group.vote.fqdn}:8080"
  description = "Vote service public URL"
}

output "result_service_url" {
  value       = "http://${azurerm_container_group.result.fqdn}"
  description = "Result service public URL"
}

output "vote_service_ip" {
  value       = azurerm_container_group.vote.ip_address
  description = "Vote service IP address"
}

output "worker_service_ip" {
  value       = azurerm_container_group.worker.ip_address
  description = "Worker service IP address"
}

output "result_service_ip" {
  value       = azurerm_container_group.result.ip_address
  description = "Result service IP address"
}

output "kafka_ip" {
  value       = azurerm_container_group.kafka.ip_address
  description = "Kafka container IP address"
}
