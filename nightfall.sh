#!/usr/bin/env bash

# =============================================================================
# Nightfall Plugin Manager TUI (v1.1)
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
readonly APP_VERSION="v1.1"

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

	for dir in "$NIGHTFALL_DIR"/*/; do
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

	# Check installed status
	for plugin in "${AVAILABLE_PLUGINS[@]}"; do
		local plugin_dir="$NIGHTFALL_DIR/$plugin"
		local config_dir="$plugin_dir/.config"

		if [[ -d "$config_dir" ]]; then
			local is_installed=true
			for item in "$config_dir"/*; do
				local item_name
				item_name=$(basename "$item")
				if [[ "$item_name" != "matugen" && -d "$item" ]]; then
					local target_dir="$HOME_CONFIG/$item_name"
					if [[ ! -d "$target_dir" ]]; then
						is_installed=false
						break
					fi
				fi
			done

			if [[ "$is_installed" == "true" ]]; then
				PLUGIN_INFO["$plugin_name"]=$(echo "${PLUGIN_INFO[$plugin_name]}" | sed 's/|false$/|true/')
				TAB_ITEMS_1+=("$plugin_name")
			fi
		fi
	done
}

get_plugin_details() {
	local plugin_name="$1"
	local plugin_dir="$NIGHTFALL_DIR/$plugin_name"

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
		find "$config_dir" -type f -o -type d | sed 's|.*/|  |'
	fi
}

install_plugin() {
	local plugin_name="$1"
	local plugin_dir="$NIGHTFALL_DIR/$plugin_name"

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

	read -p "Press Enter to continue..." -r

	# Update plugin info
	get_available_plugins
}

handle_matugen_config() {
	local matugen_dir="$1"

	# Handle config.toml (append if exists)
	local config_file="$matugen_dir/config.toml"
	local target_config="$HOME_CONFIG/matugen/config.toml"

	if [[ -f "$config_file" ]]; then
		echo -e "  ${C_GREEN}✓${C_RESET} Appending matugen config.toml"
		mkdir -p "$(dirname "$target_config")"
		cat "$config_file" >>"$target_config"
	fi

	# Handle templates folder (copy if exists)
	local templates_dir="$matugen_dir/templates"
	if [[ -d "$templates_dir" ]]; then
		echo -e "  ${C_GREEN}✓${C_RESET} Copying matugen templates"
		mkdir -p "$HOME_CONFIG/matugen/templates"
		cp -r "$templates_dir"/* "$HOME_CONFIG/matugen/templates/"
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

		printf -v padded_item "%-${ITEM_PADDING}s" "${title:0:$ITEM_PADDING}"

		if ((i == SELECTED_ROW)); then
			if ((CURRENT_TAB == 0)); then
				buf+="${C_CYAN} ➤ ${C_INVERSE}${padded_item}${C_RESET} : ${display}${CLR_EOL}"$'\n'
			else
				buf+="${C_CYAN} ➤ ${C_INVERSE}${padded_item}${C_RESET}${CLR_EOL}"$'\n'
			fi
		else
			if ((CURRENT_TAB == 0)); then
				buf+="    ${padded_item} : ${display}${CLR_EOL}"$'\n'
			else
				buf+="    ${padded_item}${CLR_EOL}"$'\n'
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
	if ((CURRENT_TAB == 0)); then
		controls="[Tab] Switch Tab  [Enter] Install  [i] Plugin Info  [↑/↓ j/k] Nav  [q] Quit"
	else
		controls="[Tab] Switch Tab  [i] Plugin Info  [↑/↓ j/k] Nav  [q] Quit"
	fi

	buf+=$'\n'"${C_CYAN} ${controls}${C_RESET}"$'\n'
	buf+="${C_CYAN} Directory: ${C_WHITE}${NIGHTFALL_DIR}${C_RESET}${CLR_EOL}${CLR_EOS}"

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
				fi
			fi
		fi
	fi
}

# --- Main ---

main() {
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
			'[<'* | '['*'<'*) handle_mouse "$seq" ;;
			esac
		else
			case $key in
			k | K) navigate -1 ;;
			j | J) navigate 1 ;;
			$'\t') switch_tab 1 ;;
			i | I) show_plugin_info ;;
			$'\n' | $'\r') # Enter key (handle LF and CR)
				# Debug: Show we detected Enter key
				echo "DEBUG: Enter key detected, tab=$CURRENT_TAB, row=$SELECTED_ROW" >>/tmp/nightfall_debug.log
				if ((CURRENT_TAB == 0)) && ((SELECTED_ROW < ${#TAB_ITEMS_0[@]})); then
					install_plugin "${TAB_ITEMS_0[SELECTED_ROW]}"
				elif ((CURRENT_TAB == 1)) && ((SELECTED_ROW < ${#TAB_ITEMS_1[@]})); then
					install_plugin "${TAB_ITEMS_1[SELECTED_ROW]}"
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
