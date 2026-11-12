#!/bin/sh
set -eu

INSTALL_DIR="${STCLI_INSTALL_DIR:-$HOME/.stcli/bin}"
GITHUB_REPO="super-trace/stcli-releases"
API_URL="${GITHUB_API_URL:-https://api.github.com}"
SERVER_URL="${GITHUB_SERVER_URL:-https://github.com}"
NEEDS_SOURCE=false

main() {
  detect_platform
  get_version
  download_and_verify
  install_binary
  setup_path
  print_success
}

fail() {
  printf 'Error: %s\n' "$1" >&2
  shift
  [ $# -eq 0 ] || printf '%s\n' "$@" >&2
  exit 1
}

detect_platform() {
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)

  case "$OS" in
    darwin) ARCH_LABEL="universal" ;;
    linux)
      case "$ARCH" in
        x86_64|amd64) ARCH_LABEL="amd64" ;;
        arm64|aarch64) ARCH_LABEL="arm64" ;;
        *) fail "unsupported architecture: $ARCH" "Supported: x86_64, arm64." ;;
      esac
      ;;
    *) fail "unsupported operating system: $OS" "Supported: macOS, Linux, WSL. For Windows, use install.ps1." ;;
  esac

  echo "Detected: $OS $ARCH"
}

# Retries live here because BusyBox wget ignores --tries and curl's --retry skips refused connections.
fetch() {
  output="$1"
  url="$2"
  header="${3:-}"
  for attempt in 1 2 3; do
    if command -v curl >/dev/null 2>&1; then
      curl -fsSL --connect-timeout 15 --speed-limit 1024 --speed-time 30 ${header:+-H "$header"} -o "$output" "$url" && return
    elif command -v wget >/dev/null 2>&1; then
      wget -q -T 30 ${header:+--header="$header"} -O "$output" "$url" && return
    else
      fail "curl or wget is required but neither is installed."
    fi
    [ "$attempt" = 3 ] || { echo "Request failed, retrying..." >&2; sleep 2; }
  done
  fail "could not download $url"
}

http_get() {
  fetch - "$1" ${GITHUB_TOKEN:+"Authorization: Bearer $GITHUB_TOKEN"}
}

get_version() {
  if [ -n "${STCLI_VERSION:-}" ]; then
    VERSION=$(echo "$STCLI_VERSION" | sed 's/^v//')
    echo "Installing requested version: v$VERSION"
  else
    VERSION=$(http_get "$API_URL/repos/${GITHUB_REPO}/releases/latest" | \
      sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p')
    if [ -z "$VERSION" ]; then
      fail "could not determine latest version." "Check your internet connection or try again later."
    fi
    echo "Latest version: v$VERSION"
  fi
  if ! printf '%s\n' "$VERSION" | LC_ALL=C grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$'; then
    fail "invalid release version."
  fi
}

download_and_verify() {
  ARCHIVE="stcli_${VERSION}_${OS}_${ARCH_LABEL}.tar.gz"
  BASE_URL="$SERVER_URL/${GITHUB_REPO}/releases/download/v${VERSION}"

  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR" "${STAGED:-}"' EXIT

  echo "Downloading stcli v${VERSION}..."
  fetch "$TMP_DIR/checksums.txt" "$BASE_URL/checksums.txt"
  EXPECTED=$(awk -v asset="$ARCHIVE" 'NF == 2 && $2 == asset { print $1 }' "$TMP_DIR/checksums.txt")
  if ! printf '%s\n' "$EXPECTED" | LC_ALL=C grep -Eq '^[a-fA-F0-9]{64}$' ||
     [ "$(printf '%s\n' "$EXPECTED" | wc -l | tr -d ' ')" != "1" ]; then
    fail "missing, invalid, or duplicate checksum for $ARCHIVE"
  fi
  EXPECTED=$(printf '%s' "$EXPECTED" | tr '[:upper:]' '[:lower:]')

  fetch "$TMP_DIR/$ARCHIVE" "$BASE_URL/$ARCHIVE"

  echo "Verifying checksum..."
  if command -v sha256sum >/dev/null 2>&1; then
    ACTUAL=$(sha256sum "$TMP_DIR/$ARCHIVE" | cut -d' ' -f1)
  elif command -v shasum >/dev/null 2>&1; then
    ACTUAL=$(shasum -a 256 "$TMP_DIR/$ARCHIVE" | cut -d' ' -f1)
  else
    fail "sha256sum or shasum is required to verify the download."
  fi

  if [ "$ACTUAL" != "$EXPECTED" ]; then
    fail "checksum verification failed." "  Expected: $EXPECTED" "  Actual:   $ACTUAL" \
      "The downloaded file may be corrupted. Please try again."
  fi

  echo "Checksum verified."

  tar -xzf "$TMP_DIR/$ARCHIVE" -C "$TMP_DIR"
}

install_binary() {
  mkdir -p "$INSTALL_DIR"
  # Stage next to the target so the final move is a rename, never a partial copy.
  STAGED=$(mktemp "$INSTALL_DIR/.stcli.XXXXXX")
  cp "$TMP_DIR/stcli" "$STAGED"
  chmod 755 "$STAGED"
  mv -f "$STAGED" "$INSTALL_DIR/stcli"
  STAGED=""

  for BREW_PREFIX in "${HOMEBREW_PREFIX:-}" /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
    [ -n "$BREW_PREFIX" ] || continue
    if [ -d "$BREW_PREFIX/Cellar/stcli" ]; then
      echo ""
      echo "Note: stcli is also installed via Homebrew at $BREW_PREFIX/bin/stcli"
      echo "You may want to run 'brew uninstall stcli' to avoid confusion."
      break
    fi
  done
}

setup_path() {
  case ":$PATH:" in
    *":$INSTALL_DIR:"*) return ;;
  esac

  SHELL_NAME=$(basename "${SHELL:-sh}")
  case "$SHELL_NAME" in
    zsh)  PROFILE="$HOME/.zshrc" ;;
    bash)
      if [ -f "$HOME/.bashrc" ]; then
        PROFILE="$HOME/.bashrc"
      else
        PROFILE="$HOME/.bash_profile"
      fi
      ;;
    fish) PROFILE="$HOME/.config/fish/config.fish" ;;
    *)    PROFILE="$HOME/.profile" ;;
  esac

  EXPORT_LINE="export PATH=\"$INSTALL_DIR:\$PATH\""
  if [ "$SHELL_NAME" = "fish" ]; then
    EXPORT_LINE="set -gx PATH \"$INSTALL_DIR\" \$PATH"
  fi

  if [ -f "$PROFILE" ] && grep -qF "$INSTALL_DIR" "$PROFILE" 2>/dev/null; then
    return
  fi

  mkdir -p "$(dirname "$PROFILE")"
  echo "" >> "$PROFILE"
  echo "$EXPORT_LINE" >> "$PROFILE"
  case "$PROFILE" in
    "$HOME"/*) echo "Added $INSTALL_DIR to PATH in ~${PROFILE#"$HOME"}" ;;
    *) echo "Added $INSTALL_DIR to PATH in $PROFILE" ;;
  esac
  NEEDS_SOURCE=true
}

print_banner() {
  width=0
  for line in "$@"; do
    [ ${#line} -gt $width ] && width=${#line}
  done
  border=$(printf "%$((width + 8))s" '' | tr ' ' '#')
  echo "$border"
  for line in "" "$@" ""; do
    printf "#   %-${width}s   #\n" "$line"
  done
  echo "$border"
}

print_success() {
  echo ""
  echo "stcli v${VERSION} installed to $INSTALL_DIR/stcli"
  echo ""
  if [ "$NEEDS_SOURCE" = "true" ]; then
    case "$PROFILE" in
      "$HOME"/*) PROFILE_DISPLAY="~${PROFILE#"$HOME"}" ;;
      *) PROFILE_DISPLAY="$PROFILE" ;;
    esac
    print_banner \
      "ACTION REQUIRED: load stcli into your PATH" \
      "" \
      "    source $PROFILE_DISPLAY" \
      "" \
      "or open a new terminal."
    echo ""
    echo "Then get started:"
  else
    echo "Get started:"
  fi
  echo "  stcli          — authenticate with your Google or GitHub SSO"
  echo "  stcli --help   — see available commands"
}

main
