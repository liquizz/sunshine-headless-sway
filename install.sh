#!/bin/bash
set -euo pipefail

# Headless Sway + Sunshine Game Streaming Setup
# https://github.com/daaaaan/sunshine-headless-sway

SWAY_CONFIG_DIR="$HOME/.config/sway-sunshine"
SUNSHINE_CONFIG_DIR="$HOME/.config/sunshine-headless"
SYSTEMD_DIR="$HOME/.config/systemd/user"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_ID="$(id -u)"
USER_NAME="$(id -un)"
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$USER_ID}"
SUNSHINE_BASE_PORT="${SUNSHINE_HEADLESS_PORT:-48989}"

echo "=== Headless Sway + Sunshine Installer ==="
echo ""

# Detect package manager
install_pkg() {
    if command -v pacman &>/dev/null; then
        sudo pacman -S --needed --noconfirm "$@"
    elif command -v dnf &>/dev/null; then
        # These desktop dependencies come from Fedora repositories; do not let
        # unrelated Sunshine repository metadata block their installation.
        sudo dnf install -y \
            --disablerepo=lizardbyte-stable \
            --disablerepo=lizardbyte-stable-source \
            "$@"
    elif command -v apt &>/dev/null; then
        sudo apt install -y "$@"
    else
        echo "Error: No supported package manager found (pacman, dnf, or apt)"
        exit 1
    fi
}

is_pkg_installed() {
    if command -v pacman &>/dev/null; then
        pacman -Qi "$1" &>/dev/null
    elif command -v dnf &>/dev/null; then
        rpm -q "$1" &>/dev/null
    elif command -v dpkg &>/dev/null; then
        dpkg -s "$1" &>/dev/null 2>&1
    else
        return 1
    fi
}

# Install dependencies
if ! command -v pactl &>/dev/null; then
    echo "Installing the pactl client needed to preserve the host audio output..."
    if command -v pacman &>/dev/null; then
        install_pkg libpulse
    else
        install_pkg pulseaudio-utils
    fi
fi

for cmd in sway swaybg foot; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Installing Sway, its background helper, and terminal..."
        install_pkg sway swaybg foot
        break
    fi
done

if ! is_pkg_installed xdg-desktop-portal-wlr; then
    echo "Installing xdg-desktop-portal-wlr..."
    install_pkg xdg-desktop-portal-wlr
fi

# Detect desktop environment
detect_de() {
    local de="${XDG_CURRENT_DESKTOP:-}"
    de="${de,,}"  # lowercase

    if [[ "$de" == *"gnome"* ]] || [[ "$de" == *"unity"* ]] || [[ "$de" == *"budgie"* ]]; then
        echo "gnome"
    elif [[ "$de" == *"kde"* ]] || [[ "$de" == *"plasma"* ]]; then
        echo "kde"
    elif command -v mutter &>/dev/null; then
        echo "gnome"
    elif command -v kwin_wayland &>/dev/null || command -v kwin_x11 &>/dev/null; then
        echo "kde"
    else
        echo "unknown"
    fi
}

DETECTED_DE=$(detect_de)

echo ""
if [ "$DETECTED_DE" = "gnome" ]; then
    echo "Detected desktop environment: GNOME"
    echo "  → Will use mutter-device-ignore for input isolation"
elif [ "$DETECTED_DE" = "kde" ]; then
    echo "Detected desktop environment: KDE Plasma"
    echo "  → Will strip ID_INPUT tags for input isolation"
else
    echo "Could not auto-detect desktop environment."
    echo ""
    echo "Input isolation method depends on your desktop:"
    echo "  1) GNOME  — uses mutter-device-ignore (targeted, GNOME-only)"
    echo "  2) KDE    — strips ID_INPUT tags (works with KWin and other compositors)"
    echo ""
    read -rp "Select your desktop [1/2]: " DE_CHOICE
    case "$DE_CHOICE" in
        1) DETECTED_DE="gnome" ;;
        2) DETECTED_DE="kde" ;;
        *)
            echo "Invalid choice. Defaulting to KDE method (works with any compositor)."
            DETECTED_DE="kde"
            ;;
    esac
fi

# Check for Sunshine
SUNSHINE_PATH=""
if command -v sunshine &>/dev/null; then
    SUNSHINE_PATH="$(command -v sunshine)"
elif [ -f "$HOME/Apps/sunshine.AppImage" ]; then
    SUNSHINE_PATH="$HOME/Apps/sunshine.AppImage"
else
    echo ""
    echo "Sunshine not found. Please install it from:"
    echo "  https://github.com/LizardByte/Sunshine/releases"
    echo ""
    read -rp "Enter the path to your Sunshine binary/AppImage: " SUNSHINE_PATH
    if [ ! -f "$SUNSHINE_PATH" ]; then
        echo "Error: $SUNSHINE_PATH not found"
        exit 1
    fi
fi

echo "Using Sunshine at: $SUNSHINE_PATH"

# Detect the active desktop's Wayland display and the first free socket for
# Sway. wlroots chooses the first available wayland-N socket at startup.
MAIN_WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
if [[ "$MAIN_WAYLAND_DISPLAY" == /* ]]; then
    MAIN_WAYLAND_DISPLAY="$(basename "$MAIN_WAYLAND_DISPLAY")"
fi
MAIN_DESKTOP="${XDG_CURRENT_DESKTOP:-GNOME}"
HEADLESS_INDEX=0
while [[ -e "$XDG_RUNTIME_DIR/wayland-$HEADLESS_INDEX" || -e "$XDG_RUNTIME_DIR/wayland-$HEADLESS_INDEX.lock" ]]; do
    HEADLESS_INDEX=$((HEADLESS_INDEX + 1))
done
HEADLESS_DISPLAY="wayland-$HEADLESS_INDEX"

if ! [[ "$SUNSHINE_BASE_PORT" =~ ^[0-9]+$ ]] || (( SUNSHINE_BASE_PORT < 1029 || SUNSHINE_BASE_PORT > 65514 )); then
    echo "Error: SUNSHINE_HEADLESS_PORT must be between 1029 and 65514"
    exit 1
fi

echo "Main display: $MAIN_WAYLAND_DISPLAY ($MAIN_DESKTOP), headless will be: $HEADLESS_DISPLAY"
echo "Headless Sunshine uses base port $SUNSHINE_BASE_PORT (Web UI port $((SUNSHINE_BASE_PORT + 1)))."

echo ""
echo "Installing config files..."

# Sway config
mkdir -p "$SWAY_CONFIG_DIR"
cp "$SCRIPT_DIR/sway-sunshine/config" "$SWAY_CONFIG_DIR/config"

cp "$SCRIPT_DIR/sway-sunshine/set-resolution.sh" "$SWAY_CONFIG_DIR/set-resolution.sh"
cp "$SCRIPT_DIR/sway-sunshine/reset-resolution.sh" "$SWAY_CONFIG_DIR/reset-resolution.sh"
cp "$SCRIPT_DIR/sway-sunshine/restore-default-sink.sh" "$SWAY_CONFIG_DIR/restore-default-sink.sh"
cp "$SCRIPT_DIR/sway-sunshine/protect-host-audio.sh" "$SWAY_CONFIG_DIR/protect-host-audio.sh"
cp "$SCRIPT_DIR/sway-sunshine/start-steam-game.sh" "$SWAY_CONFIG_DIR/start-steam-game.sh"
cp "$SCRIPT_DIR/sway-sunshine/stop-steam-game.sh" "$SWAY_CONFIG_DIR/stop-steam-game.sh"
chmod +x "$SWAY_CONFIG_DIR"/*.sh

# Keep all state for the second Sunshine process separate from the user's
# normal ~/.config/sunshine installation (pairings, certs, app list, and logs).
mkdir -p "$SUNSHINE_CONFIG_DIR/credentials"
if [ ! -f "$SUNSHINE_CONFIG_DIR/sunshine.conf" ]; then
    sed -e "s|/home/YOUR_USER|$HOME|g" \
        -e "s|port = 48989|port = $SUNSHINE_BASE_PORT|g" \
        "$SCRIPT_DIR/sunshine/sunshine.conf" > "$SUNSHINE_CONFIG_DIR/sunshine.conf"
    echo "Created sunshine.conf"
else
    echo "Existing headless Sunshine config preserved: $SUNSHINE_CONFIG_DIR/sunshine.conf"
fi

# Apps config (only if not already present)
if [ ! -f "$SUNSHINE_CONFIG_DIR/apps.json" ]; then
    sed -e "s|/home/YOUR_USER|$HOME|g" \
        -e "s|/run/user/1000|$XDG_RUNTIME_DIR|g" \
        -e "s|wayland-1|$HEADLESS_DISPLAY|g" \
        "$SCRIPT_DIR/sunshine/apps.json" > "$SUNSHINE_CONFIG_DIR/apps.json"
    echo "Created apps.json"
else
    echo "apps.json already exists, preserving custom apps. Add the audio-guard prep command from sunshine/apps.json to each app to protect host audio."
fi

# Systemd services
mkdir -p "$SYSTEMD_DIR"

sed -e "s|/run/user/1000|$XDG_RUNTIME_DIR|g" \
    -e "s|wayland-1|$HEADLESS_DISPLAY|g" \
    "$SCRIPT_DIR/systemd/sway-sunshine.service" > "$SYSTEMD_DIR/sway-sunshine.service"

sed -e "s|/run/user/1000|$XDG_RUNTIME_DIR|g" \
    -e "s|wayland-1|$HEADLESS_DISPLAY|g" \
    -e "s|__MAIN_WAYLAND_DISPLAY__|$MAIN_WAYLAND_DISPLAY|g" \
    -e "s|__MAIN_DESKTOP__|$MAIN_DESKTOP|g" \
    -e "s|ExecStart=.*|ExecStart=$SUNSHINE_PATH %h/.config/sunshine-headless/sunshine.conf|g" \
    "$SCRIPT_DIR/systemd/sunshine-headless.service" > "$SYSTEMD_DIR/sunshine-headless.service"

cp "$SCRIPT_DIR/systemd/sunshine-audio-guard.service" "$SYSTEMD_DIR/sunshine-audio-guard.service"

# PipeWire persistent null sink (survives Moonlight disconnect)
PIPEWIRE_DIR="$HOME/.config/pipewire/pipewire.conf.d"
mkdir -p "$PIPEWIRE_DIR"
cp "$SCRIPT_DIR/pipewire/sunshine-null-sink.conf" "$PIPEWIRE_DIR/sunshine-null-sink.conf"
echo "Installed PipeWire persistent audio sink (sunshine_headless_audio)"

# udev rule: install DE-appropriate input isolation rule
UDEV_RULE="85-sunshine-input-isolation.rules"
if [ "$DETECTED_DE" = "gnome" ]; then
    UDEV_TEMPLATE="$SCRIPT_DIR/udev/85-sunshine-input-isolation-gnome.rules"
    echo "Installed GNOME input isolation rule (mutter-device-ignore)"
else
    UDEV_TEMPLATE="$SCRIPT_DIR/udev/85-sunshine-input-isolation-kde.rules"
    echo "Installed KDE input isolation rule (ID_INPUT stripping)"
fi
TEMP_UDEV_RULE="$(mktemp)"
sed "s|__USER__|$USER_NAME|g" "$UDEV_TEMPLATE" > "$TEMP_UDEV_RULE"
sudo install -o root -g root -m 0644 "$TEMP_UDEV_RULE" "/etc/udev/rules.d/$UDEV_RULE"
rm -f "$TEMP_UDEV_RULE"
sudo udevadm control --reload-rules

# Load the persistent stream sink into the running PipeWire graph.
systemctl --user restart pipewire.service

echo "Installed systemd services"

# Reload and enable
systemctl --user daemon-reload
systemctl --user enable sway-sunshine.service
systemctl --user enable sunshine-headless.service

echo ""
echo "=== Installation complete ==="
echo ""
echo "Desktop environment: $DETECTED_DE"
echo ""
echo "To start streaming now:"
echo "  systemctl --user start sway-sunshine.service sunshine-headless.service"
echo ""
echo "To check status:"
echo "  systemctl --user status sway-sunshine sunshine-headless"
echo ""
echo "To add Steam games to Moonlight, edit:"
echo "  $SUNSHINE_CONFIG_DIR/apps.json"
echo ""
echo "If discovery does not show the second instance, add it manually in Moonlight as HOST_IP:$SUNSHINE_BASE_PORT"
echo "Headless Sunshine Web UI: https://localhost:$((SUNSHINE_BASE_PORT + 1))"
echo ""

read -rp "Start the services now? [Y/n] " START
if [[ "${START:-Y}" =~ ^[Yy]?$ ]]; then
    systemctl --user start sway-sunshine.service sunshine-headless.service
    echo "Services started. Open Moonlight to connect."
fi
