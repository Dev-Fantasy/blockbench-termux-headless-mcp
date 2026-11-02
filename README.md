# blockbench-termux-headless-mcp

Run **Blockbench** on an ARM64 Android device through Termux, and drive it headlessly with the **Blockbench MCP** server.

This repo is a setup guide plus install/run scripts for the exact stack I use:

- **Termux** + **proot-distro Ubuntu** (aarch64) on Android
- **Blockbench 5.2.2** desktop app (Electron 43.4.0, linux-arm64)
- **blockbench-mcp 1.10.1** headless server (edit, validate, render `.bbmodel` files without the GUI)

Nothing here patches Blockbench. The upstream sources are used as-is; the scripts only install the right ARM64 runtime and launch flags.

## Tested configuration

| Component | Version |
|---|---|
| Host | Android, aarch64, Termux (F-Droid build) |
| Container | proot-distro `ubuntu` (Ubuntu 24.04+ / 26.04, arm64) |
| Node.js | 24.22.0 (Node >= 23.6 is required for rendering) |
| Bun | 1.4.3 |
| Electron | 43.4.0 (linux-arm64, downloaded by npm) |
| Blockbench | v5.2.2 |
| blockbench-mcp | v1.10.1 |

The desktop app was verified launching under X11 inside proot Ubuntu on aarch64. Headless calls and WebGPU renders were verified in the same container. For an on-device window, use [Termux:X11](https://github.com/termux/termux-x11); for remote/CI use, any X server (including `xvfb-run`) works.

---

## 1. Set up Termux

Install **Termux** and **Termux:X11** from F-Droid (the Play Store Termux build is outdated and breaks proot).

In Termux:

```bash
pkg update -y
pkg install -y proot-distro x11-repo termux-x11-nightly
proot-distro install ubuntu
termux-setup-storage   # optional: gives Ubuntu access to /sdcard
```

Or just run the helper:

```bash
bash scripts/termux-setup.sh
```

## 2. Install Blockbench inside Ubuntu

Log into the container, sharing Termux's `/tmp` so the X11 socket is visible:

```bash
proot-distro login ubuntu --shared-tmp
```

Inside Ubuntu:

```bash
apt-get update
apt-get install -y git
git clone https://github.com/BluePhinix/blockbench-arm64.git
cd blockbench-arm64
bash scripts/install-blockbench.sh
```

The script installs Electron's runtime libraries, Node.js 24, Bun, Blockbench `v5.2.2` (with `npm ci` + `npm run build-electron`), and `blockbench-mcp` `v1.10.1` (with `bun install`). Expect roughly 1 GB of downloads and 10-30 minutes on a phone; the Electron binary alone is about 100 MB.

## 3. Run the desktop app

In a Termux session, start the X server and open the Termux:X11 app:

```bash
termux-x11 :0 -ac &
```

Inside the Ubuntu session (`proot-distro login ubuntu --shared-tmp`):

```bash
export DISPLAY=:0
bash ~/blockbench-arm64/scripts/run-blockbench.sh
```

`run-blockbench.sh` starts Electron with `--no-sandbox` and `--disable-dev-shm-usage`, which are required under proot. To open a model directly:

```bash
bash scripts/run-blockbench.sh /sdcard/Download/model.bbmodel
```

### Rendering on a phone GPU

Chromium has no direct access to the Android GPU here, so it falls back to software rendering. If the viewport is blank or WebGL fails, force SwiftShader:

```bash
BB_EXTRA_ARGS="--use-gl=angle --use-angle=swiftshader" bash scripts/run-blockbench.sh
```

If it still fails, try `--disable-gpu`. Software rendering is usable for modeling but slow for large scenes. Keep the screen on and run `termux-wake-lock` in Termux for long sessions.

## 4. Run headless (no GUI)

The headless server works on `.bbmodel` files directly over MCP stdio. It can run while the desktop app is closed, and several agents can each start their own server process.

One-shot call:

```bash
bash ~/blockbench-arm64/scripts/run-headless.sh --root ~/models --list
bash ~/blockbench-arm64/scripts/run-headless.sh --root ~/models bbmodel_info '{"file":"sword.bbmodel"}'
```

### Register it with an MCP client

From the clone:

```json
{
  "mcpServers": {
    "blockbench-headless": {
      "command": "bun",
      "args": [
        "run",
        "/root/blockbench-mcp/headless/index.ts",
        "--root",
        "/root/models"
      ]
    }
  }
}
```

Or run it straight from GitHub without cloning:

```json
{
  "mcpServers": {
    "blockbench-headless": {
      "command": "bunx",
      "args": [
        "github:jasonjgardner/blockbench-mcp-plugin#v1.10.1",
        "--root",
        "/root/models"
      ]
    }
  }
}
```

`--root` is required and may be repeated. Tools refuse paths outside every root.

### Rendering headlessly

`bbmodel_render` and `bbmodel_contact_sheet` run a WebGPU renderer under **Node**, not Bun. The first render installs `three`, `three-blockbench` and Dawn (about 130 MB) into `~/.cache/blockbench-mcp-headless`; set `BB_RENDER_HOME` or pass `--render-home <dir>` to move it. The install script already provides Node 24, so no extra setup is needed.

```bash
bash scripts/run-headless.sh --root ~/models bbmodel_render '{"file":"sword.bbmodel","preset":"icon","view":"iso"}'
```

Renders print PNG paths you can open from Termux or pull with `adb`.

### Desktop-plugin MCP (optional)

If you want an agent to drive the **open Blockbench editor** instead of files on disk, install the "Blockbench MCP" plugin from Blockbench's plugin panel (`File → Plugins`) and register the plugin's HTTP/SSE endpoint. The headless server in this repo does not need that plugin.

---

## Manual install (no scripts)

Inside Ubuntu, if you prefer to run the steps yourself:

```bash
apt-get update
apt-get install -y ca-certificates curl git jq unzip \
  libnss3 libgtk-3-0t64 libasound2t64 libatk1.0-0t64 libatk-bridge2.0-0t64 \
  libatspi2.0-0t64 libcups2t64 libdrm2 libgbm1 libx11-xcb1 libxcomposite1 \
  libxdamage1 libxfixes3 libxrandr2 libxss1 libxtst6 libxkbcommon0 \
  libsecret-1-0 libpango-1.0-0 libcairo2 libuuid1 libgl1 libegl1 libgles2 \
  libvulkan1 mesa-vulkan-drivers xvfb dbus-x11

# Node 24
curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
apt-get install -y nodejs

# Bun
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc

# Blockbench + build
git clone --depth 1 --branch v5.2.2 https://github.com/JannisX11/blockbench.git ~/blockbench
cd ~/blockbench
npm ci --no-audit --no-fund
npm run build-electron

# Headless MCP
git clone --depth 1 --branch v1.10.1 \
  https://github.com/jasonjgardner/blockbench-mcp-plugin.git ~/blockbench-mcp
cd ~/blockbench-mcp
bun install
```

On Ubuntu 22.04 or older, drop the `t64` suffixes from the library names (`libgtk-3-0`, `libasound2`, `libatk1.0-0`, `libatk-bridge2.0-0`, `libatspi2.0-0`, `libcups2`).

---

## Troubleshooting

**`Cannot open display :0`**
Start Termux:X11 before logging into Ubuntu, and use `proot-distro login ubuntu --shared-tmp`. Check that the socket exists with `ls /tmp/.X11-unix`. If you use a non-default display, export the matching `DISPLAY`.

**`The SUID sandbox helper binary was found, but is not configured correctly`**
Expected under proot. `run-blockbench.sh` already passes `--no-sandbox`; keep it.

**DBus / udev errors in the terminal**
`Failed to connect to the bus` and `Failed to initialize a udev monitor` are harmless inside proot. Blockbench still starts.

**Blank viewport, black window, or WebGL errors**
Force software WebGL: `BB_EXTRA_ARGS="--use-gl=angle --use-angle=swiftshader"`. As a last resort add `--disable-gpu`. Expect lower frame rates.

**Electron download fails during `npm ci`**
Retry, or use a mirror:
```bash
ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/ npm ci --no-audit --no-fund
```

**`npm ci` is killed (out of memory)**
Close other apps and retry with a larger heap:
```bash
NODE_OPTIONS=--max-old-space-size=2048 npm ci --no-audit --no-fund
```

**Headless render says WebGPU/Dawn failed**
Confirm `node --version` is 23.6 or newer and that `mesa-vulkan-drivers` is installed. Delete `~/.cache/blockbench-mcp-headless` and let the first render reinstall it.

**Termux kills long-running sessions**
Android's phantom-process killer can reap proot. Disable it in Developer options, keep Termux in the foreground or use `termux-wake-lock`, and avoid battery optimization for Termux and Termux:X11.

**Files under `/sdcard` are not writable**
Run `termux-setup-storage` in Termux, then use `/sdcard` (or `/storage/emulated/0`) inside Ubuntu. Scoped storage may still block some paths; keeping projects in `~/models` inside Ubuntu is the most reliable option.

---

## Notes and limits

- Blockbench is [GPL-3.0-or-later](https://github.com/JannisX11/blockbench); the MCP plugin is [GPL-3.0-only](https://github.com/jasonjgardner/blockbench-mcp-plugin). This repo only contains install scripts and notes and is not affiliated with either project.
- Pinned versions are deliberate. Update `BLOCKBENCH_TAG` / `BB_MCP_TAG` to move them.
- No root and no custom kernel are required; everything runs in userspace via proot.
- Software rendering and proot overhead make this slower than desktop. For heavy scenes, use the headless renderer (it uses Dawn/SwiftShader efficiently) or a desktop machine.
