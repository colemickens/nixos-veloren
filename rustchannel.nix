let
  flake = (import (fetchTarball {
    url="https://github.com/edolstra/flake-compat/archive/c75e76f80c57784a6734356315b306140646ee84.tar.gz";
    sha256="071aal00zp2m9knnhddgr2wqzlx6i6qa1263lv1y7bdn2w20h10h";
  }) {
    src = builtins.fetchGit ./.;
  }).defaultNix;
in
  (flake.pkgs "${builtins.currentSystem}").rustChannelOf {
    rustToolchain = "${flake.packages."${builtins.currentSystem}".veloren.src}/rust-toolchain";
    sha256 = "sha256-hKjJt5RAI9cf55orvwGEkOXIGOaySX5dD2aj3iQ/IDs=";
  }
