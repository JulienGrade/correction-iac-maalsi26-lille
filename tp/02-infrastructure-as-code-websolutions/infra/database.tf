resource "docker_container" "postgres" {
  name  = "websolutions-db"
  image = docker_image.postgres.image_id

  env = [
    "POSTGRES_DB=${var.db_name}",
    "POSTGRES_USER=${var.db_user}",
    "POSTGRES_PASSWORD=${var.db_password}"
  ]

  networks_advanced {
    name    = docker_network.websolutions.name
    aliases = ["db"]
  }

  volumes {
    volume_name    = docker_volume.postgres_data.name
    container_path = "/var/lib/postgresql/data"
  }

  healthcheck {
    test     = ["CMD-SHELL", "pg_isready -U ${var.db_user} -d ${var.db_name}"]
    interval = "5s"
    timeout  = "3s"
    retries  = 10
  }

  wait         = true
  wait_timeout = 90
}