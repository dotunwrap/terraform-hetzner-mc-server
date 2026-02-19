# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Terraform module for provisioning and deploying Minecraft servers on Hetzner Cloud. The module creates a Debian-based server with a persistent volume, installs Java and dependencies, downloads the Minecraft server JAR, and configures it as a systemd service.

## Development Commands

### Formatting

```bash
just fmt            # Format both Nix and Terraform code
nix fmt             # Format Nix code only
terraform fmt       # Format Terraform code only (run from module/)
```

### Validation and Checks

```bash
nix flake check                     # Run all Nix checks (nixfmt + terraformfmt)
cd module && terraform init         # Initialize Terraform
cd module && terraform validate     # Validate Terraform configuration
```

### Terraform Provider Locks

```bash
just tflock         # Lock providers for multiple platforms (windows, darwin, linux on amd64/arm64)
```

### Development Environment

```bash
nix develop         # Enter development shell with terraform, terraform-ls, terraform-docs, gh, just
```

## Architecture

### Provisioning Pipeline

The module uses a multi-stage provisioning pipeline with `null_resource` resources that depend on each other:

1. **mc_init_provisioner**: Initializes the server after creation
   - Waits for cloud-init to complete
   - Installs Java 21, screen, unzip
   - Creates minecraft user
   - Mounts the persistent volume at `/mnt/minecraft`
   - Stops any existing minecraft service

2. **mc_jar_provisioner**: Downloads the Minecraft server JAR
   - Triggers on changes to: server type, version, or modloader version
   - For vanilla: downloads from mcutils.com API
   - For modded (forge): downloads from mcjars.app as a zip, then unzips

3. **mc_file_provisioner**: Provisions configuration files
   - Uploads: start.sh, eula.txt, server.properties, whitelist.json, ops.json
   - Installs minecraft.service systemd unit
   - Triggers on content changes to any of these files

4. **mc_mod_cleanup_provisioner**: Cleans up old mod files
   - Removes all files from `/mnt/minecraft/mods/` before uploading new ones
   - Triggers on changes to the hash of all mod files
   - Ensures clean state when mods are added/removed/updated

5. **mc_mod_provisioner**: Uploads mod files (if any)
   - Uses `for_each` to provision each mod file in `var.mc_mods`
   - Uploads to `/mnt/minecraft/mods/`
   - Only runs if mods are specified

6. **mc_start_provisioner**: Starts the Minecraft service
   - Sets ownership and permissions
   - Enables and restarts minecraft.service
   - Verifies service is active or exits with journal logs

### Server Configuration

The module merges user-provided `server_properties` with comprehensive defaults defined in `local.default_server_properties` (module/main.tf:21-79). The validation in module/vars.tf:80-89 ensures only valid properties are accepted.

### Volume Management

The persistent volume (module/main.tf:109-119) has:

- `delete_protection = true`
- `lifecycle { prevent_destroy = true }`

This protects world data from accidental destruction. The volume must be explicitly unprotected before it can be deleted.

### Start Script Logic

The start script is generated from `module/minecraft/start.tftpl` template with the following features:

- Template receives `memsize` parameter from `var.mc_server_memsize` (defaults to 3GB)
- Sets JVM heap size: `-Xms${memsize}G -Xmx${memsize}G`
- Includes optimized G1GC flags for Minecraft performance
- Runs `server.jar` directly with `nogui` flag

### Firewall Rules

The firewall (module/main.tf:127-157) automatically:

- Opens the Minecraft server port (defaults to 25565)
- Conditionally opens RCON port if `enable-rcon` is true
- Always allows SSH on port 22
- Applies rules to servers with `role=minecraft` label

## Important Notes

### Mod File Validation

The `mc_mods` variable (module/vars.tf:61-72) validates that:

- All mod files exist
- All mod files have `.jar` extension

Note: Previously the validation expected `.zip` files, but this was corrected to `.jar` in recent commits.

### Provisioner Triggers

All provisioners use `triggers` blocks to determine when to re-run. When modifying the module, ensure triggers include all relevant dependencies to avoid stale state.

### Server Types

Currently supports:

- `vanilla`: Standard Minecraft server (downloads from mcutils.com)
- `forge`: Forge modded server (downloads from mcjars.app as zip, then unzips)

The validation is in module/vars.tf:44-47. When adding new server types, update both the validation and the download logic in `mc_jar_provisioner`.

### JVM Memory Configuration

The `mc_server_memsize` variable (module/vars.tf:61-65) controls the heap size allocated to the JVM:

- Defaults to 3GB
- Used in the start.tftpl template to set both `-Xms` and `-Xmx` flags
- Should be sized based on the Hetzner server type and expected player count
