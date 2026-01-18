{ inputs, ... }:
{
  perSystem =
    { runCommand, system, ... }:
    let
      inherit (inputs) self;
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      checks = {
        nixfmt = pkgs.runCommand "check-nixfmt-${self.rev or "dirty"}" { } ''
          ${pkgs.nixfmt}/bin/nixfmt --check ${self} < /dev/null | tee $out
        '';
        terraformfmt = pkgs.runCommand "check-terraformfmt-${self.rev or "dirty"}" { } ''
          ${pkgs.terraform}/bin/terraform fmt --check ${self}/module/ < /dev/null | tee $out
        '';
      };
    };
}
