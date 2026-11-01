#!/usr/bin/env bash
# Launch the Blockbench desktop app inside proot Ubuntu. Requires an X server (Termux:X11 or Xvfb).
set -euo pipefail

BB_HOME="${BB_HOME:-$HOME/blockbench}"
DISPLAY="${DISPLAY:-:0}"
export DISPLAY

if [[ ! -x "$BB_HOME/node_modules/electron/dist/electron" ]]; then
  echo "Blockbench/Electron not found in $BB_HOME. Run scripts/install-blockbench.sh first." >&2
  exit 1
fi

if [[ "$DISPLAY" == :* ]]; then
  display_num="${DISPLAY#:}"
  display_num="${display_num%%.*}"
  if [[ -n "$display_num" && ! -S "/tmp/.X11-unix/X${display_num}" ]]; then
    echo "warning: no X socket for DISPLAY=$DISPLAY." >&2
    echo "Start Termux:X11 (termux-x11 :0 -ac &), log in with 'proot-distro login ubuntu --shared-tmp'," >&2
    echo "or use an X server such as: xvfb-run -a scripts/run-blockbench.sh" >&2
  fi
fi

args=(--no-sandbox --disable-dev-shm-usage)
extra=()
if [[ -n "${BB_EXTRA_ARGS:-}" ]]; then
  read -r -a extra <<<"$BB_EXTRA_ARGS"
fi

exec "$BB_HOME/node_modules/.bin/electron" "${args[@]}" "${extra[@]}" "$BB_HOME" "$@"
