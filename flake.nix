{
  description = "Veloren for Nix";
  
  # TODO:
  # - use nixpkgs-mozilla's rust? seems like we want that? or just to pin?
  # - split pkgs/outputs
  # - how to auto-update rust nightly channel too

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
      pkgs = nixpkgs_;
      packages = forAllSystems (system: 
        let 
          pkgs = (nixpkgs_ system);
          chan = pkgs.rustChannelOf {
            rustToolchain = "${veloren.src}/rust-toolchain";
            sha256 = "sha256-hKjJt5RAI9cf55orvwGEkOXIGOaySX5dD2aj3iQ/IDs=";
          };
          rustPlatform = pkgs.recurseIntoAttrs (pkgs.makeRustPlatform {
            cargo = chan.cargo;
            rustc = chan.rust;
          });
          veloren = pkgs.callPackage ./pkgs/veloren/default.nix {
            inherit rustPlatform;
          };
        in
          {
            rustChannel = chan;
            inherit veloren;
          });
    };
}
