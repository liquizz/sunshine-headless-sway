#!/usr/bin/env bash
set -euo pipefail

# Sunshine temporarily changes the PulseAudio/PipeWire default sink. Remember
# the host's current sink and restore it once Sunshine selects the stream sink.
sink_id="$(wpctl status 2>/dev/null | awk '
  /Sinks:/ { in_sinks=1; next }
  in_sinks && /Sources:/ { exit }
  in_sinks && /\*/ {
    if (match($0, /[0-9]+[.]/)) {
      print substr($0, RSTART, RLENGTH-1)
      exit
    }
  }
')"

[[ "$sink_id" =~ ^[0-9]+$ ]] || exit 0
systemctl --user stop sunshine-headless-sink-restore.service >/dev/null 2>&1 || true
systemctl --user reset-failed sunshine-headless-sink-restore.service >/dev/null 2>&1 || true

systemd-run --user --quiet --no-block \
  --unit=sunshine-headless-sink-restore \
  /usr/bin/bash -c '
    original="$1"
    for _ in {1..60}; do
      sleep 1
      current="$(wpctl status 2>/dev/null | awk "/Sinks:/ { in_sinks=1; next } in_sinks && /Sources:/ { exit } in_sinks && /\\*/ { if (match(\$0, /[0-9]+[.]/)) { print substr(\$0, RSTART, RLENGTH-1); exit } }")"
      if [[ -n "$current" && "$current" != "$original" ]]; then
        wpctl set-default "$original" || true
        exit 0
      fi
    done
  ' _ "$sink_id"
