#!/bin/bash

# =============================================================================
# Fastfetch Dynamic Logo Setup Script
# =============================================================================
# This script automates the setup of fastfetch with dynamic logo generation
# using the logogen.sh script for color-themed icons.
# =============================================================================

set -euo pipefail

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
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly FASTFETCH_DIR="$HOME/.config/fastfetch"
readonly FASTFETCH_SCRIPTS_DIR="$HOME/.config/fastfetch/scripts"
readonly ZSHRC="$HOME/.zshrc"

# Check if required scripts exist in fastfetch scripts directory
check_scripts() {
	if [[ ! -f "$FASTFETCH_SCRIPTS_DIR/logogen.sh" ]]; then
		log_error "logogen.sh not found in $FASTFETCH_SCRIPTS_DIR"
		log_info "Please ensure logogen.sh is installed in ~/.config/fastfetch/scripts/"
		exit 1
	fi

	if [[ ! -f "$FASTFETCH_SCRIPTS_DIR/fastfetch.sh" ]]; then
		log_error "fastfetch.sh not found in $FASTFETCH_SCRIPTS_DIR"
		log_info "Please ensure fastfetch.sh is installed in ~/.config/fastfetch/scripts/"
		exit 1
	fi
}

# Check dependencies
check_dependencies() {
	log_info "Checking dependencies..."

	local deps=("fastfetch" "python3" "pil" "numpy")
	local missing=()

	# Check fastfetch
	if ! command -v fastfetch &>/dev/null; then
		missing+=("fastfetch")
	fi

	# Check python3
	if ! command -v python3 &>/dev/null; then
		missing+=("python3")
	fi

	# Check Python modules
	if ! python3 -c "import PIL, numpy" &>/dev/null; then
		missing+=("python3-pil python3-numpy")
	fi

	if [[ ${#missing[@]} -gt 0 ]]; then
		log_error "Missing dependencies: ${missing[*]}"
		log_info "Install them with: sudo pacman -S ${missing[*]}"
		exit 1
	fi

	log_success "All dependencies found"
}

# Update fastfetch config
update_config() {
	log_info "Updating fastfetch configuration..."

	local config_file="$FASTFETCH_DIR/config.jsonc"

	# Create config if it doesn't exist
	if [[ ! -f "$config_file" ]]; then
		log_warning "No existing fastfetch config found. Creating default config..."
		cat >"$config_file" <<'EOF'
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {
        "source": "$FASTFETCH_LOGO",
        "type": "kitty",
        "height": 10,
        "padding": {
            "top": 1
        }
    },
    "display": {
        "separator": " "
    },
    "modules": [
        "title",
        "separator",
        "os",
        "kernel",
        "uptime",
        "memory",
        "cpu",
        "gpu",
        "disk",
        "localip",
        "colors"
    ]
}
EOF
	else
		# Update existing config
		log_info "Updating existing fastfetch config..."
		if grep -q '"source":' "$config_file"; then
			# Replace existing source
			sed -i 's|"source": "[^"]*"|"source": "$FASTFETCH_LOGO"|g' "$config_file"
		else
			# Add source to logo section
			sed -i '/"logo": {/,/}/ s|{|{\n        "source": "$FASTFETCH_LOGO",|' "$config_file"
		fi
	fi

	log_success "Fastfetch configuration updated"
}

# Update zshrc
update_zshrc() {
	log_info "Updating .zshrc..."

	local needs_reload=false

	# Check if PATH already includes fastfetch scripts directory
	if ! grep -q "$FASTFETCH_SCRIPTS_DIR" "$ZSHRC"; then
		echo "" >>"$ZSHRC"
		echo "# Fastfetch wrapper" >>"$ZSHRC"
		echo "export PATH=\"$FASTFETCH_SCRIPTS_DIR:\$PATH\"" >>"$ZSHRC"
		log_success "Added fastfetch scripts directory to PATH"
		needs_reload=true
	else
		log_info "PATH already includes fastfetch scripts directory"
	fi

	# Check if alias already exists
	if ! grep -q "alias fastfetch=" "$ZSHRC" || ! grep -q "fastfetch.sh" "$ZSHRC"; then
		echo "alias fastfetch='fastfetch.sh'" >>"$ZSHRC"
		log_success "Added fastfetch alias"
		needs_reload=true
	else
		log_info "Fastfetch alias already exists"
	fi

	if [[ "$needs_reload" == true ]]; then
		log_warning "You'll need to reload your .zshrc (run: source ~/.zshrc) or open a new terminal"
	fi
}

# Test the setup
test_setup() {
	log_info "Testing the setup..."

	# Test logogen script
	if [[ -f "$FASTFETCH_SCRIPTS_DIR/logogen.sh" ]]; then
		if output="$("$FASTFETCH_SCRIPTS_DIR/logogen.sh" 2>/dev/null)"; then
			log_success "logogen.sh working: $output"
		else
			log_error "logogen.sh failed"
			return 1
		fi
	else
		log_error "logogen.sh not found"
		return 1
	fi

	# Test wrapper script
	if [[ -f "$FASTFETCH_SCRIPTS_DIR/fastfetch.sh" ]]; then
		log_success "fastfetch.sh wrapper found"
	else
		log_error "fastfetch.sh wrapper not found"
		return 1
	fi

	log_success "Setup test completed successfully"
}

# Main setup
main() {
	log_info "Starting fastfetch dynamic logo setup..."

	check_scripts
	check_dependencies
	update_config
	update_zshrc
	test_setup

	echo ""
	log_success "Setup completed!"
	echo ""
	log_info "Usage:"
	echo "  1. Reload your shell: source ~/.zshrc"
	echo "  2. Run: fastfetch"
	echo ""
	log_info "The fastfetch command will now use dynamic logo generation"
	log_info "based on your current matugen color scheme."
}

# Run main function
main "$@"
