{
  # TODO:
  # - how to auto-update rust nightly channel too


  # Last notes:
  # - we're waiting for this to hit nixos-unstable: https://github.com/NixOS/nixpkgs/commit/741285611f08230f44b443f0b2788dd93c4ba8d0

  description = "veloren";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    fenix.url = "github:figsoda/fenix";
    fenix.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs-mozilla = {
      url = "github:mozilla/nixpkgs-mozilla/master";
      flake = false;
    };
  };
  outputs = inputs:
    let
      supportedSystems = [ "x86_64-linux" ];
      nameValuePair = name: value: { inherit name value; };
      genAttrs = names: f: builtins.listToAttrs (map (n: nameValuePair n (f n)) names);
      forAllSystems = f: inputs.nixpkgs.lib.genAttrs supportedSystems (system: f system);
      pkgsFor = pkgs: sys: import pkgs {
        system = sys;
        config.allowUnfree = true;
        overlays = [(import "${inputs.nixpkgs-mozilla}/rust-overlay.nix")];
      };
      pkgs_ = genAttrs (builtins.attrNames inputs) (inp: genAttrs supportedSystems (sys: pkgsFor inputs."${inp}" sys));
    in {
      defaultPackage = forAllSystems (system:
        inputs.self.packages."${system}".veloren
      );

      packages = forAllSystems (system:
        let
          pkgs = pkgs_.nixpkgs."${system}";
          chan = pkgs.rustChannelOf {
            rustToolchain = "${veloren.src}/rust-toolchain";
            sha256 = "sha256-hKjJt5RAI9cf55orvwGEkOXIGOaySX5dD2aj3iQ/IDs=";
          };
          rustPlatform = pkgs.recurseIntoAttrs (pkgs.makeRustPlatform {
            cargo = chan.cargo;
            rustc = chan.rust;
          });
          velorenPkg = pkgs.callPackage ./pkgs/veloren/default.nix {
            inherit rustPlatform;
          };
        in
          {
            veloren = velorenPkg;
          });
    };
}
