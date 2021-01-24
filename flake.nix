{
  # TODO:
  # - how to auto-update rust nightly channel too

  description = "veloren";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
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
        overlays = [ inputs.rust-overlay.overlay ];
      };
      pkgs_ = genAttrs (builtins.attrNames inputs) (inp: genAttrs supportedSystems (sys: pkgsFor inputs."${inp}" sys));
    in {
      defaultPackage = forAllSystems (system:
        inputs.self.packages."${system}".veloren
      );

      packages = forAllSystems (system:
        let
          pkgs = pkgs_.nixpkgs."${system}";
          chan = pkgs_.nixpkgs.${system}.rust-bin.fromRustupToolchainFile
            "${velorenPkg.src}/rust-toolchain";
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
