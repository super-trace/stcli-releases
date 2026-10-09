#!/usr/bin/env bash
# User-level installer for macOS, Linux, and WSL. No sudo or shell-file edits.
set -euo pipefail

repo=super-trace/stcli-releases
version=${STCLI_VERSION:-latest}
install_dir=${STCLI_INSTALL_DIR:-"$HOME/.local/bin"}
asset_dir=${STCLI_ASSET_DIR:-}
fail() { printf 'stcli: %s\n' "$*" >&2; exit 1; }

case "$(uname -s)" in
  Darwin) platform=darwin; arch=universal ;;
  Linux)
    platform=linux
    case "$(uname -m)" in
      x86_64|amd64) arch=amd64 ;;
      aarch64|arm64) arch=arm64 ;;
      *) fail 'Unsupported Linux architecture.' ;;
    esac ;;
  *) fail 'Use install.ps1 from PowerShell on native Windows.' ;;
esac
[[ "$version" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail 'Invalid version label.'
[[ -n "$install_dir" ]] || fail 'Installation directory is empty.'

use_gh=false
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  use_gh=true
fi
if [[ "$version" == latest ]]; then
  [[ -z "$asset_dir" ]] || fail 'Set STCLI_VERSION when installing offline.'
  if "$use_gh"; then
    version=$(gh release view --repo "$repo" --json tagName --jq .tagName)
  else
    command -v curl >/dev/null || fail 'Install curl or authenticate with gh first.'
    url=$(curl -fsSL --proto '=https' --proto-redir '=https' -o /dev/null -w '%{url_effective}' \
      "https://github.com/$repo/releases/latest") || fail 'Cannot find a release. Private downloads require gh auth login.'
    [[ "$url" == "https://github.com/$repo/releases/tag/"* ]] || fail 'No latest release available.'
    version=${url##*/}
  fi
fi
version=${version#v}
[[ "$version" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail 'Release returned an invalid version.'
archive="stcli_${version}_${platform}_${arch}.tar.gz"
work=$(mktemp -d)
staged=
cleanup() { rm -rf "$work"; [[ -z "$staged" ]] || rm -f "$staged"; }
trap cleanup EXIT

if [[ -n "$asset_dir" ]]; then
  cp "$asset_dir/$archive" "$asset_dir/checksums.txt" "$work/"
elif "$use_gh"; then
  gh release download "v$version" --repo "$repo" --dir "$work" \
    --pattern "$archive" --pattern checksums.txt
else
  for name in "$archive" checksums.txt; do
    curl -fsSL --proto '=https' --proto-redir '=https' \
      "https://github.com/$repo/releases/download/v$version/$name" -o "$work/$name" \
      || fail 'Download failed. Private downloads require gh auth login.'
  done
fi

expected=$(awk -v name="$archive" '$2 == name {print $1}' "$work/checksums.txt")
[[ "$expected" =~ ^[0-9a-fA-F]{64}$ ]] || fail 'Missing or ambiguous SHA-256 checksum.'
if command -v sha256sum >/dev/null 2>&1; then
  actual=$(sha256sum "$work/$archive"); actual=${actual%% *}
elif command -v shasum >/dev/null 2>&1; then
  actual=$(shasum -a 256 "$work/$archive"); actual=${actual%% *}
else
  fail 'Install sha256sum or shasum first.'
fi
[[ "$actual" == "$expected" ]] || fail 'Checksum mismatch; existing installation left untouched.'
[[ "$(tar -tzf "$work/$archive")" == stcli ]] || fail 'Unexpected archive contents.'
tar -xzf "$work/$archive" -C "$work"
[[ -f "$work/stcli" && ! -L "$work/stcli" ]] || fail 'Archive did not contain a regular executable.'
mkdir -p "$install_dir"
staged=$(mktemp "$install_dir/.stcli.XXXXXX")
install -m 755 "$work/stcli" "$staged"
mv -f "$staged" "$install_dir/stcli"
staged=
printf 'Installed stcli %s to %s/stcli\n' "$version" "$install_dir"
case ":$PATH:" in
  *":$install_dir:"*) ;;
  *) printf 'Add this directory to your PATH: %s\n' "$install_dir"
     printf 'For this terminal: export PATH="%s:$PATH"\n' "$install_dir" ;;
esac
printf 'Run: stcli login\n'
