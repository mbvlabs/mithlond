variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "small_server_size" {
  description = "DigitalOcean droplet size (e.g., s-1vcpu-1gb, s-2vcpu-2gb)"
  type        = string
  default     = "s-1vcpu-1gb"
}

variable "dedicated_server_size" {
  description = "DigitalOcean droplet size (e.g., s-2vcpu-4gb, s-4vcpu-8gb)"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "image" {
  description = "Operating system image (e.g., ubuntu-22-04-x64, ubuntu-24-04-x64)"
  type        = string
  default     = "ubuntu-22-04-x64"
}

variable "region_europe" {
  description = "DigitalOcean region (e.g., fra1, ams3, lon1)"
  type        = string
  default     = "fra1"
}

variable "region_usa" {
  description = "DigitalOcean region (e.g., nyc1, nyc3, sfo3)"
  type        = string
  default     = "nyc1"
}

variable "user_name" {
  description = "Username for the VPS"
  type        = string
}

variable "ssh_port" {
  description = "SSH port for the VPS"
  type        = number
}

variable "ssh_key" {
  description = "SSH public key for admin access"
  type        = string
  sensitive   = true
}

variable "user_password" {
  description = "Password for the user"
  type        = string
  sensitive   = true
}

variable "caddy_username" {
  description = "Used for authenticating request to telemetry"
  type        = string
}

variable "caddy_password" {
  description = "Used for authenticating request to telemetry"
  type        = string
}

variable "domain" {
  description = "Used for reverse proxy in caddy"
  type        = string
}

# Hetzner Cloud Variables (commented out)
# variable "hcloud_token" {
#   description = "Hetzner Cloud API token"
#   type        = string
#   sensitive   = true
# }
#
# variable "small_server_type" {
#   description = "Hetzner Cloud server type (e.g., cx11, cpx11, cx21)"
#   type        = string
#   default     = "cx11"
# }
#
# variable "dedicated_server_type" {
#   description = "Hetzner Cloud server type (e.g., cx21, cpx21, cx31)"
#   type        = string
#   default     = "cx21"
# }
#
# variable "location_europe" {
#   description = "Hetzner Cloud location (e.g., nbg1, fsn1, hel1)"
#   type        = string
#   default     = "nbg1"
# }
#
# variable "location_usa" {
#   description = "Hetzner Cloud location (e.g., ash)"
#   type        = string
#   default     = "ash"
# }

