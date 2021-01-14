{ lib, fetchgit, rustPlatform
, pkg-config, python3
, libudev, alsaLib
, openssl
, atk, cairo, glib, gtk3, pango
}:

let
  metadata = import ./metadata.nix;
in
  rustPlatform.buildRustPackage rec {
    pname = "veloren";
    version = "${metadata.rev}";

    src = fetchgit {
      url = metadata.repo_git;
      rev = metadata.rev;
      sha256 = metadata.sha256;
      fetchLFS = true;
    };

    cargoSha256 = metadata.cargoSha256;

    doCheck = false;

    nativeBuildInputs = [
      pkg-config
      python3
    ];

    buildInputs = [
      pkg-config
      libudev alsaLib
      openssl
      atk cairo glib gtk3 pango
    ];
  }
