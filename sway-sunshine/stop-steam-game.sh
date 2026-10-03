#!/usr/bin/env bash
set -euo pipefail

steam_bin="${STEAM_BIN:-steam}"
sway_socket="${SWAYSOCK:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sway-sunshine.sock}"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
was_running_marker="$runtime_dir/sunshine-headless-steam-was-running"
active_marker="$runtime_dir/sunshine-headless-steam-active"
lock_file="$runtime_dir/sunshine-headless-steam-stop.lock"

exec 9>"$lock_file"
flock -n 9 || exit 0
[[ -e "$active_marker" ]] || exit 0

"$steam_bin" -shutdown >/dev/null 2>&1 || true
for _ in {1..20}; do
  pgrep -x steam >/dev/null 2>&1 || break
  sleep 1
done
if pgrep -x steam >/dev/null 2>&1; then
  pkill -TERM -x steam 2>/dev/null || true
  sleep 2
fi

rm -f "$HOME/.steam/steam.pid" "$HOME/.local/share/Steam/steam.pid" /tmp/steam_singleton_*
rm -f "$active_marker"
swaymsg -s "$sway_socket" "output HEADLESS-1 mode 1280x800@90Hz" >/dev/null 2>&1 || true

if [[ -e "$was_running_marker" ]]; then
  rm -f "$was_running_marker"
  sleep 3
  main_wayland="${SUNSHINE_MAIN_WAYLAND_DISPLAY:-wayland-0}"
  main_desktop="${SUNSHINE_MAIN_DESKTOP:-GNOME}"
  main_display="${DISPLAY:-:0}"

  systemctl --user stop sunshine-headless-restore-steam.service >/dev/null 2>&1 || true
  systemctl --user reset-failed sunshine-headless-restore-steam.service >/dev/null 2>&1 || true
  systemd-run --user --quiet --no-block --collect \
    --unit=sunshine-headless-restore-steam \
    --setenv="WAYLAND_DISPLAY=$main_wayland" \
    --setenv="DISPLAY=$main_display" \
    --setenv="XDG_CURRENT_DESKTOP=$main_desktop" \
    --setenv=XDG_SESSION_TYPE=wayland \
    "$steam_bin" -silent
fi
