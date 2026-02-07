#!/bin/bash

# =============================================================================
# DimFox Setup Script
# =============================================================================
# This script manages the TextFox Firefox theme installation
# =============================================================================

set -euo pipefail
shopt -s inherit_errexit

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
readonly TEXTFOX_DIR="$HOME/textfox-rounded"

# Action handlers
handle_uninstall() {
	log_info "Uninstalling TextFox theme..."

	if [[ -d "$TEXTFOX_DIR" ]]; then
		rm -rf "$TEXTFOX_DIR"
		log_success "Removed TextFox directory"
	else
		log_warning "TextFox directory not found"
	fi

	# Launch Firefox for manual refresh
	log_info "Launching Firefox support page for manual refresh..."
	log_warning "Please click 'Refresh Firefox...' button to completely remove theme changes"

	if command -v firefox &>/dev/null; then
		firefox "about:support" &
	elif command -v firefox-developer-edition &>/dev/null; then
		firefox-developer-edition "about:support" &
	else
		log_error "Firefox not found. Please manually open about:support and refresh Firefox."
	fi

	log_success "TextFox theme uninstalled! Please refresh Firefox to complete removal."
}

handle_on() {
	log_info "Enabling TextFox theme..."

	if [[ -d "$TEXTFOX_DIR" ]]; then
		cd "$TEXTFOX_DIR"
		if [[ -f "tf-install.sh" ]]; then
			bash tf-install.sh
			log_success "TextFox theme enabled!"
		else
			log_error "tf-install.sh not found"
			exit 1
		fi
	else
		log_error "TextFox directory not found. Please install first."
		exit 1
	fi
}

handle_off() {
	log_info "Disabling TextFox theme..."
	# TextFox doesn't have a specific disable mechanism
	# This would typically involve removing Firefox profile modifications
	log_warning "TextFox theme disable not implemented - theme remains active"
}

handle_install() {
	log_info "Installing TextFox theme..."

	# Check if directory exists and remove it first
	if [[ -d "$TEXTFOX_DIR" ]]; then
		log_info "Removing existing TextFox directory..."
		rm -rf "$TEXTFOX_DIR"
	fi

	# Clone the textfox-rounded repository
	git clone https://github.com/dim-ghub/textfox-rounded.git "$TEXTFOX_DIR"

	# Change into the cloned directory
	cd "$TEXTFOX_DIR"

	# Run the installation script
	if [[ -f "tf-install.sh" ]]; then
		sh tf-install.sh
		log_success "TextFox theme installed successfully!"
	else
		log_error "tf-install.sh not found in repository"
		exit 1
	fi
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
