#!/usr/bin/env bash

# =============================================================================
# Nightfall Plugin Manager TUI
# =============================================================================
# Target: Arch Linux / Plugin Management
# Description: Interactive TUI to manage Nightfall plugins and configurations.
# =============================================================================

set -euo pipefail

# CRITICAL FIX: The "Locale Bomb"
# Force standard C locale for numeric operations.
# This prevents awk from outputting commas (0,5) in non-US locales,
# which would corrupt the config file.
export LC_NUMERIC=C

# =============================================================================
# ▼ USER CONFIGURATION (EDIT THIS SECTION) ▼
# =============================================================================

readonly NIGHTFALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly HOME_CONFIG="$HOME/.config"
readonly APP_TITLE="Nightfall Plugin Manager"
readonly APP_VERSION="v1.8"
readonly PLUGIN_CACHE_FILE="$HOME/.cache/nightfall_installed_plugins.txt"

# Dimensions & Layout
declare -ri MAX_DISPLAY_ROWS=12 # Rows of items to show before scrolling
declare -ri BOX_INNER_WIDTH=76  # Width of the UI box
declare -ri ITEM_START_ROW=5    # Row index where items begin rendering
declare -ri ADJUST_THRESHOLD=40 # X-pos threshold for mouse click adjustment
declare -ri ITEM_PADDING=32     # Text padding for labels

readonly -a TABS=("Plugins" "Installed")

# =============================================================================
# ▲ END OF USER CONFIGURATION ▲
# =============================================================================

# --- Pre-computed Constants ---
declare _H_LINE_BUF
printf -v _H_LINE_BUF '%*s' "$BOX_INNER_WIDTH" ''
readonly H_LINE="${_H_LINE_BUF// /─}"

# --- ANSI Constants ---
readonly C_RESET=$'\033[0m'
readonly C_CYAN=$'\033[1;36m'
readonly C_GREEN=$'\033[1;32m'
readonly C_MAGENTA=$'\033[1;35m'
readonly C_RED=$'\033[1;31m'
readonly C_WHITE=$'\033[1;37m'
readonly C_GREY=$'\033[1;30m'
readonly C_YELLOW=$'\033[1;33m'
readonly C_BLUE=$'\033[1;34m'
readonly C_INVERSE=$'\033[7m'
readonly CLR_EOL=$'\033[K'
readonly CLR_EOS=$'\033[J'
readonly CLR_SCREEN=$'\033[2J'
readonly CURSOR_HOME=$'\033[H'
readonly CURSOR_HIDE=$'\033[?25l'
readonly CURSOR_SHOW=$'\033[?25h'
readonly MOUSE_ON=$'\033[?1000h\033[?1002h\033[?1006h'
readonly MOUSE_OFF=$'\033[?1000l\033[?1002l\033[?1006l'

# Timeout for reading escape sequences (in seconds)
readonly ESC_READ_TIMEOUT=0.02

# --- State Management ---
declare -i SELECTED_ROW=0
declare -i CURRENT_TAB=0
declare -i SCROLL_OFFSET=0
declare -ri TAB_COUNT=${#TABS[@]}
declare -a TAB_ZONES=()
declare ORIGINAL_STTY=""

# --- Data Structures ---
declare -A PLUGIN_INFO # plugin_name -> "title|description|installed"
declare -a AVAILABLE_PLUGINS=() INSTALLED_PLUGINS=()

# Provisioned Tab Containers (0-9) to avoid sparse array errors
# shellcheck disable=SC2034
declare -a TAB_ITEMS_0=() TAB_ITEMS_1=() TAB_ITEMS_2=() TAB_ITEMS_3=() TAB_ITEMS_4=()
# shellcheck disable=SC2034
declare -a TAB_ITEMS_5=() TAB_ITEMS_6=() TAB_ITEMS_7=() TAB_ITEMS_8=() TAB_ITEMS_9=()

# --- System Helpers ---

log_err() {
	printf '%s[ERROR]%s %s\n' "$C_RED" "$C_RESET" "$1" >&2
}

log_warn() {
	printf '%s[WARN]%s %s\n' "$C_MAGENTA" "$C_RESET" "$1" >&2
}

# --- Cache Functions ---

read_plugin_cache() {
	if [[ ! -f "$PLUGIN_CACHE_FILE" ]]; then
		return 1
	fi

	local cache_version
	cache_version=$(head -n1 "$PLUGIN_CACHE_FILE" 2>/dev/null || echo "invalid")
	if [[ "$cache_version" != "nightfall_v1" ]]; then
		return 1
	fi

	local cached_plugins
	cached_plugins=$(tail -n +2 "$PLUGIN_CACHE_FILE" 2>/dev/null || echo "")
	if [[ -z "$cached_plugins" ]]; then
		return 1
	fi

	# Return only non-empty lines
	echo "$cached_plugins" | grep -v '^$'
	return 0
}

write_plugin_cache() {
	local installed_plugins="$1"

	mkdir -p "$(dirname "$PLUGIN_CACHE_FILE")"
	cat >"$PLUGIN_CACHE_FILE" <<EOF
nightfall_v1
$installed_plugins
EOF
}

is_plugin_cached_installed() {
	local plugin_name="$1"
	local cache_output
	cache_output=$(read_plugin_cache) || return 1

	echo "$cache_output" | grep -q "^$plugin_name$"
}

add_plugin_to_cache() {
	local plugin_name="$1"
	local cache_output
	cache_output=$(read_plugin_cache) || cache_output=""

	# Check if plugin is already in cache
	if echo "$cache_output" | grep -q "^$plugin_name$"; then
		return 0
	fi

	# Add plugin to cache, ensuring no duplicates
	local temp_file="${PLUGIN_CACHE_FILE}.tmp"
	{
		echo "nightfall_v1"
		echo "$cache_output"
		echo "$plugin_name"
	} | grep -v '^$' | tail -n +2 | sort -u | awk 'BEGIN{print "nightfall_v1"} {print}' >"$temp_file" && mv "$temp_file" "$PLUGIN_CACHE_FILE"
}

remove_plugin_from_cache() {
	local plugin_name="$1"
	local cache_output
	cache_output=$(read_plugin_cache) || return 1

	echo "$cache_output" | grep -v "^$plugin_name$" >"$PLUGIN_CACHE_FILE.tmp"
	write_plugin_cache "$(cat "$PLUGIN_CACHE_FILE.tmp")"
	rm -f "$PLUGIN_CACHE_FILE.tmp"
}

clear_plugin_cache() {
	rm -f "$PLUGIN_CACHE_FILE"
}

validate_cache() {
	local cache_output
	cache_output=$(read_plugin_cache) || return 1

	local valid_plugins=""
	local needs_update=false

	# Check each cached plugin - cache takes precedence over filesystem checks
	while IFS= read -r plugin_name; do
		if [[ -n "$plugin_name" ]]; then
			# Cache takes precedence - if it's in cache, consider it installed
			valid_plugins+="${valid_plugins:+$'\n'}$plugin_name"
		fi
	done <<<"$cache_output"

	# Update cache if validation found issues
	if [[ "$needs_update" == "true" ]]; then
		write_plugin_cache "$valid_plugins"
	fi
}

cleanup() {
	# Restore terminal state (Mouse, Cursor, Colors)
	printf '%s%s%s' "$MOUSE_OFF" "$CURSOR_SHOW" "$C_RESET"

	# Robustly restore original stty settings
	if [[ -n "${ORIGINAL_STTY:-}" ]]; then
		stty "$ORIGINAL_STTY" 2>/dev/null || :
	fi

	printf '\n'
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# --- Plugin Management Functions ---

get_available_plugins() {
	AVAILABLE_PLUGINS=()
	TAB_ITEMS_0=()
	TAB_ITEMS_1=()

	# Validate cache to detect manually removed plugins
	validate_cache || true

	for dir in "$NIGHTFALL_DIR/plugins"/*/; do
		if [[ -d "$dir" && -f "${dir}info" && "$(basename "$dir")" != "arch_iso_scripts" ]]; then
			local plugin_name
			plugin_name=$(basename "$dir")
			AVAILABLE_PLUGINS+=("$plugin_name")
			TAB_ITEMS_0+=("$plugin_name")

			# Read plugin info
			local info_file="$dir/info"
			if [[ -f "$info_file" ]]; then
				local title description
				title=$(sed -n '1s/^#\s*//p' "$info_file")
				description=$(sed -n '3,$p' "$info_file" | tr '\n' ' ')
				PLUGIN_INFO["$plugin_name"]="$title|$description|false"
			fi
		fi
	done

	# Check installed status using cache first
	for plugin in "${AVAILABLE_PLUGINS[@]}"; do
		local plugin_dir="$NIGHTFALL_DIR/plugins/$plugin"
		local config_dir="$plugin_dir/.config"

		if [[ -d "$config_dir" ]]; then
			local is_installed=false

			# Check cache first
			if is_plugin_cached_installed "$plugin"; then
				is_installed=true
			else
				# Fallback to filesystem check if cache miss
				local filesystem_check=true
				for item in "$config_dir"/*; do
					local item_name
					item_name=$(basename "$item")
					if [[ "$item_name" == "matugen" && -d "$item" ]]; then
						# Check matugen config.toml content
						local plugin_config="$item/config.toml"
						local user_config="$HOME_CONFIG/matugen/config.toml"
						if [[ -f "$plugin_config" && -f "$user_config" ]]; then
							if ! grep -qF "$(cat "$plugin_config")" "$user_config"; then
								filesystem_check=false
								break
							fi
						else
							filesystem_check=false
							break
						fi
					elif [[ -d "$item" ]]; then
						local target_dir="$HOME_CONFIG/$item_name"
						if [[ ! -d "$target_dir" ]]; then
							filesystem_check=false
							break
						fi
					elif [[ -f "$item" ]]; then
						local target_file="$HOME_CONFIG/$item_name"
						if [[ ! -f "$target_file" ]]; then
							filesystem_check=false
							break
						fi
					fi
				done

				# Cache takes precedence - if cache says installed, trust it
				if is_plugin_cached_installed "$plugin"; then
					is_installed=true
				elif [[ "$filesystem_check" == "true" ]]; then
					is_installed=true
					# Update cache with filesystem verification result
					add_plugin_to_cache "$plugin"
				fi
			fi

			if [[ "$is_installed" == "true" ]]; then
				PLUGIN_INFO["$plugin"]=$(echo "${PLUGIN_INFO[$plugin]}" | sed 's/|false$/|true/')
				TAB_ITEMS_1+=("$plugin")
			fi
		else
			# Cache takes precedence over filesystem checks
			if is_plugin_cached_installed "$plugin"; then
				PLUGIN_INFO["$plugin"]=$(echo "${PLUGIN_INFO[$plugin]}" | sed 's/|false$/|true/')
				TAB_ITEMS_1+=("$plugin")
			fi
		fi
	done
}

get_plugin_details() {
	local plugin_name="$1"
	local plugin_dir="$NIGHTFALL_DIR/plugins/$plugin_name"

	echo "Plugin: ${C_WHITE}$plugin_name${C_RESET}"
	echo "Directory: ${C_GREY}$plugin_dir${C_RESET}"
	echo ""

	# Show info file content
	local info_file="$plugin_dir/info"
	if [[ -f "$info_file" ]]; then
		echo "${C_CYAN}Plugin Information:${C_RESET}"
		cat "$info_file"
		echo ""
	fi

	# Show config structure
	local config_dir="$plugin_dir/.config"
	if [[ -d "$config_dir" ]]; then
		echo "${C_CYAN}Configuration Files:${C_RESET}"
		find "$config_dir" -type f -o -type d | grep -v previews | sed 's|.*/|  |'
	fi
}

install_plugin() {
	local plugin_name="$1"
	local plugin_dir="$NIGHTFALL_DIR/plugins/$plugin_name"

	# Check if already installed
	local plugin_info="${PLUGIN_INFO[$plugin_name]}"
	IFS='|' read -r title description installed <<<"$plugin_info"
	local action="Installing"
	if [[ "$installed" == "true" ]]; then
		action="Reinstalling/Updating"
	fi

	# Show plugin details
	clear
	echo -e "${C_CYAN}${C_INVERSE} $action Plugin: $plugin_name ${C_RESET}"
	echo ""
	get_plugin_details "$plugin_name"
	echo ""

	if [[ "$installed" == "true" ]]; then
		echo -e "${C_YELLOW}Plugin is already installed. Press [Enter] to reinstall/update or [q] to cancel...${C_RESET}"
	else
		echo -e "${C_YELLOW}Press [Enter] to continue installation or [q] to cancel...${C_RESET}"
	fi
	read -rsn1 key
	[[ "$key" == "q" || "$key" == "Q" ]] && return 0

	# Check if plugin directory exists
	if [[ ! -d "$plugin_dir" ]]; then
		echo -e "${C_RED}Error: Plugin directory not found: $plugin_dir${C_RESET}"
		read -p "Press Enter to continue..." -r
		return 1
	fi

	echo -e "${C_BLUE}Installing configuration files...${C_RESET}"

	# Install .config contents
	local config_dir="$plugin_dir/.config"
	if [[ -d "$config_dir" ]]; then
		for item in "$config_dir"/*; do
			local item_name
			item_name=$(basename "$item")

			if [[ "$item_name" == "matugen" ]]; then
				handle_matugen_config "$item"
			elif [[ "$item_name" == "previews" ]]; then
				# Skip previews folders
				echo -e "  ${C_GREY}⚠${C_RESET} Skipping previews folder"
				continue
			else
				# Copy other folders directly
				if [[ -d "$item" ]]; then
					echo -e "  ${C_GREEN}✓${C_RESET} Copying $item_name to ~/.config/"
					cp -r "$item" "$HOME_CONFIG/"
				elif [[ -f "$item" ]]; then
					echo -e "  ${C_GREEN}✓${C_RESET} Copying file $item_name to ~/.config/"
					cp "$item" "$HOME_CONFIG/"
				fi
			fi
		done
	fi

	# Run setup script if it exists
	local setup_script="$plugin_dir/setup.sh"
	if [[ -f "$setup_script" ]]; then
		echo -e "${C_BLUE}Running setup script...${C_RESET}"
		if bash -i "$setup_script"; then
			echo -e "  ${C_GREEN}✓${C_RESET} Setup script completed successfully"
		else
			echo -e "  ${C_RED}✗${C_RESET} Setup script failed"
			read -p "Press Enter to continue..." -r
			return 1
		fi
	fi

	if [[ "$installed" == "true" ]]; then
		echo -e "${C_GREEN}Plugin $plugin_name reinstalled/updated successfully!${C_RESET}"
	else
		echo -e "${C_GREEN}Plugin $plugin_name installed successfully!${C_RESET}"
	fi

	# Update cache instead of refreshing all plugins
	add_plugin_to_cache "$plugin_name"

	# Execute theme refresh after installation
	if [[ -f "$HOME/user_scripts/theme_matugen/theme_ctl.sh" ]]; then
		echo -e "${C_BLUE}Refreshing theme...${C_RESET}"
		bash "$HOME/user_scripts/theme_matugen/theme_ctl.sh" refresh
	fi

	read -p "Press Enter to continue..." -r
}

get_plugin_toggle_status() {
	local plugin_name="$1"
	local plugin_dir="$NIGHTFALL_DIR/plugins/$plugin_name"
	local matugen_config="$HOME_CONFIG/matugen/config.toml"
	local matugen_plugin_config="$plugin_dir/.config/matugen/config.toml"

	# Quick check if plugin has matugen config
	[[ ! -f "$matugen_plugin_config" ]] && return 1

	# Extract template name more efficiently
	local template_name
	template_name=$(grep -m1 '^\[templates\.' "$matugen_plugin_config" 2>/dev/null | sed 's/^\[templates\.//; s/\]$//')
	[[ -z "$template_name" ]] && return 1

	# Simple grep check for enabled status
	if grep -q "^\[templates\.$template_name\]" "$matugen_config" 2>/dev/null; then
		echo "ON"
	else
		echo "OFF"
	fi
}

toggle_plugin() {
	local plugin_name="$1"
	local plugin_dir="$NIGHTFALL_DIR/plugins/$plugin_name"
	local matugen_config="$HOME_CONFIG/matugen/config.toml"
	local matugen_plugin_config="$plugin_dir/.config/matugen/config.toml"

	# Check if plugin has matugen config
	if [[ ! -f "$matugen_plugin_config" ]]; then
		return 0
	fi

	# Extract template name
	local template_name
	template_name=$(grep -m1 '^\[templates\.' "$matugen_plugin_config" 2>/dev/null | sed 's/^\[templates\.//; s/\]$//')
	[[ -z "$template_name" ]] && return 0

	# Check if currently enabled
	local is_enabled=false
	if grep -q "^\[templates\.$template_name\]" "$matugen_config" 2>/dev/null; then
		is_enabled=true
	fi

	if [[ "$is_enabled" == "true" ]]; then
		# Turn off: comment out the block
		awk -v template="[templates.$template_name]" '
			$0 == template { 
				print "#" $0
				in_block=1
				next 
			}
			in_block && /^\[.*\]/ { 
				in_block=0
				print
				next
			}
			in_block { 
				print "#" $0
				next 
			}
			{ print }
		' "$matugen_config" >"$matugen_config.tmp" && mv "$matugen_config.tmp" "$matugen_config"

		# Run setup script with --off flag if available
		local setup_script="$plugin_dir/setup.sh"
		if [[ -f "$setup_script" ]]; then
			bash "$setup_script" --off 2>/dev/null || true
		fi
	else
		# Turn on: uncomment the block
		awk -v template="[templates.$template_name]" '
			/^#/ && $0 == "#" template { 
				print substr($0, 2)
				in_block=1
				next 
			}
			in_block && /^#/ && !/^\s*$/ { 
				print substr($0, 2)
				next 
			}
			in_block && /^\[.*\]/ { 
				in_block=0
				print
				next
			}
			{ print }
		' "$matugen_config" >"$matugen_config.tmp" && mv "$matugen_config.tmp" "$matugen_config"

		# Run setup script with --on flag if available
		local setup_script="$plugin_dir/setup.sh"
		if [[ -f "$setup_script" ]]; then
			bash "$setup_script" --on 2>/dev/null || true
		fi
	fi

	# Execute theme refresh silently
	if [[ -f "$HOME/user_scripts/theme_matugen/theme_ctl.sh" ]]; then
		bash "$HOME/user_scripts/theme_matugen/theme_ctl.sh" refresh >/dev/null 2>&1
	fi
}

uninstall_plugin() {
	local plugin_name="$1"
	local plugin_dir="$NIGHTFALL_DIR/plugins/$plugin_name"
	local matugen_config="$HOME_CONFIG/matugen/config.toml"
	local matugen_plugin_config="$plugin_dir/.config/matugen/config.toml"

	# Remove from cache
	remove_plugin_from_cache "$plugin_name"

	# Remove block from matugen config if plugin has matugen config
	if [[ -f "$matugen_plugin_config" ]]; then
		# Extract template name
		local template_name
		template_name=$(grep -m1 '^\[templates\.' "$matugen_plugin_config" 2>/dev/null | sed 's/^\[templates\.//; s/\]$//')

		if [[ -n "$template_name" ]]; then
			# Remove the entire block from matugen config
			awk -v template="[templates.$template_name]" '
				$0 == template { 
					in_block=1
					skip_block=1
					next 
				}
				skip_block && /^\[.*\]/ { 
					skip_block=0
					next
				}
				skip_block { next }
				{ print }
			' "$matugen_config" >"$matugen_config.tmp" && mv "$matugen_config.tmp" "$matugen_config"
		fi
	fi

	# Remove files using the same checks as filesystem validation
	local config_dir="$plugin_dir/.config"
	if [[ -d "$config_dir" ]]; then
		for item in "$config_dir"/*; do
			local item_name
			item_name=$(basename "$item")

			if [[ "$item_name" == "matugen" && -d "$item" ]]; then
				# Remove matugen templates (not config.toml)
				local template_dir="$HOME_CONFIG/matugen/templates"
				if [[ -d "$template_dir" ]]; then
					for template_file in "$item"/*; do
						local template_name=$(basename "$template_file")
						rm -f "$template_dir/$template_name"
					done
					# Remove template directory if empty
					rmdir "$template_dir" 2>/dev/null || true
				fi
			elif [[ -d "$item" ]]; then
				# Remove only the specific files/dirs from plugin, not all contents
				local target_dir="$HOME_CONFIG/$item_name"
				if [[ -d "$target_dir" ]]; then
					# Remove each item that exists in both plugin and target
					for plugin_item in "$item"/*; do
						local plugin_item_name=$(basename "$plugin_item")
						if [[ -e "$target_dir/$plugin_item_name" ]]; then
							if [[ -d "$plugin_item" ]]; then
								rm -rf "$target_dir/$plugin_item_name"
							else
								rm -f "$target_dir/$plugin_item_name"
							fi
						fi
					done
					# Remove directory if empty
					rmdir "$target_dir" 2>/dev/null || true
				fi
			elif [[ -f "$item" ]]; then
				# Remove file from user config
				local target_file="$HOME_CONFIG/$item_name"
				if [[ -f "$target_file" ]]; then
					rm -f "$target_file"
				fi
			fi
		done
	fi

	# Call setup.sh with --uninstall if available
	if [[ -f "$plugin_dir/setup.sh" ]]; then
		bash "$plugin_dir/setup.sh" --uninstall
	fi

	# Execute theme refresh
	if [[ -f "$HOME/user_scripts/theme_matugen/theme_ctl.sh" ]]; then
		bash "$HOME/user_scripts/theme_matugen/theme_ctl.sh" refresh >/dev/null 2>&1
	fi
}

handle_matugen_config() {
	local matugen_dir="$1"

	# Handle config.toml with smart merging
	local config_file="$matugen_dir/config.toml"
	local target_config="$HOME_CONFIG/matugen/config.toml"

	if [[ -f "$config_file" ]]; then
		echo -e "  ${C_GREEN}✓${C_RESET} Merging matugen config.toml"
		mkdir -p "$(dirname "$target_config")"
		smart_merge_matugen_config "$config_file" "$target_config"
	fi

	# Handle templates folder (copy if exists)
	local templates_dir="$matugen_dir/templates"
	if [[ -d "$templates_dir" ]]; then
		echo -e "  ${C_GREEN}✓${C_RESET} Copying matugen templates"
		mkdir -p "$HOME_CONFIG/matugen/templates"
		cp -r "$templates_dir"/* "$HOME_CONFIG/matugen/templates/"
	fi
}

smart_merge_matugen_config() {
	local plugin_config="$1"
	local target_config="$2"

	# Read the plugin config content
	local plugin_content
	plugin_content=$(cat "$plugin_config")

	# Extract the section title (first line that starts with [)
	local plugin_title
	plugin_title=$(echo "$plugin_content" | grep '^\[' | head -n1)

	# If no title found, just append normally
	if [[ -z "$plugin_title" ]]; then
		echo "$plugin_content" >>"$target_config"
		return 0
	fi

	# Check if target config exists and has the same section
	if [[ -f "$target_config" ]]; then
		# Check if the exact same content already exists
		# Extract existing section including the title
		local existing_section
		existing_section=$(awk -v section="$plugin_title" '
				BEGIN { found=0 }
				$0 == section { found=1; print; next }
				found && /^\[/ { exit }
				found { print }
			' "$target_config")

		# Normalize both for comparison (remove leading/trailing whitespace)
		local plugin_clean existing_clean
		plugin_clean=$(echo "$plugin_content" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$')
		existing_clean=$(echo "$existing_section" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' || true)

		if [[ "$plugin_clean" == "$existing_clean" ]]; then
			echo -e "    ${C_GREY}✓${C_RESET} Config already exists, skipping"
			return 0
		fi

		# If section doesn't exist at all, just append it
		if [[ -z "$existing_clean" ]]; then
			echo "" >>"$target_config"
			echo "$plugin_content" >>"$target_config"
			echo -e "    ${C_GREY}✓${C_RESET} Added new config section"
			return 0
		fi

		# Create temp file for the new config
		local temp_config
		temp_config=$(mktemp)

		# Read target config line by line
		local in_section=false
		local found_section=false
		local line_before_empty=false

		while IFS= read -r line || [[ -n "$line" ]]; do
			# Check if this is the start of the section we need to comment out
			if [[ "$line" == "$plugin_title" ]]; then
				in_section=true
				found_section=true
				# Comment out this line
				echo "# $line" >>"$temp_config"
				continue
			fi

			# If we're in the section, check if we've reached the next section
			if [[ "$in_section" == "true" ]]; then
				# If we hit a new section title, stop commenting
				if [[ "$line" =~ ^\[.*\]$ ]]; then
					in_section=false
					# Comment out the empty line before if it was empty
					if [[ "$line_before_empty" == "true" ]]; then
						echo "# " >>"$temp_config"
					fi
					echo "$line" >>"$temp_config"
				else
					# Comment out the line in the section
					echo "# $line" >>"$temp_config"
				fi
			else
				# Not in the section, copy as-is
				echo "$line" >>"$temp_config"
			fi

			# Track if the previous line was empty
			if [[ -z "$line" ]]; then
				line_before_empty=true
			else
				line_before_empty=false
			fi
		done <"$target_config"

		# Add the new plugin config at the end
		echo "" >>"$temp_config"
		echo "$plugin_content" >>"$temp_config"

		# Replace the target config
		mv "$temp_config" "$target_config"

		if [[ "$found_section" == "true" ]]; then
			echo -e "    ${C_YELLOW}✓${C_RESET} Commented out existing section and added new config"
		else
			echo -e "    ${C_GREY}✓${C_RESET} Added new config section"
		fi
	else
		# Target doesn't exist, just copy the plugin config
		echo "$plugin_content" >"$target_config"
		echo -e "    ${C_GREY}✓${C_RESET} Created new config file"
	fi
}

show_plugin_info() {
	local plugin_name
	if ((CURRENT_TAB == 0)); then
		plugin_name="${TAB_ITEMS_0[SELECTED_ROW]}"
	else
		plugin_name="${TAB_ITEMS_1[SELECTED_ROW]}"
	fi

	clear
	echo -e "${C_CYAN}${C_INVERSE} Plugin Information ${C_RESET}"
	echo ""
	get_plugin_details "$plugin_name"
	echo ""
	echo -e "${C_YELLOW}Press Enter to continue...${C_RESET}"
	read -r
}

# --- UI Rendering ---

draw_ui() {
	local buf="" pad_buf="" padded_item="" item val display
	local -i i current_col=3 zone_start len count pad_needed
	local -i visible_len left_pad right_pad
	local -i visible_start visible_end

	buf+="${CURSOR_HOME}"
	buf+="${C_MAGENTA}┌${H_LINE}┐${C_RESET}"$'\n'

	# Header - Dynamic Centering
	visible_len=$((${#APP_TITLE} + ${#APP_VERSION} + 1))
	left_pad=$(((BOX_INNER_WIDTH - visible_len) / 2))
	right_pad=$((BOX_INNER_WIDTH - visible_len - left_pad))

	printf -v pad_buf '%*s' "$left_pad" ''
	buf+="${C_MAGENTA}│${pad_buf}${C_WHITE}${APP_TITLE} ${C_CYAN}${APP_VERSION}${C_MAGENTA}"
	printf -v pad_buf '%*s' "$right_pad" ''
	buf+="${pad_buf}│${C_RESET}"$'\n'

	# Tab bar rendering
	local tab_line="${C_MAGENTA}│ "
	TAB_ZONES=()

	for ((i = 0; i < TAB_COUNT; i++)); do
		local name=${TABS[i]}
		len=${#name}
		zone_start=$current_col

		if ((i == CURRENT_TAB)); then
			tab_line+="${C_CYAN}${C_INVERSE} ${name} ${C_RESET}${C_MAGENTA}│ "
		else
			tab_line+="${C_GREY} ${name} ${C_MAGENTA}│ "
		fi

		TAB_ZONES+=("${zone_start}:$((zone_start + len + 1))")
		((current_col += len + 4)) || :
	done

	pad_needed=$((BOX_INNER_WIDTH - current_col + 2))
	if ((pad_needed > 0)); then
		printf -v pad_buf '%*s' "$pad_needed" ''
		tab_line+="${pad_buf}"
	fi
	tab_line+="${C_MAGENTA}│${C_RESET}"

	buf+="${tab_line}"$'\n'
	buf+="${C_MAGENTA}└${H_LINE}┘${C_RESET}"$'\n'

	# Items Rendering with scroll support
	# shellcheck disable=SC2178
	local -n items_ref="TAB_ITEMS_${CURRENT_TAB}"
	count=${#items_ref[@]}

	# Bounds checking & Scroll Calculation
	if ((count == 0)); then
		SELECTED_ROW=0
		SCROLL_OFFSET=0
	else
		((SELECTED_ROW < 0)) && SELECTED_ROW=0
		((SELECTED_ROW >= count)) && SELECTED_ROW=$((count - 1))

		# Auto-scroll to keep selection visible
		if ((SELECTED_ROW < SCROLL_OFFSET)); then
			SCROLL_OFFSET=$SELECTED_ROW
		elif ((SELECTED_ROW >= SCROLL_OFFSET + MAX_DISPLAY_ROWS)); then
			SCROLL_OFFSET=$((SELECTED_ROW - MAX_DISPLAY_ROWS + 1))
		fi

		# Clamp scroll offset
		((SCROLL_OFFSET < 0)) && SCROLL_OFFSET=0
		local -i max_scroll=$((count - MAX_DISPLAY_ROWS))
		((max_scroll < 0)) && max_scroll=0
		((SCROLL_OFFSET > max_scroll)) && SCROLL_OFFSET=$max_scroll
	fi

	visible_start=$SCROLL_OFFSET
	visible_end=$((SCROLL_OFFSET + MAX_DISPLAY_ROWS))
	((visible_end > count)) && visible_end=$count

	# Top Scroll Indicator
	if ((SCROLL_OFFSET > 0)); then
		buf+="${C_GREY}    ▲ (more above)${CLR_EOL}${C_RESET}"$'\n'
	else
		buf+="${CLR_EOL}"$'\n'
	fi

	# Render Visible Items
	for ((i = visible_start; i < visible_end; i++)); do
		item=${items_ref[i]}
		local plugin_info="${PLUGIN_INFO[$item]}"
		IFS='|' read -r title description installed <<<"$plugin_info"

		if ((CURRENT_TAB == 0)); then
			# Plugins tab - show status
			if [[ "$installed" == "true" ]]; then
				display="${C_GREEN}Installed${C_RESET}"
			else
				display="${C_GREY}Available${C_RESET}"
			fi
		else
			# Installed tab - show description
			display="${C_WHITE}${title}${C_RESET}"
		fi

		# Add toggle status for installed plugins with matugen configs
		if [[ "$installed" == "true" ]]; then
			local plugin_dir="$NIGHTFALL_DIR/plugins/$item"
			local matugen_plugin_config="$plugin_dir/.config/matugen/config.toml"

			if [[ -f "$matugen_plugin_config" ]]; then
				# Extract template name
				local template_name
				template_name=$(grep -m1 '^\[templates\.' "$matugen_plugin_config" 2>/dev/null | sed 's/^\[templates\.//; s/\]$//')

				if [[ -n "$template_name" ]]; then
					if grep -q "^\[templates\.$template_name\]" "$HOME_CONFIG/matugen/config.toml" 2>/dev/null; then
						display+=" ${C_GREEN}[ON]${C_RESET}"
					else
						display+=" ${C_RED}[OFF]${C_RESET}"
					fi
				fi
			fi
		fi

		printf -v padded_item "%-${ITEM_PADDING}s" "${title:0:$ITEM_PADDING}"

		if ((i == SELECTED_ROW)); then
			if ((CURRENT_TAB == 0)); then
				buf+="${C_CYAN} ➤ ${C_INVERSE}${padded_item}${C_RESET} : ${display}${CLR_EOL}"$'\n'
			else
				buf+="${C_CYAN} ➤ ${C_INVERSE}${padded_item}${C_RESET} : ${display}${CLR_EOL}"$'\n'
			fi
		else
			if ((CURRENT_TAB == 0)); then
				buf+="    ${padded_item} : ${display}${CLR_EOL}"$'\n'
			else
				buf+="    ${padded_item} : ${display}${CLR_EOL}"$'\n'
			fi
		fi
	done

	# Pad remaining rows to maintain stable height
	local -i rows_rendered=$((visible_end - visible_start))
	for ((i = rows_rendered; i < MAX_DISPLAY_ROWS; i++)); do
		buf+="${CLR_EOL}"$'\n'
	done

	# Bottom Scroll Indicator
	if ((visible_end < count)); then
		buf+="${C_GREY}    ▼ (more below)${CLR_EOL}${C_RESET}"$'\n'
	else
		buf+="${CLR_EOL}"$'\n'
	fi

	# Controls line
	local controls=""
	local nav=""
	if ((CURRENT_TAB == 0)); then
		controls="[Tab] Switch Tab  [Enter] Install  [i] Plugin Info  [q] Quit"
		nav="[↑/↓] Navigate  [←/→] Toggle"
	else
		controls="[Tab] Switch Tab  [u] Uninstall  [i] Plugin Info  [q] Quit"
		nav="[↑/↓] Navigate  [←/→] Toggle"
	fi

	buf+=$'\n'"${C_CYAN} ${controls}${C_RESET}${CLR_EOL}"$'\n'
	buf+="${C_CYAN} ${nav}${C_RESET}${CLR_EOL}"$'\n'"${CLR_EOS}"

	printf '%s' "$buf"
}

# --- Input Handling ---

navigate() {
	local -i dir=$1
	# shellcheck disable=SC2178
	local -n items_ref="TAB_ITEMS_${CURRENT_TAB}"
	local -i count=${#items_ref[@]}

	((count == 0)) && {
		SELECTED_ROW=0
		return 0
	}
	((SELECTED_ROW += dir)) || :

	# Wrap selection with bounds checking
	if ((SELECTED_ROW < 0)); then
		SELECTED_ROW=$((count - 1))
	elif ((SELECTED_ROW >= count)); then
		SELECTED_ROW=0
	fi
}

switch_tab() {
	local -i dir=${1:-1}

	((CURRENT_TAB += dir)) || :
	((CURRENT_TAB >= TAB_COUNT)) && CURRENT_TAB=0
	((CURRENT_TAB < 0)) && CURRENT_TAB=$((TAB_COUNT - 1))

	SELECTED_ROW=0
	SCROLL_OFFSET=0
}

set_tab() {
	local -i idx=$1

	if ((idx != CURRENT_TAB && idx >= 0 && idx < TAB_COUNT)); then
		CURRENT_TAB=$idx
		SELECTED_ROW=0
		SCROLL_OFFSET=0
	fi
}

handle_mouse() {
	local input=$1
	local -i button x y i
	local type zone start end

	# SGR Mouse Mode (1006) - handle both [< and [< variations
	if [[ $input == "[<"* || $input == "[<"* ]]; then
		# Parse SGR sequence: [0;10;5M or [0;10;5m or [<0;10;5M or [<0;10;5m
		local temp_input=${input#*[<} # Remove leading up to "[<"
		temp_input=${temp_input%[Mm]} # Remove trailing M or m
		IFS=';' read -r button x y <<<"$temp_input"
		type=${input: -1} # Get last character (M or m)

		# Only handle Button Press ('M'), ignore Release ('m')
		[[ $type != "M" ]] && return 0

		# Tab bar click detection (Row 3)
		if ((y == 3)); then
			for ((i = 0; i < TAB_COUNT; i++)); do
				zone=${TAB_ZONES[i]}
				start=${zone%%:*}
				end=${zone##*:}
				if ((x >= start && x <= end)); then
					set_tab "$i"
					return 0
				fi
			done
		fi

		# Item click detection (accounting for top indicator offset)
		# shellcheck disable=SC2178
		local -n items_ref="TAB_ITEMS_${CURRENT_TAB}"
		local -i count=${#items_ref[@]}
		local -i item_row_start=$((ITEM_START_ROW + 1))

		if ((y >= item_row_start && y < item_row_start + MAX_DISPLAY_ROWS)); then
			local -i clicked_idx=$((y - item_row_start + SCROLL_OFFSET))
			if ((clicked_idx >= 0 && clicked_idx < count)); then
				SELECTED_ROW=$clicked_idx
				if ((button == 0 && CURRENT_TAB == 0)); then
					# Left click on Plugins tab - install plugin
					install_plugin "${items_ref[SELECTED_ROW]}"
					get_available_plugins
				fi
			fi
		fi
	fi
}

# --- Main ---

main() {
	# Handle command line arguments
	case "${1:-}" in
	--clear-cache)
		clear_plugin_cache
		echo "Plugin cache cleared."
		exit 0
		;;
	--help | -h)
		echo "Usage: $0 [--clear-cache] [--help]"
		echo "  --clear-cache  Clear the plugin installation cache"
		echo "  --help, -h     Show this help message"
		exit 0
		;;
	esac

	# 1. Config Validation
	if [[ ! -d "$NIGHTFALL_DIR" ]]; then
		log_err "Nightfall directory not found: $NIGHTFALL_DIR"
		exit 1
	fi

	# 2. Initialization
	get_available_plugins

	# 3. Save Terminal State
	if command -v stty &>/dev/null; then
		ORIGINAL_STTY=$(stty -g 2>/dev/null) || ORIGINAL_STTY=""
	fi

	printf '%s%s%s%s' "$MOUSE_ON" "$CURSOR_HIDE" "$CLR_SCREEN" "$CURSOR_HOME"

	local key seq char

	# 4. Event Loop
	while true; do
		draw_ui

		# Safety: break on EOF to prevent 100% CPU loops
		IFS= read -rsn1 key || break

		# Debug: Show every key press
		printf "DEBUG: Key read: %q (ASCII: %d)\n" "$key" "'$key" >>/tmp/nightfall_debug.log

		# Handle Enter key that might be read as empty string (common with read -rsn1)
		if [[ -z "$key" ]]; then
			key=$'\n'
		fi

		if [[ $key == $'\x1b' ]]; then
			seq=""
			# Fast timeout for escape sequences
			while IFS= read -rsn1 -t "$ESC_READ_TIMEOUT" char; do
				seq+="$char"
			done

			# Handle empty sequence (plain Escape key)
			if [[ -z "$seq" ]]; then
				continue
			fi

			case $seq in
			'[Z') switch_tab -1 ;;      # Shift+Tab
			'[A' | 'OA') navigate -1 ;; # Arrow Up
			'[B' | 'OB') navigate 1 ;;  # Arrow Down
			'[C' | 'OC')                # Arrow Right - toggle plugin
				if ((CURRENT_TAB == 0)) && ((SELECTED_ROW < ${#TAB_ITEMS_0[@]})); then
					toggle_plugin "${TAB_ITEMS_0[SELECTED_ROW]}"
				elif ((CURRENT_TAB == 1)) && ((SELECTED_ROW < ${#TAB_ITEMS_1[@]})); then
					toggle_plugin "${TAB_ITEMS_1[SELECTED_ROW]}"
				fi
				;;
			'[D' | 'OD') # Arrow Left - toggle plugin
				if ((CURRENT_TAB == 0)) && ((SELECTED_ROW < ${#TAB_ITEMS_0[@]})); then
					toggle_plugin "${TAB_ITEMS_0[SELECTED_ROW]}"
				elif ((CURRENT_TAB == 1)) && ((SELECTED_ROW < ${#TAB_ITEMS_1[@]})); then
					toggle_plugin "${TAB_ITEMS_1[SELECTED_ROW]}"
				fi
				;;
			'[<'* | '['*'<'*) handle_mouse "$seq" ;;
			esac
		else
			case $key in
			k | K) navigate -1 ;;
			$'\t') switch_tab 1 ;;
			i | I) show_plugin_info ;;
			u | U) # Uninstall plugin
				if ((CURRENT_TAB == 1)) && ((SELECTED_ROW < ${#TAB_ITEMS_1[@]})); then
					uninstall_plugin "${TAB_ITEMS_1[SELECTED_ROW]}"
				fi
				;;
			$'\n' | $'\r') # Enter key (handle LF and CR)
				# Debug: Show we detected Enter key
				echo "DEBUG: Enter key detected, tab=$CURRENT_TAB, row=$SELECTED_ROW" >>/tmp/nightfall_debug.log
				if ((CURRENT_TAB == 0)) && ((SELECTED_ROW < ${#TAB_ITEMS_0[@]})); then
					install_plugin "${TAB_ITEMS_0[SELECTED_ROW]}"
					get_available_plugins
				elif ((CURRENT_TAB == 1)) && ((SELECTED_ROW < ${#TAB_ITEMS_1[@]})); then
					install_plugin "${TAB_ITEMS_1[SELECTED_ROW]}"
					get_available_plugins
				fi
				;;
			q | Q | $'\x03') break ;;
			*)
				# Debug: Show unknown keys
				printf "DEBUG: Unknown key: %q (ASCII: %d)\n" "$key" "'$key" >>/tmp/nightfall_debug.log
				;;
			esac
		fi
	done
}

main "$@"
