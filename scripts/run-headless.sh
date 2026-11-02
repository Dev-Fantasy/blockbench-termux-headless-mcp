#!/usr/bin/env bash
# One-shot wrapper for the headless Blockbench MCP server.
# Examples:
#   bash ~/blockbench-termux-headless-mcp/scripts/run-headless.sh --root ~/models --list
#   bash ~/blockbench-termux-headless-mcp/scripts/run-headless.sh --root ~/models bbmodel_info '{"file":"sword.bbmodel"}'
set -euo pipefail

BB_MCP_HOME="${BB_MCP_HOME:-$HOME/blockbench-mcp}"
BUN_BIN="${BUN_BIN:-}"

if [[ -z "$BUN_BIN" ]]; then
  if command -v bun >/dev/null 2>&1; then
    BUN_BIN="$(command -v bun)"
  elif [[ -x "$HOME/.bun/bin/bun" ]]; then
    BUN_BIN="$HOME/.bun/bin/bun"
  else
    echo "Bun not found. Install it from https://bun.sh or run: bash ~/blockbench-termux-headless-mcp/scripts/install-blockbench.sh." >&2
    exit 1
  fi
fi

if [[ ! -f "$BB_MCP_HOME/headless/call.ts" ]]; then
  echo "Headless MCP not found in $BB_MCP_HOME. Run: bash ~/blockbench-termux-headless-mcp/scripts/install-blockbench.sh first," >&2
  echo "or set BB_MCP_HOME to the checkout of jasonjgardner/blockbench-mcp-plugin." >&2
  exit 1
fi

exec "$BUN_BIN" run "$BB_MCP_HOME/headless/call.ts" "$@"
