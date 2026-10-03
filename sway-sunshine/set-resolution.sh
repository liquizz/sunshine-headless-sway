#!/bin/bash
#!/usr/bin/env bash
set -euo pipefail

# Called by Sunshine before streaming. Keep malformed/missing client values
# from becoming arbitrary swaymsg commands.
width="${SUNSHINE_CLIENT_WIDTH:-1280}"
height="${SUNSHINE_CLIENT_HEIGHT:-800}"
fps="${SUNSHINE_CLIENT_FPS:-90}"

[[ "$width" =~ ^[0-9]{3,4}$ ]] || width=1280
[[ "$height" =~ ^[0-9]{3,4}$ ]] || height=800
[[ "$fps" =~ ^[0-9]{1,3}([.][0-9]{1,3})?$ ]] || fps=90

swaymsg -s "${SWAYSOCK:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sway-sunshine.sock}" \
  "output HEADLESS-1 mode ${width}x${height}@${fps}Hz"

# Let the display mode settle before Sunshine starts capturing
sleep 1
