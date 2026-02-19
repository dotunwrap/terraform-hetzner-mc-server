variable "hcloud_token" {
  type        = string
  description = "Hetzner Cloud API token"
}

variable "name" {
  type        = string
  description = "The name of the project"
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

variable "server_type" {
  type        = string
  description = "The server type for Hetzner (e.g. cpx21)"
  default     = "cpx21"
}

variable "server_location" {
  type        = string
  description = "The location for the Hetzner server to run in (e.g. ash)"
}

variable "server_swap_size" {
  type        = number
  description = "Size of the swap to enable in GB"
  default     = 4
}

variable "volume_size" {
  type        = number
  description = "Size of persistent volume in GB"
  default     = 50
}

variable "mc_server_type" {
  type        = string
  description = "The type of server to run (e.g. vanilla, forge)"
  default     = "vanilla"

  validation {
    condition     = contains(["vanilla", "forge"], var.mc_server_type)
    error_message = "mc_server_type must be one of: vanilla, forge"
  }
}

variable "mc_version" {
  type        = string
  description = "The version of Minecraft"
}

variable "mc_modloader_version" {
  type        = string
  description = "The version of the Minecraft modloader"
  default     = ""
}

variable "mc_server_memsize" {
  type        = number
  description = "The number of gigabytes of memory to give to the JVM"
  default     = 3
}

variable "mc_mods" {
  type        = list(string)
  description = "List of Minecraft mod archives to install (.jar)"
  default     = []

  validation {
    condition = alltrue([
      for f in var.mc_mods : can(fileexists(f)) && can(regex(".*\\.jar$", f))
    ])
    error_message = "All mods must exist and have a .jar extension"
  }
}

variable "server_properties" {
  type        = map(string)
  description = "A map of key -> value pairs for the Minecraft server.properties file"
  sensitive   = true
  default     = {}

  validation {
    condition = alltrue([
      for k in keys(var.server_properties) :
      contains(
        keys(local.default_server_properties),
        k
      )
    ])
    error_message = "server_properties contains unknown Minecraft settings"
  }
}

variable "whitelist_users" {
  type = list(object({
    name = string
    uuid = string
  }))
  description = "A list of objects containing the name and uuids of users to add to the whitelist.json"
  default     = []
}

variable "op_users" {
  type = list(object({
    uuid                = string
    name                = string
    level               = number
    bypassesPlayerLimit = bool
  }))
  default = []
}
