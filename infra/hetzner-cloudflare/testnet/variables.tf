variable "name" {
  description = "Base name for the canonical Scuro testnet."
  type        = string
  default     = "scuro-testnet"
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone id that owns rpc_hostname."
  type        = string
}

variable "rpc_hostname" {
  description = "Fully qualified Cloudflare-proxied public RPC hostname."
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key authorized on the Hetzner host."
  type        = string
}

variable "ssh_admin_cidrs" {
  description = "CIDR blocks allowed to connect to SSH."
  type        = list(string)
}

variable "location" {
  description = "Hetzner Cloud location."
  type        = string
  default     = "fsn1"
}

variable "server_type" {
  description = "Hetzner Cloud server type."
  type        = string
  default     = "cx23"
}

variable "http_source_cidrs" {
  description = "CIDR blocks allowed to connect to HTTP/HTTPS on the origin. Keep broad only when the Cloudflare DNS record is proxied."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Extra labels for Hetzner resources."
  type        = map(string)
  default     = {}
}
