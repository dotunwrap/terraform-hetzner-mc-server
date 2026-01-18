# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Terraform module for provisioning and deploying Minecraft servers on Hetzner Cloud. The module handles infrastructure provisioning, server configuration, and automatic deployment of Minecraft server software (vanilla, fabric, or forge).

## Development Setup

This project uses Nix flakes for development environment management.

```bash
# Enter development shell (provides terraform, terraform-ls, terraform-docs)
nix develop

# Or use direnv
direnv allow
```

## Common Commands

### Formatting

```bash
# Format both Nix and Terraform code
just fmt

# Or separately:
nix fmt
cd module && terraform fmt
```

### Terraform Operations

All Terraform operations should be run from the `module/` directory:

```bash
# Update provider lock file for all platforms
just tflock
```

### Testing

```bash
# Run all Nix checks (formatting and validation)
nix flake check --keep-going
```

The flake defines two checks in `flake/checks.nix`:
- `nixfmt`: Validates Nix code formatting
- `terraformfmt`: Validates Terraform code formatting in `module/`

## Architecture

### Module Structure

The Terraform module is located in the `module/` directory and provisions:

1. **Hetzner Cloud Server** (`hcloud_server.mc`): Debian 13 server running Minecraft
2. **Persistent Volume** (`hcloud_volume.mc_vol`): EXT4 volume mounted at `/mnt/minecraft` with delete protection and lifecycle prevent_destroy
3. **SSH Key** (`hcloud_ssh_key.mc_ci_key`): For server access
4. **Firewall** (`hcloud_firewall.mc_fw`): Opens ports for Minecraft (default 25565), RCON (default 25575), and SSH (22)
5. **Provisioner** (`null_resource.mc_provisioner`): Handles server configuration and Minecraft installation

### Provisioning Flow

The `null_resource.mc_provisioner` in `module/main.tf:158-299` orchestrates the deployment using `remote-exec` and `file` provisioners:

1. Installs Java 21, creates `minecraft` user, mounts persistent volume
2. Uploads configuration files: `start.sh`, `eula.txt`, `server.properties`, `whitelist.json`, `ops.json`
3. Uploads systemd service file to `/etc/systemd/system/minecraft.service`
4. If mods are specified (`var.mc_mods`), uploads them to `/mnt/minecraft/mods/` as base64-encoded files
5. Downloads Minecraft server JAR from `mcutils.com` API based on `mc_server_type` and `mc_version`
6. Starts Minecraft as a systemd service

### Re-provisioning Triggers

The provisioner uses triggers (`module/main.tf:161-172`) to force re-provisioning when:
- Server ID changes
- Configuration files change (`start.sh`, `eula.txt`, `server.properties`, `whitelist.json`, `ops.json`, `minecraft.service`)
- Server type or version changes
- Mods list changes

### Server Properties Management

Server properties are managed via a merge strategy (`module/main.tf:76-82`):
- Default properties defined in `local.default_server_properties` (lines 17-75)
- User overrides via `var.server_properties` map
- Merged result written to `server.properties` file
- The `var.server_properties` variable validates that only known properties are used (lines 75-84)

### User Management

Two types of users can be configured:
- `var.whitelist_users`: List of `{name, uuid}` objects for whitelist.json
- `var.op_users`: List of `{uuid, name, level, bypassesPlayerLimit}` objects for ops.json

### Systemd Service

The Minecraft server runs as a systemd service (`module/services/minecraft.service`):
- Runs as `minecraft` user
- Working directory: `/mnt/minecraft`
- Executes `start.sh` which runs Java with 2GB min / 3GB max heap
- Auto-restarts on failure
- 60-second timeout on stop

### CI/CD

The `.github/workflows/ci.yml` runs on PRs and pushes to main:
- Executes `nix flake check` on macOS and Ubuntu
- On PRs: runs `terraform init` and `terraform validate`, posts results as PR comment

Note: The git status shows deleted files in `infra/` directory - the Terraform code has been refactored into the `module/` directory structure.

## Module Variables

Key variables defined in `module/vars.tf`:
- `hcloud_token`: Hetzner Cloud API token (required)
- `name`: Project name prefix for resources (required)
- `public_ssh_key` / `private_ssh_key`: SSH keys for server access (required)
- `server_type`: Hetzner server type (default: "cpx21")
- `server_location`: Hetzner datacenter location (required, e.g., "ash")
- `volume_size`: Persistent volume size in GB (default: 50)
- `mc_server_type`: Server software type - "vanilla", "fabric", or "forge" (default: "vanilla")
- `mc_version`: Minecraft version (default: "1.21.10")
- `mc_mods`: List of .zip mod files to install (default: [])
- `server_properties`: Map of Minecraft server.properties overrides (default: {})

## Module Outputs

Defined in `module/outputs.tf`:
- `server_ip`: Public IPv4 address of the Minecraft server
- `volume_id`: ID of the persistent volume
