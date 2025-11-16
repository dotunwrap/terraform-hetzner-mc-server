<div align = center>

# Aitai MC Server

[![Badge CD]][CD]
[![Badge CI]][CI]
[![Badge Nix]][Nix]
[![Badge X]][Follow X]

_aitai - Japanese for "I miss you" / "I want to see you"_

</div>

---

> [!NOTE]
> This is a hobbiest project for brushing up on my Terraform. I am extremely aware that this is overkill.

This is a Minecraft server running vanilla 1.21.10 deployed and provisioned on [Hetzner](https://hetzner.com) using [Terraform](https://developer.hashicorp.com/terraform).

This server is specifically meant for my [boyfriend](https://github.com/jlevere) and I to play on; however, I attempted to build the IaC in a way that can be reused and easily modified for different Minecraft packs or versions.

I would like to give a shoutout to [flytegg/mc-utils](https://github.com/flytegg/mc-utils). This website enabled me to essentially bypass the shakey server.jar download from the official Minecraft website.

<!------------------------------>

[CD]: https://github.com/dotunwrap/aitai-mc/actions/workflows/cd.yml
[CI]: https://github.com/dotunwrap/aitai-mc/actions/workflows/ci.yml
[Nix]: https://nixos.org
[Follow X]: https://twitter.com/intent/user?screen_name=dotunwrap

[Badge CD]: https://github.com/dotunwrap/aitai-mc/actions/workflows/cd.yml/badge.svg
[Badge CI]: https://github.com/dotunwrap/aitai-mc/actions/workflows/ci.yml/badge.svg
[Badge Nix]: https://img.shields.io/badge/-nix_btw-75afd7?logo=nixos&logoColor=CAD3F5&labelColor=24273A
[Badge X]: https://img.shields.io/twitter/follow/dotunwrap
