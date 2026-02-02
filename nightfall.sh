#!/usr/bin/env bash

# =============================================================================
# Nightfall Plugin Manager TUI (v1.0)
# =============================================================================
# Target: Arch Linux / Plugin Management
# Description: Interactive TUI to manage Nightfall plugins and configurations.
# =============================================================================

set -uo pipefail

# --- Configuration ---
readonly NIGHTFALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly HOME_CONFIG="$HOME/.config"
declare -ri MAX_DISPLAY_ROWS=12

# --- ANSI Constants ---
readonly C_RESET=$'\033[0m'
readonly C_CYAN=$'\033[1;36m'
readonly C_GREEN=$'\033[1;32m'
readonly C_MAGENTA=$'\033[1;35m'
readonly C_RED=$'\033[1;31m'
readonly C_WHITE=$'\033[1;37m'
readonly C_GREY=$'\033[1;30m'
readonly C_YELLOW=$'\033[1;33m'
readonly C_BLUE=$'\033[0;34m'
readonly C_INVERSE=$'\033[7m'
readonly CLR_EOL=$'\033[K'
readonly CLR_EOS=$'\033[J'
readonly CURSOR_HOME=$'\033[H'
readonly CURSOR_HIDE=$'\033[?25l'
readonly CURSOR_SHOW=$'\033[?25h'
# SGR Mouse Mode (1006) + Button Event (1002)
readonly MOUSE_ON=$'\033[?1000h\033[?1002h\033[?1006h'
readonly MOUSE_OFF=$'\033[?1000l\033[?1002l\033[?1006l'

# --- State ---
declare -i SELECTED_ROW=0
declare -i CURRENT_TAB=0
readonly -a TABS=("Plugins" "Installed")
declare -ri TAB_COUNT=${#TABS[@]}

# Mouse Click Zones (Calculated during draw)
declare -a TAB_ZONES=()

# --- Data Structures ---
declare -A PLUGIN_INFO # plugin_name -> "title|description|installed"
declare -a AVAILABLE_PLUGINS=() INSTALLED_PLUGINS=()

# --- Plugin Management Functions ---

get_available_plugins() {
	AVAILABLE_PLUGINS=()
	for dir in "$NIGHTFALL_DIR"/*/; do
		if [[ -d "$dir" && -f "${dir}info" && "$(basename "$dir")" != "arch_iso_scripts" ]]; then
			local plugin_name
			plugin_name=$(basename "$dir")
			AVAILABLE_PLUGINS+=("$plugin_name")

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
			PLUGIN_INFO["$plugin_name"]=$(echo "${PLUGIN_INFO[$plugin_name]}" | sed 's/|false$/|true/')
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

	# Show plugin details
	clear
	echo -e "${C_CYAN}${C_INVERSE} Installing Plugin: $plugin_name ${C_RESET}"
	echo ""
	get_plugin_details "$plugin_name"
	echo ""

	echo -e "${C_YELLOW}Press [Enter] to continue installation or [q] to cancel...${C_RESET}"
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
		if bash "$setup_script"; then
			echo -e "  ${C_GREEN}✓${C_RESET} Setup script completed successfully"
		else
			echo -e "  ${C_RED}✗${C_RESET} Setup script failed"
			read -p "Press Enter to continue..." -r
			return 1
		fi
	fi

	echo -e "${C_GREEN}Plugin $plugin_name installed successfully!${C_RESET}"
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

# --- UI Rendering ---

draw_ui() {
	local buf=""
	local -i i current_col=3

	buf+="${CURSOR_HOME}"

	# 66-char wide box (including borders)
	buf+="${C_MAGENTA}┌────────────────────────────────────────────────────────────────┐${C_RESET}"$'\n'

	# Center alignment
	buf+="${C_MAGENTA}│$(printf '%*s' 18 '')${C_WHITE}Nightfall Plugin Manager ${C_CYAN}v1.0${C_MAGENTA}$(printf '%*s' 18 '')│${C_RESET}"$'\n'

	local tab_line="${C_MAGENTA}│ "
	TAB_ZONES=()

	for ((i = 0; i < TAB_COUNT; i++)); do
		local name=${TABS[i]}
		local -i len=${#name}
		local -i zone_start=$current_col

		if ((i == CURRENT_TAB)); then
			tab_line+="${C_CYAN}${C_INVERSE} ${name} ${C_RESET}${C_MAGENTA}│ "
		else
			tab_line+="${C_GREY} ${name} ${C_MAGENTA}│ "
		fi

		TAB_ZONES+=("${zone_start}:$((zone_start + len + 1))")
		((current_col += len + 4))
	done

	# Box right border fix
	local -i tab_line_len=$((current_col - 1))
	local -i pad_needed=$((65 - tab_line_len))

	((pad_needed > 0)) && tab_line+=$(printf '%*s' "$pad_needed" '')
	tab_line+="${C_MAGENTA}│${C_RESET}"

	buf+="${tab_line}"$'\n'
	buf+="${C_MAGENTA}└────────────────────────────────────────────────────────────────┘${C_RESET}"$'\n'

	# Content based on current tab
	if ((CURRENT_TAB == 0)); then
		# Plugins tab
		local -i count=${#AVAILABLE_PLUGINS[@]}
		((SELECTED_ROW >= count)) && SELECTED_ROW=$((count - 1))
		((SELECTED_ROW < 0)) && SELECTED_ROW=0

		for ((i = 0; i < count; i++)); do
			local plugin_name="${AVAILABLE_PLUGINS[i]}"
			local plugin_info="${PLUGIN_INFO[$plugin_name]}"
			IFS='|' read -r title description installed <<<"$plugin_info"

			local status_display=""
			if [[ "$installed" == "true" ]]; then
				status_display="${C_GREEN}Installed${C_RESET}"
			else
				status_display="${C_GREY}Available${C_RESET}"
			fi

			if ((i == SELECTED_ROW)); then
				buf+="${C_CYAN} ➤ ${C_INVERSE}"
				buf+=$(printf '%-25s' "$title")
				buf+="${C_RESET} : $status_display${CLR_EOL}"$'\n'
			else
				buf+="   "
				buf+=$(printf ' %-25s' "$title")
				buf+=" : $status_display${CLR_EOL}"$'\n'
			fi
		done
	else
		# Installed tab
		local -i count=0
		INSTALLED_PLUGINS=()

		for plugin_name in "${AVAILABLE_PLUGINS[@]}"; do
			local plugin_info="${PLUGIN_INFO[$plugin_name]}"
			IFS='|' read -r title description installed <<<"$plugin_info"

			if [[ "$installed" == "true" ]]; then
				INSTALLED_PLUGINS+=("$plugin_name")
				((count++))
			fi
		done

		((SELECTED_ROW >= count)) && SELECTED_ROW=$((count - 1))
		((SELECTED_ROW < 0)) && SELECTED_ROW=0

		for ((i = 0; i < count; i++)); do
			local plugin_name="${INSTALLED_PLUGINS[i]}"
			local plugin_info="${PLUGIN_INFO[$plugin_name]}"
			IFS='|' read -r title description installed <<<"$plugin_info"

			if ((i == SELECTED_ROW)); then
				buf+="${C_CYAN} ➤ ${C_INVERSE}"
				buf+=$(printf '%-30s' "$title")
				buf+="${C_RESET}${CLR_EOL}"$'\n'
			else
				buf+="   "
				buf+=$(printf ' %-30s' "$title")
				buf+="${CLR_EOL}"$'\n'
			fi
		done
	fi

	for ((i = count; i < MAX_DISPLAY_ROWS; i++)); do
		buf+="${CLR_EOL}"$'\n'
	done

	# Help line
	if ((CURRENT_TAB == 0)); then
		buf+=$'\n'"${C_CYAN} [Tab] Switch Tab  [Enter] Install  [i] Plugin Info  [↑/↓ j/k] Nav  [q] Quit${C_RESET}"$'\n'
	else
		buf+=$'\n'"${C_CYAN} [Tab] Switch Tab  [i] Plugin Info  [↑/↓ j/k] Nav  [q] Quit${C_RESET}"$'\n'
	fi

	buf+="${C_CYAN} Directory: ${C_WHITE}${NIGHTFALL_DIR}${C_RESET}${CLR_EOL}${CLR_EOS}"

	printf '%s' "$buf"
}

show_plugin_info() {
	local plugin_name
	if ((CURRENT_TAB == 0)); then
		plugin_name="${AVAILABLE_PLUGINS[SELECTED_ROW]}"
	else
		plugin_name="${INSTALLED_PLUGINS[SELECTED_ROW]}"
	fi

	clear
	echo -e "${C_CYAN}${C_INVERSE} Plugin Information ${C_RESET}"
	echo ""
	get_plugin_details "$plugin_name"
	echo ""
	echo -e "${C_YELLOW}Press Enter to continue...${C_RESET}"
	read -r
}

# --- Input Handling ---

navigate() {
	local -i dir=$1
	local -i count
	if ((CURRENT_TAB == 0)); then
		count=${#AVAILABLE_PLUGINS[@]}
	else
		count=${#INSTALLED_PLUGINS[@]}
	fi

	((SELECTED_ROW += dir)) || :
	((SELECTED_ROW < 0)) && SELECTED_ROW=$((count - 1))
	((SELECTED_ROW >= count)) && SELECTED_ROW=0
}

switch_tab() {
	local -i dir=${1:-1}
	((CURRENT_TAB += dir)) || :
	((CURRENT_TAB >= TAB_COUNT)) && CURRENT_TAB=0
	((CURRENT_TAB < 0)) && CURRENT_TAB=$((TAB_COUNT - 1))
	SELECTED_ROW=0
	clear
}

set_tab() {
	local -i idx=$1
	if ((idx != CURRENT_TAB && idx >= 0 && idx < TAB_COUNT)); then
		CURRENT_TAB=idx
		SELECTED_ROW=0
		clear
	fi
}

handle_mouse() {
	local input=$1
	local -i button x y i
	local type zone start end

	# Matches SGR sequence: "[<0;10;5M"
	if [[ $input =~ ^\[\<([0-9]+)\;([0-9]+)\;([0-9]+)([Mm])$ ]]; then
		button=${BASH_REMATCH[1]}
		x=${BASH_REMATCH[2]}
		y=${BASH_REMATCH[3]}
		type=${BASH_REMATCH[4]}

		[[ $type != "M" ]] && return 0

		# Tab Row = 3
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

		# Item rows start at 5
		local -i item_start_y=5
		local -i count
		if ((CURRENT_TAB == 0)); then
			count=${#AVAILABLE_PLUGINS[@]}
		else
			count=${#INSTALLED_PLUGINS[@]}
		fi

		if ((y >= item_start_y && y < item_start_y + count)); then
			SELECTED_ROW=$((y - item_start_y))
			if ((button == 0)); then # Left click
				if ((CURRENT_TAB == 0)); then
					install_plugin "${AVAILABLE_PLUGINS[SELECTED_ROW]}"
				fi
			fi
		fi
	fi
}

# --- Cleanup ---

cleanup() {
	printf '%s%s%s' "$MOUSE_OFF" "$CURSOR_SHOW" "$C_RESET"
	clear
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# --- Main ---

main() {
	[[ ! -d "$NIGHTFALL_DIR" ]] && {
		echo -e "${C_RED}Error: Nightfall directory not found: $NIGHTFALL_DIR${C_RESET}"
		exit 1
	}

	printf '%s%s' "$MOUSE_ON" "$CURSOR_HIDE"
	get_available_plugins
	clear

	local key seq char
	while true; do
		draw_ui

		IFS= read -rsn1 key || :

		if [[ $key == $'\x1b' ]]; then
			# Instant buffer drain for zero-latency arrow keys
			seq=""
			while IFS= read -rsn1 -t 0.001 char; do
				seq+="$char"
			done

			case $seq in
			'[Z') switch_tab -1 ;;           # Shift+Tab
			'[A' | 'OA') navigate -1 ;;      # Up
			'[B' | 'OB') navigate 1 ;;       # Down
			'['*'<'*) handle_mouse "$seq" ;; # SGR Mouse
			esac
		else
			case $key in
			k | K) navigate -1 ;;
			j | J) navigate 1 ;;
			$'\t') switch_tab 1 ;;
			i | I) show_plugin_info ;;
			$'\n') # Enter key
				if ((CURRENT_TAB == 0)); then
					install_plugin "${AVAILABLE_PLUGINS[SELECTED_ROW]}"
				fi
				;;
			q | Q | $'\x03') break ;;
			esac
		fi
	done
}

main "$@"
