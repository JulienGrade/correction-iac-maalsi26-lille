variable "docker_context" {
  description = "Contexte Docker pointant vers la VM de test"
  type        = string
  default     = "websolutions-vm"
}

variable "api_image_id" {
  description = "Identifiant complet de l'image API construite dans la VM"
  type        = string
}

variable "app_version" {
  description = "Version affichée par l'API"
  type        = string
  default     = "1.0.0"
}

variable "db_name" {
  type    = string
  default = "websolutions"
}

variable "db_user" {
  type    = string
  default = "websolutions"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "web_bind_ip" {
  description = "Adresse privée de la VM sur laquelle exposer Nginx"
  type        = string
  default     = "192.168.56.20"
}

variable "web_port" {
  type    = number
  default = 8081
}

variable "nginx_config_dir" {
  description = "Dossier de configuration Nginx sur la VM"
  type        = string
  default     = "/home/julien/websolutions/nginx-conf"
}