#!/usr/bin/env bash
set -uo pipefail

last_host_sink=""

get_default_sink() {
    pactl get-default-sink 2>/dev/null || true
}

sink_exists() {
    local wanted="$1"
    pactl list short sinks 2>/dev/null | awk -v wanted="$wanted" '$2 == wanted { found = 1 } END { exit !found }'
}

move_streams_off_sunshine_sinks() {
    local sink_index input_id
    local -a sunshine_sink_indexes=()

    mapfile -t sunshine_sink_indexes < <(
        pactl list short sinks 2>/dev/null | awk '$2 ~ /^sink-sunshine-/ { print $1 }'
    )

    for sink_index in "${sunshine_sink_indexes[@]}"; do
        while IFS= read -r input_id; do
            [[ -n "$input_id" ]] || continue
            pactl move-sink-input "$input_id" "$last_host_sink" >/dev/null 2>&1 || true
        done < <(
            pactl list short sink-inputs 2>/dev/null | awk -v sink="$sink_index" '$2 == sink { print $1 }'
        )
    done
}

handle_default_sink_change() {
    local current_sink
    current_sink="$(get_default_sink)"
    [[ -n "$current_sink" ]] || return 0

    case "$current_sink" in
        sink-sunshine-*)
            [[ -n "$last_host_sink" ]] || return 0
            sink_exists "$last_host_sink" || return 0

            printf 'Sunshine selected %s; restoring host output to %s\n' \
                "$current_sink" "$last_host_sink"
            pactl set-default-sink "$last_host_sink" || return 0
            move_streams_off_sunshine_sinks
            ;;
        *)
            last_host_sink="$current_sink"
            ;;
    esac
}

# This service is started by Sunshine's app prep command, before stream audio
# initializes. Remember the GNOME output once; then keep watching for Sunshine
# selecting one of its own virtual sinks, including on Moonlight reconnects.
for _ in {1..30}; do
    current_sink="$(get_default_sink)"
    if [[ -n "$current_sink" && "$current_sink" != sink-sunshine-* ]]; then
        last_host_sink="$current_sink"
        break
    fi
    sleep 1
done

if [[ -z "$last_host_sink" ]]; then
    printf 'No non-Sunshine default sink found; audio guard exiting\n' >&2
    exit 1
fi

printf 'Protecting host audio output; current default is %s\n' "$last_host_sink"

# pactl emits a server change event when the default sink changes. Reconnect
# the subscription if the PulseAudio-compatible server restarts.
while :; do
    while IFS= read -r event; do
        case "$event" in
            *"on server"*) handle_default_sink_change ;;
        esac
    done < <(pactl subscribe 2>/dev/null)
    sleep 1
done
