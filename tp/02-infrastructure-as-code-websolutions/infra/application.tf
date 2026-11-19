resource "docker_container" "api" {
  name  = "websolutions-api"
  image = var.api_image_id

  env = [
    "APP_VERSION=${var.app_version}",
    "DB_HOST=db",
    "DB_NAME=${var.db_name}",
    "DB_USER=${var.db_user}",
    "DB_PASSWORD=${var.db_password}"
  ]

  networks_advanced {
    name    = docker_network.websolutions.name
    aliases = ["api"]
  }

  depends_on = [docker_container.postgres]
}