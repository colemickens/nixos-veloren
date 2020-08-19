{
  description = "Veloren for Nix";
  
  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    nixpkgs-mozilla = { url = "github:mozilla/nixpkgs-mozilla/master"; flake=false;};
  };

  outputs = inputs:
    let
      systems = [
        "x86_64-linux"
      ];
      forAllSystems = f: inputs.nixpkgs.lib.genAttrs systems (system: f system);
      nixpkgs_ = system: import inputs.nixpkgs {
        system = system;
        config.overlays = [ (import "${inputs.nixpkgs-mozilla}/rust-overlay.nix") ];
      };
    in {
      packages = forAllSystems (system: 
        let 
          pkgs = (nixpkgs_ system);
          v = pkgs.callPackage ./default.nix {};
        in
          {
            veloren = v;
          });
    };
}
