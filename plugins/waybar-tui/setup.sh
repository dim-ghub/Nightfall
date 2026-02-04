#!/bin/bash

# =============================================================================
# Waybar TUI Setup Script
# =============================================================================
# This script manages Waybar TUI theme configuration
# =============================================================================

set -euo pipefail

# Handle command line arguments
ACTION=""
case "${1:-}" in
--uninstall)
	ACTION="uninstall"
	;;
--on)
	ACTION="on"
	;;
--off)
	ACTION="off"
	;;
*)
	ACTION="install"
	;;
esac

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"; }
log_warning() { printf "${YELLOW}[WARNING]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

# Script paths
readonly WAYBAR_CONFIG_DIR="$HOME/.config/waybar"
readonly TUI_CONFIG_DIR="$WAYBAR_CONFIG_DIR/TUI"
readonly WAYBAR_CONFIG="$WAYBAR_CONFIG_DIR/config.jsonc"
readonly WAYBAR_STYLE="$WAYBAR_CONFIG_DIR/style.css"

# Check if waybar is available
check_waybar() {
	if ! command -v waybar &>/dev/null; then
		log_error "Waybar not found. Please install waybar first."
		return 1
	fi
	return 0
}

# Restart waybar
restart_waybar() {
	if check_waybar; then
		log_info "Restarting Waybar..."
		pkill waybar 2>/dev/null || true
		sleep 1
		waybar &
		log_success "Waybar restarted"
	fi
}

# Apply TUI theme
apply_tui_theme() {
	if [[ ! -d "$TUI_CONFIG_DIR" ]]; then
		log_error "TUI config directory not found: $TUI_CONFIG_DIR"
		return 1
	fi

	if [[ ! -f "$TUI_CONFIG_DIR/config.jsonc" ]] || [[ ! -f "$TUI_CONFIG_DIR/style.css" ]]; then
		log_error "TUI config files not found"
		return 1
	fi

	log_info "Applying Waybar TUI theme..."

	# Remove existing symlinks in ~/.config/waybar
	find "$WAYBAR_CONFIG_DIR" -maxdepth 1 -type l -delete 2>/dev/null || true

	# Create symlinks from TUI config to ~/.config/waybar
	ln -sf "$TUI_CONFIG_DIR/config.jsonc" "$WAYBAR_CONFIG"
	ln -sf "$TUI_CONFIG_DIR/style.css" "$WAYBAR_STYLE"

	log_success "Waybar TUI theme applied"
}

# Remove TUI theme
remove_tui_theme() {
	log_info "Removing Waybar TUI theme..."

	# Remove symlinks if they point to TUI
	if [[ -L "$WAYBAR_CONFIG" ]] && [[ "$(readlink "$WAYBAR_CONFIG")" == *"TUI"* ]]; then
		rm -f "$WAYBAR_CONFIG"
		log_success "Removed TUI config symlink"
	fi

	if [[ -L "$WAYBAR_STYLE" ]] && [[ "$(readlink "$WAYBAR_STYLE")" == *"TUI"* ]]; then
		rm -f "$WAYBAR_STYLE"
		log_success "Removed TUI style symlink"
	fi
}

# Find first available config folder
find_first_config() {
	# Find first directory alphabetically (excluding TUI)
	local first_dir
	first_dir=$(find "$WAYBAR_CONFIG_DIR" -maxdepth 1 -type d ! -name "TUI" | sort | head -n1)

	if [[ -n "$first_dir" ]]; then
		local dir_name=$(basename "$first_dir")
		log_info "Found config directory: $dir_name"
		echo "$dir_name"
		return 0
	else
		log_warning "No alternative config directories found"
		return 1
	fi
}

# Create symlinks to first available config
create_alternative_symlinks() {
	local config_dir
	config_dir=$(find_first_config)

	if [[ $? -eq 0 && -n "$config_dir" ]]; then
		log_info "Creating symlinks to $config_dir configs..."

		# Remove existing symlinks
		find "$WAYBAR_CONFIG_DIR" -maxdepth 1 -type l -delete 2>/dev/null || true

		# Create new symlinks to first available config
		if [[ -f "$WAYBAR_CONFIG_DIR/$config_dir/config.jsonc" ]]; then
			ln -sf "$config_dir/config.jsonc" "$WAYBAR_CONFIG_DIR/config.jsonc"
			log_success "Linked config.jsonc to $config_dir"
		fi

		if [[ -f "$WAYBAR_CONFIG_DIR/$config_dir/style.css" ]]; then
			ln -sf "$config_dir/style.css" "$WAYBAR_CONFIG_DIR/style.css"
			log_success "Linked style.css to $config_dir"
		fi
	else
		log_warning "No alternative configs available, removing symlinks only"
		find "$WAYBAR_CONFIG_DIR" -maxdepth 1 -type l -delete 2>/dev/null || true
	fi
}

# Action handlers
handle_uninstall() {
	log_info "Uninstalling Waybar TUI theme..."

	# Remove TUI folder
	if [[ -d "$TUI_CONFIG_DIR" ]]; then
		rm -rf "$TUI_CONFIG_DIR"
		log_success "Removed TUI configuration directory"
	fi

	# Remove existing symlinks
	find "$WAYBAR_CONFIG_DIR" -maxdepth 1 -type l -delete 2>/dev/null || true

	# Create symlinks to first available config folder
	create_alternative_symlinks

	# Restart waybar
	restart_waybar

	log_success "Waybar TUI theme uninstalled!"
}

handle_on() {
	log_info "Enabling Waybar TUI theme..."
	apply_tui_theme
	restart_waybar
}

handle_off() {
	log_info "Disabling Waybar TUI theme..."
	remove_tui_theme
	restart_waybar
}

handle_install() {
	log_info "Installing Waybar TUI theme..."
	apply_tui_theme
	restart_waybar
}

# Main setup
main() {
	case "$ACTION" in
	uninstall)
		handle_uninstall
		;;
	on)
		handle_on
		;;
	off)
		handle_off
		;;
	install | *)
		handle_install
		;;
	esac
}

# Run main function
main "$@"
