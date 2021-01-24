{ lib, fetchgit, rustPlatform
, velorenSrc
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

    src = velorenSrc;

    cargoSha256 = metadata.cargoSha256;

    doCheck = false;

    nativeBuildInputs = [
      pkg-config
      python3
    ];

    VELOREN_USERDATA_STRATEGY = "system";

    buildInputs = [
      pkg-config
      libudev alsaLib
      openssl
      atk cairo glib gtk3 pango
    ];
  }
