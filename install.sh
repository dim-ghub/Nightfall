#!/usr/bin/env bash

# =============================================================================
# Nightfall Installation Script
# =============================================================================
# Target: Arch Linux / Nightfall Setup
# Description: Clone Nightfall repository and create desktop entry
# =============================================================================

set -euo pipefail
shopt -s inherit_errexit

# ANSI colors using ANSI-C quoting
readonly C_RESET=$'\033[0m'
readonly C_BLUE=$'\033[1;34m'
readonly C_GREEN=$'\033[1;32m'
readonly C_RED=$'\033[1;31m'

# Logging functions
log_info() { printf '%s[INFO]%s %s\n' "$C_BLUE" "$C_RESET" "$1"; }
log_success() { printf '%s[SUCCESS]%s %s\n' "$C_GREEN" "$C_RESET" "$1"; }
log_error() { printf '%s[ERROR]%s %s\n' "$C_RED" "$C_RESET" "$1" >&2; }
die() {
	log_error "$*"
	exit 1
}

# --- Main Logic ---

main() {
	local nightfall_dir="$HOME/Nightfall"
	local desktop_dir="$HOME/.local/share/applications"

	log_info "Cloning Nightfall to ~/Nightfall..."

	if [[ -d "$nightfall_dir" ]]; then
		log_info "Nightfall directory already exists, updating..."
		cd "$nightfall_dir"
		if ! git pull; then
			die "Failed to update Nightfall repository"
		fi
	else
		if ! git clone https://github.com/dim-ghub/Nightfall "$nightfall_dir"; then
			die "Failed to clone Nightfall repository"
		fi
	fi

	log_info "Creating applications directory..."
	if ! mkdir -p "$desktop_dir"; then
		die "Failed to create applications directory"
	fi

	log_info "Creating Nightfall.desktop file..."
	if ! cat >"$desktop_dir/Nightfall.desktop" <<EOF; then
[Desktop Entry]
Type=Application
Name=Nightfall Manager
GenericName=nightfall
Comment=TUI for managing DiM's 3rd party configs for Dusky
Exec=uwsm-app -- kitty --class nightfall.sh -e $HOME/Nightfall/nightfall.sh
Terminal=false
Categories=Settings;DesktopSettings;System;Utility;
Keywords=dusky;hyprland;appearance;theme;tui;config;settings;matugen;nightfall
Icon=preferences-desktop-display
StartupNotify=true
StartupWMClass=nightfall.sh
EOF
		die "Failed to create desktop entry file"
	fi

	log_success "Nightfall installation complete!"
	log_info "You can now launch Nightfall from your application menu."
}

main "$@"
