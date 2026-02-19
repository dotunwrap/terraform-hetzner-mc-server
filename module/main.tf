terraform {
  required_version = ">= 1.3.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.56"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

locals {
  default_server_properties = {
    "enable-jmx-monitoring"             = "false"
    "rcon.port"                         = "25575"
    "level-seed"                        = ""
    "gamemode"                          = "survival"
    "enable-command-block"              = "false"
    "enable-query"                      = "false"
    "generator-settings"                = "{}"
    "enforce-secure-profile"            = "true"
    "level-name"                        = "world"
    "motd"                              = "A Minecraft Server"
    "query.port"                        = "25565"
    "pvp"                               = "true"
    "generate-structures"               = "true"
    "max-chained-neighbor-updates"      = "1000000"
    "difficulty"                        = "easy"
    "network-compression-threshold"     = "256"
    "max-tick-time"                     = "60000"
    "require-resource-pack"             = "false"
    "use-native-transport"              = "true"
    "max-players"                       = "20"
    "online-mode"                       = "true"
    "enable-status"                     = "true"
    "allow-flight"                      = "false"
    "initial-disabled-packs"            = ""
    "broadcast-rcon-to-ops"             = "true"
    "view-distance"                     = "10"
    "server-ip"                         = ""
    "resource-pack-prompt"              = ""
    "allow-nether"                      = "true"
    "server-port"                       = "25565"
    "enable-rcon"                       = "false"
    "sync-chunk-writes"                 = "true"
    "op-permission-level"               = "4"
    "prevent-proxy-connections"         = "false"
    "hide-online-players"               = "false"
    "resource-pack"                     = ""
    "entity-broadcast-range-percentage" = "100"
    "simulation-distance"               = "10"
    "rcon.password"                     = ""
    "player-idle-timeout"               = "0"
    "force-gamemode"                    = "false"
    "rate-limit"                        = "0"
    "hardcore"                          = "false"
    "white-list"                        = "false"
    "broadcast-console-to-ops"          = "true"
    "spawn-npcs"                        = "true"
    "spawn-animals"                     = "true"
    "log-ips"                           = "true"
    "function-permission-level"         = "2"
    "initial-enabled-packs"             = "vanilla"
    "level-type"                        = "minecraft\\:normal"
    "text-filtering-config"             = ""
    "spawn-monsters"                    = "true"
    "enforce-whitelist"                 = "false"
    "spawn-protection"                  = "16"
    "resource-pack-sha1"                = ""
    "max-world-size"                    = "29999984"
  }
  effective_server_properties = merge(
    local.default_server_properties,
    var.server_properties
  )
  server_properties_content = join("\n", [
    for k in sort(keys(local.effective_server_properties)) :
    "${k}=${local.effective_server_properties[k]}"
  ])
  whitelist_json_content = jsonencode(var.whitelist_users)
  ops_json_content       = jsonencode(var.op_users)
}

resource "hcloud_ssh_key" "mc_ci_key" {
  name       = "${var.name}-ci-key"
  public_key = var.public_ssh_key
}

resource "hcloud_server" "mc" {
  name        = "${var.name}-mc-server"
  server_type = var.server_type
  image       = "debian-13"
  location    = var.server_location
  ssh_keys    = [hcloud_ssh_key.mc_ci_key.id]

  labels = {
    role = "minecraft"
  }
}

resource "hcloud_volume" "mc_vol" {
  name              = "${var.name}-vol"
  size              = var.volume_size
  format            = "ext4"
  location          = var.server_location
  delete_protection = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "hcloud_volume_attachment" "mc_vol_attach" {
  volume_id = hcloud_volume.mc_vol.id
  server_id = hcloud_server.mc.id
  automount = false
}

resource "hcloud_firewall" "mc_fw" {
  name = "${var.name}-fw"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = local.effective_server_properties["server-port"]
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  dynamic "rule" {
    for_each = local.effective_server_properties["enable-rcon"] == "true" ? [1] : []
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = local.effective_server_properties["rcon.port"]
      source_ips = ["0.0.0.0/0", "::/0"]
    }
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  apply_to {
    label_selector = "role=minecraft"
  }
}

resource "null_resource" "mc_init_provisioner" {
  depends_on = [hcloud_server.mc, hcloud_volume_attachment.mc_vol_attach]

  triggers = {
    server_id = hcloud_server.mc.id
    vol_id    = hcloud_volume.mc_vol.id
  }

  connection {
    host        = hcloud_server.mc.ipv4_address
    user        = "root"
    private_key = var.private_ssh_key
    agent       = false
  }

  provisioner "remote-exec" {
    inline = [
      "timeout 300 bash -c 'until cloud-init status --wait 2>/dev/null; do sleep 5; done' || echo 'cloud-init wait skipped'",
      "apt-get update && apt-get install -y openjdk-21-jre-headless screen unzip",
      "useradd -m -s /bin/bash minecraft || echo 'User already exists'",
      "mkdir -p /mnt/minecraft",
      "grep -q '/dev/disk/by-id/scsi-0HC_Volume_${hcloud_volume.mc_vol.id}' /etc/fstab || echo '/dev/disk/by-id/scsi-0HC_Volume_${hcloud_volume.mc_vol.id} /mnt/minecraft ext4 defaults 0 2' >> /etc/fstab",
      "systemctl daemon-reload",
      "mount /mnt/minecraft || true",
      "systemctl stop minecraft || echo 'Service not running'",
    ]
  }
}

resource "null_resource" "mc_jar_provisioner" {
  depends_on = [null_resource.mc_init_provisioner]

  triggers = {
    server_id            = hcloud_server.mc.id
    vol_id               = hcloud_volume.mc_vol.id
    mc_server_type       = var.mc_server_type
    mc_version           = var.mc_version
    mc_modloader_version = var.mc_modloader_version
  }

  connection {
    host        = hcloud_server.mc.ipv4_address
    user        = "root"
    private_key = var.private_ssh_key
    agent       = false
  }

  provisioner "remote-exec" {
    inline = flatten([
      [
        "chown -R minecraft:minecraft /mnt/minecraft",
      ],
      var.mc_server_type != "vanilla"
      ? [
        "sudo -u minecraft wget -O /mnt/minecraft/server.jar.zip https://files.mcjars.app/${var.mc_server_type}/${var.mc_version}/${var.mc_modloader_version}/1/server.jar.zip ||  exit 1",
        "unzip /mnt/minecraft/server.jar.zip -d /mnt/minecraft && rm /mnt/minecraft/server.jar.zip"
      ]
      : ["sudo -u minecraft wget -O /mnt/minecraft/server.jar https://mcutils.com/api/server-jars/vanilla/${var.mc_version}/download || exit 1"],
      # var.mc_server_type == "forge" ? ["cd /mnt/minecraft && sudo -u minecraft java -jar forge-installer.jar --installServer && rm -f forge-installer.jar"] : [],
    ])
  }
}

resource "null_resource" "mc_file_provisioner" {
  depends_on = [null_resource.mc_jar_provisioner]

  triggers = {
    server_id         = hcloud_server.mc.id
    vol_id            = hcloud_volume.mc_vol.id
    start_sh          = filemd5("${path.module}/minecraft/start.sh")
    eula              = filemd5("${path.module}/minecraft/eula.txt")
    server_properties = md5(local.server_properties_content)
    whitelist         = md5(local.whitelist_json_content)
    ops               = md5(local.ops_json_content)
    minecraft_service = filemd5("${path.module}/services/minecraft.service")
  }

  connection {
    host        = hcloud_server.mc.ipv4_address
    user        = "root"
    private_key = var.private_ssh_key
    agent       = false
  }

  provisioner "file" {
    source      = "${path.module}/minecraft/start.sh"
    destination = "/mnt/minecraft/start.sh"
  }

  provisioner "file" {
    source      = "${path.module}/minecraft/eula.txt"
    destination = "/mnt/minecraft/eula.txt"
  }

  provisioner "file" {
    content     = local.server_properties_content
    destination = "/mnt/minecraft/server.properties"
  }

  provisioner "file" {
    content     = local.whitelist_json_content
    destination = "/mnt/minecraft/whitelist.json"
  }

  provisioner "file" {
    content     = local.ops_json_content
    destination = "/mnt/minecraft/ops.json"
  }

  provisioner "file" {
    source      = "${path.module}/services/minecraft.service"
    destination = "/etc/systemd/system/minecraft.service"
  }
}

resource "null_resource" "mc_mod_provisioner" {
  depends_on = [null_resource.mc_file_provisioner]

  for_each = toset(var.mc_mods)

  triggers = {
    server_id = hcloud_server.mc.id
    vol_id    = hcloud_volume.mc_vol.id
    mods      = md5(join("", [for m in var.mc_mods : filemd5(m)]))
  }

  connection {
    host        = hcloud_server.mc.ipv4_address
    user        = "root"
    private_key = var.private_ssh_key
    agent       = false
  }

  provisioner "file" {
    source      = each.value
    destination = "/mnt/minecraft/mods/${basename(each.value)}"
  }
}


resource "null_resource" "mc_start_provisioner" {
  depends_on = [null_resource.mc_mod_provisioner]

  triggers = {
    server_id         = hcloud_server.mc.id
    vol_id            = hcloud_volume.mc_vol.id
    start_sh          = filemd5("${path.module}/minecraft/start.sh")
    eula              = filemd5("${path.module}/minecraft/eula.txt")
    server_properties = md5(local.server_properties_content)
    whitelist         = md5(local.whitelist_json_content)
    ops               = md5(local.ops_json_content)
    minecraft_service = filemd5("${path.module}/services/minecraft.service")
    mods              = md5(join("", [for m in var.mc_mods : filemd5(m)]))
    mc_server_type    = var.mc_server_type
    mc_version        = var.mc_version
  }

  connection {
    host        = hcloud_server.mc.ipv4_address
    user        = "root"
    private_key = var.private_ssh_key
    agent       = false
  }

  provisioner "remote-exec" {
    inline = [
      "chown -R minecraft:minecraft /mnt/minecraft",
      "chmod +x /mnt/minecraft/start.sh",
      "chmod 644 /etc/systemd/system/minecraft.service",
      "systemctl daemon-reload",
      "systemctl enable minecraft",
      "systemctl restart minecraft",
      "sleep 10",
      "systemctl is-active minecraft || (journalctl --no-pager -u minecraft -n 50 && exit 1)"
    ]
  }
}
output "server_ip" {
  description = "Public IP address of the Minecraft server"
  value       = hcloud_server.mc.ipv4_address
}

output "volume_id" {
  description = "ID of the persistent volume"
  value       = hcloud_volume.mc_vol.id
}
