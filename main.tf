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

# resource "digitalocean_droplet" "test-server" {
#   name   = "test-server"
#   size   = var.small_server_size
#   image  = var.image
#   region = var.region_europe
#   user_data = templatefile("${path.module}/telemetry-vps.sh.tpl", {
#     user_name     = var.user_name
#     user_password = var.user_password
#     ssh_key       = var.ssh_key
#     ssh_port      = var.ssh_port
#
#     base     = file("${path.module}/scripts/base.sh")
#     fail2ban = file("${path.module}/scripts/fail2ban.sh"),
#
#     node_exporter = file("${path.module}/scripts/node_exporter.sh"),
#     tempo         = file("${path.module}/scripts/tempo.sh"),
#     loki          = file("${path.module}/scripts/loki.sh"),
#     prometheus    = file("${path.module}/scripts/prometheus.sh"),
#     alloy         = file("${path.module}/scripts/alloy.sh"),
#
#     caddy = file("${path.module}/scripts/caddy.sh"),
#   })
# }
#
# output "test_server_ip" {
#   description = "IP address of the created server"
#   value       = digitalocean_droplet.test-server.ipv4_address
# }

resource "digitalocean_droplet" "app-test-server" {
  name   = "app-test-server"
  size   = var.small_server_size
  image  = var.image
  region = var.region_europe
  # ssh_keys = [var.ssh_key]
  user_data = templatefile("${path.module}/app-vps.sh.tpl", {
    user_name     = var.user_name
    user_password = var.user_password
    ssh_key       = var.ssh_key
    ssh_port      = var.ssh_port

    base     = file("${path.module}/scripts/base.sh")
    fail2ban = file("${path.module}/scripts/fail2ban.sh"),

    docker = file("${path.module}/scripts/docker.sh"),

    node_exporter = file("${path.module}/scripts/node_exporter.sh"),
    traefik       = file("${path.module}/scripts/traefik.sh"),

    manager_domain     = var.manager_domain
    manager_password   = var.manager_password
    cloudflare_email   = var.cloudflare_email
    cloudflare_api_key = var.cloudflare_api_key
  })

  # provisioner "file" {
  #   source      = "${path.module}/bin/manager"
  #   destination = "/home/${var.user_name}/manager"
  #
  #   connection {
  #     host     = self.ipv4_address
  #     user     = var.user_name
  #     password = var.user_password
  #     port     = var.ssh_port
  #   }
  # }
  #
  # provisioner "remote-exec" {
  #   inline = [
  #     "sudo mv /home/${var.user_name}/manager /usr/local/bin/manager",
  #     "sudo chmod +x /usr/local/bin/manager",
  #     "sudo chown ${var.user_name}:${var.user_name} /usr/local/bin/manager"
  #   ]
  #
  #   connection {
  #     host     = self.ipv4_address
  #     user     = var.user_name
  #     password = var.user_password
  #     port     = var.ssh_port
  #   }
  # }
}

output "app_test_server_ip" {
  description = "IP address of the created server"
  value       = digitalocean_droplet.app-test-server.ipv4_address
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
