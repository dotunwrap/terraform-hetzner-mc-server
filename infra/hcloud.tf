terraform {
  required_version = ">= 1.3.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.56"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_ssh_key" "mc_ci_key" {
  name       = "mc-ci-key"
  public_key = var.public_ssh_key
}

resource "hcloud_server" "mc" {
  name        = "aitai-mc-server"
  server_type = "cpx21"
  image       = "debian-13"
  location    = "ash"
  ssh_keys    = [hcloud_ssh_key.mc_ci_key.id]

  labels = {
    role = "minecraft"
  }
}

resource "hcloud_volume" "mc_vol" {
  name              = "mc-vol"
  size              = var.volume_size
  format            = "ext4"
  server_id         = hcloud_server.mc.id
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
  name = "mc-fw"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "25565"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = var.rcon_port
    source_ips = ["0.0.0.0/0", "::/0"]
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

resource "null_resource" "mc_provisioner" {
  depends_on = [hcloud_server.mc, hcloud_volume_attachment.mc_vol_attach]

  provisioner "remote-exec" {
    connection {
      host        = hcloud_server.mc.ipv4_address
      user        = "root"
      private_key = var.private_ssh_key
      agent       = false
    }

    inline = [
      "apt-get update && apt-get install -y openjdk-21-jre-headless screen",
      "useradd -m -s /bin/bash minecraft || echo 'User already exists'",
      "echo 'minecraft ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/90-minecraft-user",
      "mkdir -p /mnt/minecraft",
      "grep -q '/dev/disk/by-id/scsi-0HC_Volume_${hcloud_volume.mc_vol.id}' /etc/fstab || echo '/dev/disk/by-id/scsi-0HC_Volume_${hcloud_volume.mc_vol.id} /mnt/minecraft ext4 defaults 0 2' >> /etc/fstab",
      "systemctl daemon-reload",
      "mount /mnt/minecraft || true",
    ]
  }

  provisioner "file" {
    source      = "${path.module}/minecraft/start.sh"
    destination = "/mnt/minecraft/start.sh"
    connection {
      host        = hcloud_server.mc.ipv4_address
      user        = "root"
      private_key = var.private_ssh_key
      agent       = false
    }
  }

  provisioner "file" {
    source      = "${path.module}/minecraft/eula.txt"
    destination = "/mnt/minecraft/eula.txt"
    connection {
      host        = hcloud_server.mc.ipv4_address
      user        = "root"
      private_key = var.private_ssh_key
      agent       = false
    }
  }

  provisioner "file" {
    content = templatefile("${path.module}/minecraft/server.properties", {
      rcon_password = var.rcon_password
      rcon_port     = var.rcon_port
    })
    destination = "/mnt/minecraft/server.properties"
    connection {
      host        = hcloud_server.mc.ipv4_address
      user        = "root"
      private_key = var.private_ssh_key
      agent       = false
    }
  }

  provisioner "file" {
    source      = "${path.module}/minecraft/whitelist.json"
    destination = "/mnt/minecraft/whitelist.json"
    connection {
      host        = hcloud_server.mc.ipv4_address
      user        = "root"
      private_key = var.private_ssh_key
      agent       = false
    }
  }

  provisioner "file" {
    source      = "${path.module}/minecraft/ops.json"
    destination = "/mnt/minecraft/ops.json"
    connection {
      host        = hcloud_server.mc.ipv4_address
      user        = "root"
      private_key = var.private_ssh_key
      agent       = false
    }
  }

  provisioner "file" {
    source      = "${path.module}/services/minecraft.service"
    destination = "/etc/systemd/system/minecraft.service"
    connection {
      host        = hcloud_server.mc.ipv4_address
      user        = "root"
      private_key = var.private_ssh_key
      agent       = false
    }
  }

  provisioner "remote-exec" {
    connection {
      host        = hcloud_server.mc.ipv4_address
      user        = "root"
      private_key = var.private_ssh_key
      agent       = false
    }

    inline = [
      "chown -R minecraft:minecraft /mnt/minecraft",
      "chmod +x /mnt/minecraft/start.sh",
      "chmod 644 /etc/systemd/system/minecraft.service",

      "sudo -u minecraft wget -O /mnt/minecraft/server.jar https://mcutils.com/api/server-jars/vanilla/${var.mc_version}/download",

      "systemctl daemon-reload",
      "systemctl enable minecraft",
      "systemctl start minecraft"
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
