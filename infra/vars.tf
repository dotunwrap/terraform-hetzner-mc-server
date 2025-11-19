variable "hcloud_token" {
  type        = string
  description = "Hetzner Cloud API token"
}

variable "public_ssh_key" {
  type        = string
  description = "SSH public key"
}

variable "private_ssh_key" {
  type        = string
  description = "SSH private key"
  sensitive   = true
}

variable "volume_size" {
  type        = number
  description = "Size of persistent volume in GB"
  default     = 50
}

variable "mc_version" {
  type        = string
  description = "The version of Minecraft"
  default     = "1.21.10"
}

variable "rcon_password" {
  type        = string
  description = "Password for RCON"
  sensitive   = true
}

variable "rcon_port" {
  type        = string
  description = "The port for RCON"
  sensitive   = true
}
