#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
set -euo pipefail
set -x

unset NIX_PATH

# build up commit msg
defaultcommitmsg="auto-updates:"
commitmsg="${defaultcommitmsg}";

# keep track of what we build for the README
pkgentries=(); nixpkgentries=();
cache="veloren";

function update() {
  #set +x
  typ="${1}"
  pkg="${2}"

  echo "============================================================================"
  echo "${pkg}: checking"

  metadata="${pkg}/metadata.nix"
  pkgname="$(basename "${pkg}")"

  # TODO: nix2json, update in parallel
  # TODO: aka, not in bash

  branch="$(nix-instantiate "${metadata}" --eval --json -A branch 2>/dev/null | jq -r .)"
  rev="$(nix-instantiate "${metadata}" --eval --json -A rev  2>/dev/null | jq -r .)"
  sha256="$(nix-instantiate "${metadata}" --eval --json -A sha256  2>/dev/null | jq -r .)"
  upattr="$(nix-instantiate "${metadata}" --eval --json -A upattr  2>/dev/null | jq -r . || echo "${pkgname}")"
  url="$(nix-instantiate "${metadata}" --eval --json -A url  2>/dev/null | jq -r . || echo "missing_url")"
  cargoSha256="$(nix-instantiate "${metadata}" --eval --json -A cargoSha256  2>/dev/null | jq -r . || echo "missing_cargoSha256")"
  vendorSha256="$(nix-instantiate "${metadata}" --eval --json -A vendorSha256  2>/dev/null | jq -r . || echo "missing_vendorSha256")"
  skip="$(nix-instantiate "${metadata}" --eval --json -A skip  2>/dev/null | jq -r . || echo "false")"

  if [[ "${skip}" != "true" ]]; then
    # Determine RepoTyp (git/hg)
    if   nix-instantiate "${metadata}" --eval --json -A repo_git &>/dev/null; then repotyp="git";
    elif nix-instantiate "${metadata}" --eval --json -A repo_hg &>/dev/null; then repotyp="hg";
    else echo "unknown repo_typ" && exit 1;
    fi

    # Update Rev
    if [[ "${repotyp}" == "git" ]]; then
      repo="$(nix-instantiate "${metadata}" --eval --json -A repo_git | jq -r .)"
      newrev="$(git ls-remote "${repo}" "${branch}" | awk '{ print $1}')"
    elif [[ "${repotyp}" == "hg" ]]; then
      repo="$(nix-instantiate "${metadata}" --eval --json -A repo_hg | jq -r .)"
      newrev="$(hg identify "${repo}" -r "${branch}")"
    fi

    if [[ "${rev}" != "${newrev}" ]]; then
      commitmsg="${commitmsg} ${pkgname},"

      echo "${pkg}: ${rev} => ${newrev}"

      # Update Sha256
      if [[ "${typ}" == "pkgs" ]]; then
        newsha256="$(NIX_PATH="nixpkgs=https://github.com/nixos/nixpkgs/archive/nixos-unstable.tar.gz" \
          nix-prefetch --output raw \
            -E "(import ./packages.nix).${upattr}" \
            --rev "${newrev}")"
      elif [[ "${typ}" == "nixpkgs" ]]; then
        newsha256="$(NIX_PATH="${tmpnixpath}" nix-prefetch-url --unpack "${url}" 2>/dev/null)"
      fi

      # TODO: do this with nix instead of sed?
      sed -i "s/${rev}/${newrev}/" "${metadata}"
      sed -i "s|${sha256}|${newsha256}|" "${metadata}"

      # CargoSha256 has to happen AFTER the other rev/sha256 bump
      if [[ "${cargoSha256}" != "missing_cargoSha256" ]]; then
        newcargoSha256="$(NIX_PATH="nixpkgs=https://github.com/nixos/nixpkgs/archive/nixos-unstable.tar.gz" \
          nix-prefetch \
            "{ sha256 }: let p=(import ./packages.nix).${upattr}; in p.cargoDeps.overrideAttrs (_: { cargoSha256 = sha256; })")"
        sed -i "s|${cargoSha256}|${newcargoSha256}|" "${metadata}"
      fi

      # VendorSha256 has to happen AFTER the other rev/sha256 bump
      if [[ "${vendorSha256}" != "missing_vendorSha256" ]]; then
        newvendorSha256="$(NIX_PATH="nixpkgs=https://github.com/nixos/nixpkgs/archive/nixos-unstable.tar.gz" \
          nix-prefetch \
            "{ sha256 }: let p=(import ./packages.nix).${upattr}; in p.go-modules.overrideAttrs (_: { vendorSha256 = sha256; })")"
        sed -i "s|${vendorSha256}|${newvendorSha256}|" "${metadata}"
      fi

      set +x
    fi
  fi
}

# update flake inputs
nix --experimental-features 'nix-command flakes' \
  flake update --update-input nixpkgs

for p in `ls -d -- pkgs/*/`; do
  update "pkgs" "${p}"
done

set -x

out="$(mktemp -d)"
nix --experimental-features 'nix-command flakes' \
  build --out-link "${out}/result" \
    --option "extra-binary-caches" "https://cache.nixos.org https://veloren.cachix.org" \
    --option "trusted-public-keys" "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= veloren.cachix.org-1:u8IX/r/JHpC5eb4hCwkTwf2IoTQ36No8z4gZGU6ga7E=" \
    --option "build-cores" "0" \
    --option "narinfo-cache-negative-ttl" "0" \
      -f ./packages.nix

if find ${out} | grep result; then
  nix --experimental-features 'nix-command flakes' \
    path-info --json -r ${out}/result* > ${out}/path-info.json
  jq -r 'map(select(.ca == null and .signatures == null)) | map(.path) | .[]' < "${out}/path-info.json" > "${out}/paths"
  cachix push "${cache}" < "${out}/paths"
fi

if [[ "${JOB_ID:-""}" != "" ]]; then
  git status
  git add -A .
  git status
  git diff-index --cached --quiet HEAD || git commit -m "${commitmsg}"

  echo "we're building on sr.ht, pushing..."
  git push origin HEAD
fi
