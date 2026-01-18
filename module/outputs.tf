output "server_ip" {
  description = "Public IP address of the Minecraft server"
  value       = hcloud_server.mc.ipv4_address
}

output "volume_id" {
  description = "ID of the persistent volume"
  value       = hcloud_volume.mc_vol.id
}
