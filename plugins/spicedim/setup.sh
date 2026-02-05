#!/bin/bash

# =============================================================================
# SpiceDim Setup Script
# =============================================================================
# This script manages the Spicetify dim theme with matugen color scheme
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

# Check if spicetify is available
check_spicetify() {
	if ! command -v spicetify &>/dev/null; then
		log_error "Spicetify not found. Please install spicetify first."
		return 1
	fi
	return 0
}

# Apply theme configuration
apply_theme() {
	if ! check_spicetify; then
		return 1
	fi

	log_info "Setting Spicetify theme to dim..."
	spicetify config current_theme dim

	log_info "Setting color scheme to matugen..."
	spicetify config color_scheme matugen

	log_info "Applying Spicetify changes..."
	spicetify apply

	log_success "Spicetify dim theme with matugen colors configured!"
}

# Reset theme to default
reset_theme() {
	if ! check_spicetify; then
		return 1
	fi

	log_info "Resetting Spicetify theme to default..."
	spicetify config current_theme ""
	spicetify config color_scheme ""
	spicetify apply

	log_success "Spicetify theme reset to default!"
}

# Complete spicetify reset
complete_reset() {
	if ! check_spicetify; then
		return 1
	fi

	log_info "Performing complete Spicetify reset..."

	# Reset theme and color scheme
	spicetify config current_theme ""
	spicetify config color_scheme ""

	# Clear spicetify cache
	spicetify clear-cache >/dev/null 2>&1 || true

	# Apply changes
	spicetify apply

	log_success "Complete Spicetify reset performed!"
}

# Action handlers
handle_uninstall() {
	log_info "Uninstalling SpiceDim theme..."
	complete_reset
	log_success "SpiceDim theme uninstalled!"
}

handle_on() {
	log_info "Enabling SpiceDim theme..."
	apply_theme
}

handle_off() {
	log_info "Disabling SpiceDim theme..."
	reset_theme
}

handle_install() {
	log_info "Installing SpiceDim theme..."
	apply_theme
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
