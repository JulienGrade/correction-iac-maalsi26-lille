resource "docker_container" "web" {
  name  = "websolutions-web"
  image = docker_image.nginx.image_id

  networks_advanced {
    name    = docker_network.websolutions.name
    aliases = ["web"]
  }

  volumes {
    host_path      = var.nginx_config_dir
    container_path = "/etc/nginx/conf.d"
    read_only      = true
  }

  ports {
    internal = 80
    external = var.web_port
    ip       = var.web_bind_ip
  }

  depends_on = [docker_container.api]
}