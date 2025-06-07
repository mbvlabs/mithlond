terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    # hcloud = {
    #   source  = "hetznercloud/hcloud"
    #   version = "~> 1.0"
    # }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# provider "hcloud" {
#   token = var.hcloud_token
# }

#  resource "digitalocean_droplet" "app-server" {
#   name     = "app-server"
#   size     = var.dedicated_server_size
#   image    = var.image
#   region   = var.region_europe
#   user_data = templatefile("${path.module}/app-vps.sh.tpl", {
#     base     = file("${path.module}/scripts/base.sh"),
#     docker   = file("${path.module}/scripts/docker.sh"),
#     fail2ban = file("${path.module}/scripts/fail2ban.sh"),
#   })
# }
#
# output "app_server_ip" {
#   description = "IP address of the created server"
#   value       = digitalocean_droplet.app-server.ipv4_address
# }

resource "digitalocean_droplet" "test-server" {
  name   = "test-server"
  size   = var.small_server_size
  image  = var.image
  region = var.region_europe
  user_data = templatefile("${path.module}/telemetry-vps.sh.tpl", {
    user_name     = var.user_name
    user_password = var.user_password
    ssh_key       = var.ssh_key
    ssh_port      = var.ssh_port

    base     = file("${path.module}/scripts/base.sh")
    fail2ban = file("${path.module}/scripts/fail2ban.sh"),

    node_exporter = file("${path.module}/scripts/node_exporter.sh"),
    tempo         = file("${path.module}/scripts/tempo.sh"),
    loki          = file("${path.module}/scripts/loki.sh"),
    prometheus    = file("${path.module}/scripts/prometheus.sh"),
    alloy         = file("${path.module}/scripts/alloy.sh"),
  })
}

output "test_server_ip" {
  description = "IP address of the created server"
  value       = digitalocean_droplet.test-server.ipv4_address
}

# Hetzner Cloud Resources (commented out)
# resource "hcloud_server" "app-server" {
#   name        = "app-server"
#   server_type = var.dedicated_server_type
#   image       = var.image
#   location    = var.location_europe
#   user_data = templatefile("${path.module}/app-vps.sh.tpl", {
#     base     = file("${path.module}/scripts/base.sh"),
#     docker   = file("${path.module}/scripts/docker.sh"),
#     fail2ban = file("${path.module}/scripts/fail2ban.sh"),
#   })
# }
#
# resource "hcloud_server" "test-server" {
#   name        = "test-server"
#   server_type = var.small_server_type
#   image       = var.image
#   location    = var.location_europe
#   user_data = templatefile("${path.module}/telemetry-vps.sh.tpl", {
#     base = file("${path.module}/scripts/base.sh")
#   })
# }
#
# output "app_server_ip_hetzner" {
#   description = "IP address of the created server"
#   value       = hcloud_server.app-server.ipv4_address
# }
#
# output "test_server_ip_hetzner" {
#   description = "IP address of the created server"
#   value       = hcloud_server.test-server.ipv4_address
# }
