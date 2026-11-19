output "web_url" {
  description = "Point d'accès au serveur web depuis le Mac"
  value       = "http://${var.web_bind_ip}:${var.web_port}"
}

output "health_url" {
  description = "Route de santé à vérifier après la livraison"
  value       = "http://${var.web_bind_ip}:${var.web_port}/health"
}

output "deployed_version" {
  description = "Version annoncée par l'application"
  value       = var.app_version
}

output "postgres_volume" {
  description = "Volume contenant les données PostgreSQL"
  value       = docker_volume.postgres_data.name
}