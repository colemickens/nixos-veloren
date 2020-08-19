{
  description = "Veloren for Nix";
  
  # TODO:
  # - use nixpkgs-mozilla's rust? seems like we want that? or just to pin?
  # - split pkgs/outputs

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };
    nixpkgs-mozilla = {
      url = "github:mozilla/nixpkgs-mozilla/master";
      flake = false;
    };
  };

  outputs = inputs:
    let
      systems = [
        "x86_64-linux"
      ];
      forAllSystems = f: inputs.nixpkgs.lib.genAttrs systems (system: f system);
      nixpkgs_ = system: import inputs.nixpkgs {
        system = system;
        overlays = [
          (import "${inputs.nixpkgs-mozilla}/rust-overlay.nix")
        ];
      };
    in {
      packages = forAllSystems (system: 
        let 
          pkgs = (nixpkgs_ system);
          base = pkgs.rustChannels.nightly;
          v = pkgs.callPackage ./default.nix {
            rustPlatform = pkgs.recurseIntoAttrs (pkgs.makeRustPlatform {
              cargo = base.cargo;
              rustc = base.rust;
            });
          };
        in
          {
            veloren = v;
          });
    };
}
