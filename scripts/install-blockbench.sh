#!/usr/bin/env bash
# Run inside proot-distro Ubuntu (aarch64). Installs Blockbench and the headless MCP server.
set -euo pipefail

BLOCKBENCH_TAG="${BLOCKBENCH_TAG:-v5.2.2}"
BB_MCP_TAG="${BB_MCP_TAG:-v1.10.1}"
BB_HOME="${BB_HOME:-$HOME/blockbench}"
BB_MCP_HOME="${BB_MCP_HOME:-$HOME/blockbench-mcp}"
export DEBIAN_FRONTEND=noninteractive

case "$(uname -m)" in
  aarch64 | arm64) ;;
  *) echo "warning: expected aarch64/arm64, got $(uname -m); continuing anyway" >&2 ;;
esac

install_first_available() {
  local pkg
  for pkg in "$@"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      apt-get install -y --no-install-recommends "$pkg"
      return 0
    fi
  done
  echo "none of these packages are available: $*" >&2
  return 1
}

echo "== Installing system packages"
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates curl git jq unzip xz-utils \
  dbus-x11 xvfb \
  libnss3 libdrm2 libgbm1 libx11-xcb1 libxcomposite1 libxdamage1 \
  libxfixes3 libxrandr2 libxss1 libxtst6 libxkbcommon0 libsecret-1-0 \
  libpango-1.0-0 libcairo2 libuuid1 libgl1 libegl1 libgles2 \
  libvulkan1 mesa-vulkan-drivers

install_first_available libgtk-3-0t64 libgtk-3-0
install_first_available libasound2t64 libasound2
install_first_available libatk1.0-0t64 libatk1.0-0
install_first_available libatk-bridge2.0-0t64 libatk-bridge2.0-0
install_first_available libatspi2.0-0t64 libatspi2.0-0
install_first_available libcups2t64 libcups2
install_first_available libglib2.0-0t64 libglib2.0-0

echo "== Installing Node.js 24"
major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
if [[ "$major" -lt 23 ]]; then
  curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
  apt-get install -y nodejs
fi
node --version
npm --version

echo "== Installing Bun"
if ! command -v bun >/dev/null 2>&1; then
  curl -fsSL https://bun.sh/install | bash
  export PATH="$HOME/.bun/bin:$PATH"
fi
bun --version

echo "== Fetching Blockbench $BLOCKBENCH_TAG into $BB_HOME"
if [[ ! -d "$BB_HOME/.git" ]]; then
  git clone --depth 1 --branch "$BLOCKBENCH_TAG" \
    https://github.com/JannisX11/blockbench.git "$BB_HOME"
fi
cd "$BB_HOME"
npm ci --no-audit --no-fund
npm run build-electron

echo "== Fetching blockbench-mcp $BB_MCP_TAG into $BB_MCP_HOME"
if [[ ! -d "$BB_MCP_HOME/.git" ]]; then
  git clone --depth 1 --branch "$BB_MCP_TAG" \
    https://github.com/jasonjgardner/blockbench-mcp-plugin.git "$BB_MCP_HOME"
fi
cd "$BB_MCP_HOME"
bun install

cat <<EOF

Done.

Desktop app:
  $BB_HOME/scripts/run-blockbench.sh   (or scripts/run-blockbench.sh from this repo)

Headless MCP:
  $BB_MCP_HOME/scripts/run-headless.sh --root ~/models --list
EOF
