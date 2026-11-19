terraform {
  required_version = ">= 1.11.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.9.0"
    }
  }
}