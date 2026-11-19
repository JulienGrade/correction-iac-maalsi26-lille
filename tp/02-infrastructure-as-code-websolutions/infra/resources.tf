resource "docker_network" "websolutions" {
  name = "websolutions-net"
}

resource "docker_volume" "postgres_data" {
  name = "websolutions-db-data"
}

resource "docker_image" "postgres" {
  name         = "postgres:16-alpine"
  keep_locally = true
}

resource "docker_image" "nginx" {
  name         = "nginx:1.28-alpine"
  keep_locally = true
}