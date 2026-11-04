#!/bin/sh
set -eu

INSTALL_DIR="${STCLI_INSTALL_DIR:-$HOME/.stcli/bin}"
GITHUB_REPO="super-trace/stcli-releases"
API_URL="${GITHUB_API_URL:-https://api.github.com}"
SERVER_URL="${GITHUB_SERVER_URL:-https://github.com}"
NEEDS_SOURCE=false

main() {
  detect_platform
  get_latest_version
  download_and_verify
  install_binary
  setup_path
  print_success
}

fail() {
  printf 'Error: %s\n' "$@" >&2
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

http_get() {
  url="$1"
  if command -v curl >/dev/null 2>&1; then
    if [ -n "${GITHUB_TOKEN:-}" ]; then
      curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" "$url"
    else
      curl -fsSL "$url"
    fi
  elif command -v wget >/dev/null 2>&1; then
    if [ -n "${GITHUB_TOKEN:-}" ]; then
      wget -qO- --header="Authorization: Bearer $GITHUB_TOKEN" "$url"
    else
      wget -qO- "$url"
    fi
  else
    fail "curl or wget is required but neither is installed."
  fi
}

http_download() {
  url="$1"
  output="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$output" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$output" "$url"
  else
    fail "curl or wget is required but neither is installed."
  fi
}

get_latest_version() {
  LATEST_VERSION=$(http_get "$API_URL/repos/${GITHUB_REPO}/releases/latest" | \
    sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p')

  if [ -z "$LATEST_VERSION" ]; then
    fail "could not determine latest version." "Check your internet connection or try again later."
  fi

  if [ -n "${STCLI_VERSION:-}" ]; then
    VERSION=$(echo "$STCLI_VERSION" | sed 's/^v//')
    echo "Installing requested version: v$VERSION (latest is v$LATEST_VERSION)"
  else
    VERSION="$LATEST_VERSION"
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
  trap 'rm -rf "$TMP_DIR"' EXIT

  echo "Downloading stcli v${VERSION}..."
  http_download "$BASE_URL/checksums.txt" "$TMP_DIR/checksums.txt"

  echo "Verifying checksum..."
  EXPECTED=$(awk -v asset="$ARCHIVE" 'NF == 2 && $2 == asset { print $1 }' "$TMP_DIR/checksums.txt")
  if ! printf '%s\n' "$EXPECTED" | LC_ALL=C grep -Eq '^[a-fA-F0-9]{64}$' ||
     [ "$(printf '%s\n' "$EXPECTED" | wc -l | tr -d ' ')" != "1" ]; then
    fail "missing, invalid, or duplicate checksum for $ARCHIVE"
  fi
  EXPECTED=$(printf '%s' "$EXPECTED" | tr '[:upper:]' '[:lower:]')

  http_download "$BASE_URL/$ARCHIVE" "$TMP_DIR/$ARCHIVE"

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
  mv "$TMP_DIR/stcli" "$INSTALL_DIR/stcli"
  chmod +x "$INSTALL_DIR/stcli"

  if command -v brew >/dev/null 2>&1; then
    BREW_STCLI=$(brew --prefix 2>/dev/null)/bin/stcli
    if [ -f "$BREW_STCLI" ]; then
      echo ""
      echo "Note: stcli is also installed via Homebrew at $BREW_STCLI"
      echo "You may want to run 'brew uninstall stcli' to avoid confusion."
    fi
  fi
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
    EXPORT_LINE="set -gx PATH $INSTALL_DIR \$PATH"
  fi

  if [ -f "$PROFILE" ] && grep -qF "$INSTALL_DIR" "$PROFILE" 2>/dev/null; then
    return
  fi

  echo "" >> "$PROFILE"
  echo "$EXPORT_LINE" >> "$PROFILE"
  echo "Added $INSTALL_DIR to PATH in $PROFILE"
  NEEDS_SOURCE=true
}

print_success() {
  echo ""
  echo "stcli v${VERSION} installed to $INSTALL_DIR/stcli"
  echo ""
  if [ "$VERSION" != "$LATEST_VERSION" ]; then
    echo "Note: You installed v${VERSION}, but the latest is v${LATEST_VERSION}."
    echo "Re-run this installer without STCLI_VERSION to upgrade."
    echo ""
  fi
  if [ "$NEEDS_SOURCE" = "true" ]; then
    echo "Run 'source $PROFILE' or open a new terminal, then:"
  fi
  echo "  stcli login    — authenticate with your Supertrace account"
  echo "  stcli --help   — see available commands"
}

main
