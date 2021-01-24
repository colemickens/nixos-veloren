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

      metadata = import ./pkgs/veloren/metadata.nix;
      velorenSrc = system: pkgs_.nixpkgs."${system}".fetchgit {
        url = metadata.repo_git;
        rev = metadata.rev;
        sha256 = metadata.sha256;
        fetchLFS = true;
      };
    in {
      defaultPackage = forAllSystems (system:
        inputs.self.packages."${system}".veloren
      );

      packages = forAllSystems (system:
        let
          pkgs = pkgs_.nixpkgs."${system}";
          #base = (pkgs.rust-bin.fromRustupToolchainFile "${velorenSrc system}/rust-toolchain");
          base = (pkgs.rustChannelOf { channel = "nightly"; date = "2021-01-01"; });

          rustPlatform = pkgs.recurseIntoAttrs (pkgs.makeRustPlatform {
            rustc = (builtins.trace (builtins.attrNames base) base.rust);
            cargo = base.cargo;
          });
        in
          {
            veloren = pkgs.callPackage ./pkgs/veloren/default.nix {
              rustPlatform = rustPlatform;
              velorenSrc = (velorenSrc system);
            };
          });
    };
}
