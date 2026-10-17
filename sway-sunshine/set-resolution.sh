#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=defaults.env
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/defaults.env"

# Called by Sunshine before streaming. Keep malformed/missing client values
# from becoming arbitrary swaymsg commands.
width="${SUNSHINE_CLIENT_WIDTH:-$DEFAULT_WIDTH}"
height="${SUNSHINE_CLIENT_HEIGHT:-$DEFAULT_HEIGHT}"
fps="${SUNSHINE_CLIENT_FPS:-$DEFAULT_FPS}"

[[ "$width" =~ ^[0-9]{3,4}$ ]] || width=$DEFAULT_WIDTH
[[ "$height" =~ ^[0-9]{3,4}$ ]] || height=$DEFAULT_HEIGHT
[[ "$fps" =~ ^[0-9]{1,3}([.][0-9]{1,3})?$ ]] || fps=$DEFAULT_FPS

swaymsg -s "${SWAYSOCK:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sway-sunshine.sock}" \
  "output HEADLESS-1 mode ${width}x${height}@${fps}Hz"

# Let the display mode settle before Sunshine starts capturing
sleep 1
