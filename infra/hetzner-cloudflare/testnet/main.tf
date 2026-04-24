provider "hcloud" {}

provider "cloudflare" {}

locals {
  common_labels = merge(var.tags, {
    project = "scuro"
    stack   = var.name
  })

  origin_dir       = "${path.module}/.origin"
  origin_cert_path = "${local.origin_dir}/scuro-origin.pem"
  origin_key_path  = "${local.origin_dir}/scuro-origin.key"
}

resource "tls_private_key" "origin" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "origin" {
  private_key_pem = tls_private_key.origin.private_key_pem

  subject {
    common_name  = var.rpc_hostname
    organization = "Scuro"
  }

  dns_names = [var.rpc_hostname]
}

resource "cloudflare_origin_ca_certificate" "origin" {
  csr                = tls_cert_request.origin.cert_request_pem
  hostnames          = [var.rpc_hostname]
  request_type       = "origin-ecc"
  requested_validity = 5475
}

resource "local_sensitive_file" "origin_certificate" {
  filename        = local.origin_cert_path
  content         = cloudflare_origin_ca_certificate.origin.certificate
  file_permission = "0600"
}

resource "local_sensitive_file" "origin_key" {
  filename        = local.origin_key_path
  content         = tls_private_key.origin.private_key_pem
  file_permission = "0600"
}

resource "hcloud_ssh_key" "admin" {
  name       = "${var.name}-admin"
  public_key = file(pathexpand(var.ssh_public_key_path))
  labels     = local.common_labels
}

resource "hcloud_firewall" "host" {
  name   = "${var.name}-host"
  labels = local.common_labels

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = var.ssh_admin_cidrs
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = var.http_source_cidrs
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = var.http_source_cidrs
  }
}

resource "hcloud_server" "host" {
  name        = var.name
  image       = "ubuntu-24.04"
  server_type = var.server_type
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.admin.id]
  backups     = false
  labels      = local.common_labels
  firewall_ids = [
    hcloud_firewall.host.id
  ]

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  user_data = templatefile("${path.module}/user_data.yml.tftpl", {
    name                   = var.name
    rpc_hostname           = var.rpc_hostname
    public_rpc_url         = "https://${var.rpc_hostname}"
    root_volume_size_gib   = 40
    hetzner_server_name    = var.name
    cloudflare_origin_cert = local.origin_cert_path
    cloudflare_origin_key  = local.origin_key_path
  })

  depends_on = [
    local_sensitive_file.origin_certificate,
    local_sensitive_file.origin_key
  ]
}

resource "cloudflare_dns_record" "rpc" {
  zone_id = var.cloudflare_zone_id
  name    = var.rpc_hostname
  type    = "A"
  content = hcloud_server.host.ipv4_address
  proxied = true
  ttl     = 1
  comment = "Scuro canonical testnet RPC"
}

resource "cloudflare_zone_setting" "ssl" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "ssl"
  value      = "strict"
}

resource "cloudflare_zone_setting" "tls_1_3" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "tls_1_3"
  value      = "on"
}

resource "cloudflare_zone_setting" "automatic_https_rewrites" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "automatic_https_rewrites"
  value      = "on"
}
