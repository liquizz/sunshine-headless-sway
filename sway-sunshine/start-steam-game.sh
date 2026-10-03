#!/usr/bin/env bash
set -euo pipefail

app_id="${1:-}"
steam_bin="${STEAM_BIN:-steam}"
sway_socket="${SWAYSOCK:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sway-sunshine.sock}"
headless_display="${WAYLAND_DISPLAY:-wayland-1}"
stream_sink="${PULSE_SINK:-sunshine_headless_audio}"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
was_running_marker="$runtime_dir/sunshine-headless-steam-was-running"
active_marker="$runtime_dir/sunshine-headless-steam-active"

if [[ "$app_id" != "bigpicture" && ! "$app_id" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 <Steam app ID|bigpicture|0>" >&2
  exit 2
fi
if ! command -v "$steam_bin" >/dev/null 2>&1; then
  echo "Steam command '$steam_bin' was not found" >&2
  exit 127
fi

rm -f "$was_running_marker"
touch "$active_marker"

# Steam enforces one client instance per user. Move an existing GNOME Steam
# process into the streaming compositor, then return it to GNOME on disconnect.
if pgrep -x steam >/dev/null 2>&1; then
  touch "$was_running_marker"
  "$steam_bin" -shutdown >/dev/null 2>&1 || true
  for _ in {1..20}; do
    pgrep -x steam >/dev/null 2>&1 || break
    sleep 1
  done
  if pgrep -x steam >/dev/null 2>&1; then
    pkill -TERM -x steam 2>/dev/null || true
    sleep 2
  fi
fi

rm -f "$HOME/.steam/steam.pid" "$HOME/.local/share/Steam/steam.pid" /tmp/steam_singleton_*
sleep 3

steam_env=$(printf 'env WAYLAND_DISPLAY=%q PULSE_SINK=%q XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=sway %q' \
  "$headless_display" "$stream_sink" "$steam_bin")

case "$app_id" in
  bigpicture) command="$steam_env steam://open/bigpicture" ;;
  0) command="$steam_env" ;;
  *) command="$steam_env -applaunch $app_id" ;;
esac

swaymsg -s "$sway_socket" exec "$command"
