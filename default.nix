{ lib, git, git-lfs, rustPlatform, fetchgit
, pkg-config
, libudev, alsaLib
, openssl
, atk, cairo, glib, gtk3, pango
}:

let
  metadata = builtins.fromJSON (builtins.readFile ./metadata.json);
in
  rustPlatform.buildRustPackage rec {
    pname = "veloren";
    version = "${metadata.rev}";

    src = fetchgit {
      url = metadata.repo_git;
      rev = metadata.rev;
      sha256 = metadata.sha256;
      leaveDotGit = true;
      postFetch = ''
        set -e
        set -x
        cd $out
        git remote -v
        git remote add origin ${metadata.repo_git}
        git remote update
        export PATH=''${PATH}:${git}/bin
        ${git-lfs}/bin/git-lfs pull
        rm -rf .git
      '';
    };

    cargoSha256 = metadata.cargoSha256;

    buildInputs = [
      pkg-config
      libudev alsaLib
      openssl
      atk cairo glib gtk3 pango
    ];

    nativeBuildInputs = [ pkg-config ];
  }