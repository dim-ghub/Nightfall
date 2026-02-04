#!/bin/bash

# =============================================================================
# OBS Studio Matugen Setup Script
# =============================================================================
# This script manages the Catppuccin theme for OBS Studio with matugen integration
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
readonly OBS_CONFIG_DIR="$HOME/.config/obs-studio"
readonly OBS_THEMES_DIR="$OBS_CONFIG_DIR/themes"

# Check if OBS Studio is installed
check_obs_installed() {
	if command -v obs &>/dev/null; then
		return 0
	elif [[ -d "/usr/bin/obs-studio" ]] || [[ -d "/opt/obs-studio" ]]; then
		return 0
	else
		return 1
	fi
}

# Show setup instructions
show_instructions() {
	echo "📋 SETUP INSTRUCTIONS:"
	echo "1. Open OBS Studio"
	echo "2. Go to: File → Settings → General → Theme"
	echo "3. Select 'Catppuccin' theme from the dropdown menu"
	echo "4. Click 'Apply' to activate the theme"
	echo ""

	echo "🎨 THEME INFORMATION:"
	echo "   Theme: Catppuccin"
	echo "   Color Scheme: matugen (automatic)"
	echo "   Integration: Automatic color generation"
	echo ""

	echo "🔄 COLOR GENERATION:"
	echo "   - Run 'matugen' to generate colors"
	echo "   - OBS theme colors will update automatically"
	echo "   - Colors sync with your system theme"
	echo ""

	echo "📁 CONFIGURATION FILES:"
	echo "   - Theme: ~/.config/obs-studio/themes/matugen.obt"
	echo "   - Colors: ~/.config/matugen/generated/obs-studio.ovt"
	echo ""
}

# Edit OBS configuration file
edit_obs_config() {
	local obs_config="$OBS_CONFIG_DIR/global.ini"

	if [[ -f "$obs_config" ]]; then
		log_info "Updating OBS configuration..."

		# Check if [Appearance] section exists
		if ! grep -q "^\[Appearance\]" "$obs_config"; then
			echo -e "\n[Appearance]" >>"$obs_config"
		fi

		# Add or update Theme setting
		if grep -q "^Theme=" "$obs_config"; then
			# Update existing Theme setting
			sed -i 's|^Theme=.*|Theme=com.obsproject.Catppuccin.Mocha|' "$obs_config"
		else
			# Add Theme setting to [Appearance] section
			sed -i '/^\[Appearance\]/a Theme=com.obsproject.Catppuccin.Mocha' "$obs_config"
		fi

		log_success "OBS theme configuration updated"
	else
		log_warning "OBS configuration file not found. Please run OBS Studio first to create the configuration."
		log_info "Manual theme selection required: go to File → Settings → General → Theme"
	fi
}

# Comment out OBS theme
comment_obs_theme() {
	local obs_config="$OBS_CONFIG_DIR/global.ini"

	if [[ -f "$obs_config" ]]; then
		log_info "Commenting out OBS theme..."

		# Comment out Theme line
		if grep -q "^Theme=" "$obs_config"; then
			sed -i 's|^Theme=|#Theme=|' "$obs_config"
			log_success "Commented out OBS theme in configuration"
		else
			log_warning "No Theme setting found to comment out"
		fi
	else
		log_warning "OBS configuration file not found"
	fi
}

# Reset OBS config theme to default
reset_obs_theme() {
	local obs_config="$OBS_CONFIG_DIR/global.ini"

	if [[ -f "$obs_config" ]]; then
		log_info "Resetting OBS theme to default..."

		# Remove or comment out Theme line
		if grep -q "^Theme=" "$obs_config"; then
			sed -i '/^Theme=/d' "$obs_config"
		elif grep -q "^#Theme=" "$obs_config"; then
			sed -i '/^#Theme=/d' "$obs_config"
		fi

		log_success "Reset OBS theme to default"
	else
		log_warning "OBS configuration file not found"
	fi
}

# Action handlers
handle_uninstall() {
	log_info "Uninstalling OBS Studio Catppuccin theme..."

	# Remove theme files
	if [[ -d "$OBS_THEMES_DIR" ]]; then
		rm -f "$OBS_THEMES_DIR"/*matugen*.obt
		rm -f "$OBS_THEMES_DIR"/*catppuccin*.obt
		log_success "Removed theme files"
	else
		log_warning "OBS themes directory not found"
	fi

	# Reset OBS config theme to default
	reset_obs_theme

	log_success "OBS Studio Catppuccin theme uninstalled!"
	log_info "Restart OBS Studio to see the changes."
}

handle_on() {
	log_info "Enabling OBS Studio Catppuccin theme..."

	if check_obs_installed; then
		log_success "OBS Studio found"
		show_instructions
		log_success "Catppuccin theme enabled! Follow the instructions above to apply in OBS Studio."
	else
		log_error "OBS Studio not found - please install OBS Studio first"
		exit 1
	fi
}

handle_off() {
	log_info "Disabling OBS Studio Catppuccin theme..."

	# Comment out theme in config file
	comment_obs_theme

	log_success "OBS Studio Catppuccin theme disabled!"
	log_info "Restart OBS Studio to see the changes."
}

handle_install() {
	log_info "Installing OBS Studio Catppuccin theme..."

	if ! check_obs_installed; then
		log_error "OBS Studio not found - please install OBS Studio first"
		exit 1
	fi

	log_success "OBS Studio found"

	# Create themes directory if it doesn't exist
	mkdir -p "$OBS_THEMES_DIR"

	# Edit OBS configuration file
	edit_obs_config

	# Check if matugen is available
	if command -v matugen &>/dev/null; then
		log_success "Matugen found - color generation ready"
	else
		log_warning "Matugen not found - install matugen for automatic color generation"
	fi

	show_instructions

	log_success "OBS Studio Catppuccin theme setup complete!"
	log_info "Theme has been configured. Restart OBS Studio to see the changes."
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
