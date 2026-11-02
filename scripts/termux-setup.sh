#!/usr/bin/env bash
# Run in Termux (not inside proot). Installs proot-distro, Termux:X11 and Ubuntu.
set -euo pipefail

if [[ ! -x /data/data/com.termux/files/usr/bin/pkg ]]; then
  echo "This script must run in Termux, not inside proot." >&2
  exit 1
fi

pkg update -y
pkg install -y proot-distro
pkg install -y x11-repo
pkg update -y
pkg install -y termux-x11-nightly

rootfs=/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/ubuntu
if [[ ! -d "$rootfs" ]]; then
  proot-distro install ubuntu
fi

cat <<'EOF'

Termux side is ready.

Next:
  1. Install the Termux:X11 app from F-Droid (package com.termux.x11).
  2. Start the X server:            termux-x11 :0 -ac &
  3. Enter Ubuntu with shared tmp:  proot-distro login ubuntu --shared-tmp
  4. Inside Ubuntu, clone this repo and run the installer:
       apt-get update && apt-get install -y git
       git clone https://github.com/Dev-Fantasy/blockbench-termux-headless-mcp.git
       bash ~/blockbench-termux-headless-mcp/scripts/install-blockbench.sh
  5. Then launch the app with:
       export DISPLAY=:0
       bash ~/blockbench-termux-headless-mcp/scripts/run-blockbench.sh
EOF
