# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Minecraft server Infrastructure-as-Code (IaC) project that deploys vanilla Minecraft 1.21.10 on Hetzner Cloud using Terraform. The infrastructure provisions a dedicated server with persistent storage for game data.

## Development Environment

This project uses Nix flakes for reproducible development environments and tooling.

### Setup

```bash
# Enter the development environment
nix develop

# Or use direnv (if configured)
direnv allow
```

The dev shell provides: `terraform`, `terraform-ls`, `terraform-docs`

## Common Commands

### Terraform Operations

All Terraform operations must be run from the `infra/` directory:

```bash
# Initialize Terraform (required before first use)
cd infra/
terraform init

# Validate configuration
terraform validate

# Plan changes
terraform plan

# Apply changes (deployment)
terraform apply

# Format Terraform files
terraform fmt
```

### Linting and Formatting

```bash
# Run all Nix checks (includes formatting checks)
nix flake check

# Format Nix files
nix fmt

# Format Terraform files
cd infra/
terraform fmt
```

## Architecture

### Infrastructure Components

The infrastructure is defined in `infra/hcloud.tf` and provisions:

1. **Server**: Hetzner CPX21 instance running Debian 13 in Ashburn (ash) datacenter
2. **Volume**: Persistent 50GB ext4 volume mounted at `/mnt/minecraft` (has `prevent_destroy` lifecycle rule)
3. **Firewall**: Allows TCP ports 25565 (Minecraft) and 22 (SSH) from all sources
4. **SSH Key**: CI/CD key for provisioning and management

### Provisioning Flow

The `null_resource.mc_provisioner` handles server setup in this order:

1. Install Java 21 JRE and screen via apt
2. Create `minecraft` user with sudo privileges
3. Mount persistent volume to `/mnt/minecraft` with fstab entry
4. Copy service files: `start.sh`, `eula.txt`, `minecraft.service`
5. Download Minecraft server.jar from mcutils.com API
6. Enable and start systemd service

### Minecraft Runtime

- **Service**: Managed via systemd (`minecraft.service`)
- **Working Directory**: `/mnt/minecraft`
- **User**: `minecraft:minecraft`
- **Java Memory**: 2GB min (-Xms2G), 3GB max (-Xmx3G)
- **Restart Policy**: Always restart on failure

### Configuration Variables

Variables are defined in `infra/vars.tf`:

- `hcloud_token` (required): Hetzner Cloud API token
- `public_ssh_key` (required): SSH public key for server access
- `private_ssh_key` (required, sensitive): SSH private key for provisioning
- `volume_size` (default: 50): Persistent volume size in GB
- `mc_version` (default: "1.21.10"): Minecraft version to download

## CI/CD

### Continuous Integration (.github/workflows/ci.yml)

Runs on PRs and main branch pushes:

1. **Nix checks**: Runs `nix flake check` on macOS and Ubuntu (formatting validation)
2. **Terraform plan**: Generates plan and posts comment to PRs with init/validate/plan output

### Continuous Deployment (.github/workflows/cd.yml)

Deploys to production on main branch pushes when `infra/` changes:

- Runs `terraform apply -auto-approve` to deploy infrastructure changes

### Required Secrets

The following GitHub Actions secrets must be configured:

- `HCLOUD_TOKEN`: Hetzner Cloud API token
- `PUBLIC_SSH_KEY`: SSH public key for server access
- `PRIVATE_SSH_KEY`: SSH private key for provisioning

## Important Notes

- The persistent volume has `prevent_destroy = true` to protect game data
- Server provisioning uses remote-exec and file provisioners over SSH
- Minecraft version can be changed by modifying the `mc_version` variable
- All infrastructure changes to main automatically trigger deployment
