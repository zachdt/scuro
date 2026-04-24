output "ssh_host" {
  value = hcloud_server.host.ipv4_address
}

output "ssh_user" {
  value = "root"
}

output "rpc_hostname" {
  value = var.rpc_hostname
}

output "public_rpc_url" {
  value = "https://${var.rpc_hostname}"
}

output "server_id" {
  value = hcloud_server.host.id
}

output "server_name" {
  value = hcloud_server.host.name
}

output "origin_certificate_path" {
  value     = local.origin_cert_path
  sensitive = true
}

output "origin_key_path" {
  value     = local.origin_key_path
  sensitive = true
}
