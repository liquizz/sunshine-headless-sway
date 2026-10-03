#!/usr/bin/env bash
set -euo pipefail

# Return to the Steam Deck OLED's native display mode when a stream ends.
swaymsg -s "${SWAYSOCK:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sway-sunshine.sock}" \
  "output HEADLESS-1 mode 1280x800@90Hz"
