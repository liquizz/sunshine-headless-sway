#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=defaults.env
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/defaults.env"

# Return to the Steam Deck OLED's native display mode when a stream ends.
swaymsg -s "${SWAYSOCK:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sway-sunshine.sock}" \
  "output HEADLESS-1 mode ${DEFAULT_WIDTH}x${DEFAULT_HEIGHT}@${DEFAULT_FPS}Hz"
