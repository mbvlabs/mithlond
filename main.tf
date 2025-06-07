terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.36.0" # Use a recent version
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "small_server_type" {
  description = "Hetzner Cloud server type (e.g., cx11, cx21)"
  type        = string
  default     = "cpx11"
}

variable "dedicated_server_type" {
  description = "Hetzner Cloud server type (e.g., cx11, cx21)"
  type        = string
  default     = "ccx13"
}

variable "image" {
  description = "Operating system image (e.g., ubuntu-22.04, debian-12)"
  type        = string
  default     = "ubuntu-24.04"
}

variable "loc_germany_fsn1" {
  description = "Hetzner Cloud location (e.g., fsn1, nbg1)"
  type        = string
  default     = "fsn1"
}

variable "loc_usa_ash" {
  description = "Hetzner Cloud location (e.g., fsn1, nbg1)"
  type        = string
  default     = "ash"
}

variable "user_name" {
  description = "Username for the VPS"
  type        = string
  default     = "admin"
}

variable "ssh_port" {
  description = "SSH port for the VPS"
  type        = number
}

variable "admin_ssh_key" {
  description = "SSH public key for admin access"
  type        = string
  sensitive   = true
}

variable "user_password" {
  description = "Password for the user"
  type        = string
  sensitive   = true
}

#  resource "hcloud_server" "app-server" {
#   name         = "app-server"
#   server_type  = var.dedicated_server_type
#   image        = var.image
#   location     = var.loc_germany_fsn1
#   user_data    = templatefile("${path.module}/app-vps.sh.tpl", {
#     base   = file("${path.module}/scripts/base.sh"),
#     docker        = file("${path.module}/scripts/docker.sh"),
#     fail2ban      = file("${path.module}/scripts/fail2ban.sh"),
#   })
# }
#
# output "app_server_ip" {
#   description = "IP address of the created server"
#   value       = hcloud_server.app-server.ipv4_address
# }

resource "hcloud_server" "test-telemetry-server" {
  name        = "test-telemetry-server"
  server_type = var.small_server_type
  image       = var.image
  location    = var.loc_germany_fsn1
  user_data = templatefile("${path.module}/telemetry-vps.sh.tpl", {
    user_name     = var.user_name
    ssh_port      = var.ssh_port
    admin_ssh_key = var.admin_ssh_key
    user_password = var.user_password
    base          = file("${path.module}/scripts/base.sh")
    fail2ban      = file("${path.module}/scripts/fail2ban.sh")
    node_exporter = file("${path.module}/scripts/node_exporter.sh")
    prometheus    = file("${path.module}/scripts/prometheus.sh")
    loki          = file("${path.module}/scripts/loki.sh")
    tempo         = file("${path.module}/scripts/tempo.sh")
    alloy         = file("${path.module}/scripts/alloy.sh")
  })
}

output "telemetry_server_ip" {
  description = "IP address of the created server"
  value       = hcloud_server.test-telemetry-server.ipv4_address
}
