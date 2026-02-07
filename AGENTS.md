# Nightfall Agent Guidelines

## Project Overview
Nightfall is a bash-based plugin and theme manager for Dusky (Hyprland environment). The main TUI is in `nightfall.sh` and plugins are located in `plugins/`.

## Build/Test Commands

This is a pure bash project with no build system or automated tests. Scripts should be validated with:

```bash
# Validate bash syntax
bash -n nightfall.sh
bash -n plugins/*/setup.sh

# Run with shellcheck (if available)
shellcheck nightfall.sh
shellcheck plugins/*/setup.sh
```

## Code Style Guidelines

### Shebang and Settings
- Use `#!/bin/bash` or `#!/usr/bin/env bash` shebang
- Always use `set -euo pipefail` at the start of scripts
- Use `shopt -s inherit_errexit` for bash 4.4+ compatibility

### Naming Conventions
- **Constants**: `UPPER_SNAKE_CASE` with `readonly` modifier
- **Global variables**: `UPPER_SNAKE_CASE`
- **Local variables**: `lower_snake_case`
- **Functions**: `lower_snake_case` using `name() {` syntax (not `function name {`)

### Header Comments
Include a header comment block at the top of each script:
```bash
# =============================================================================
# Script Name - Brief Description
# =============================================================================
# Target: Arch Linux / Context
# Description: Detailed explanation of what the script does.
# =============================================================================
```

### Logging
Use consistent logging functions with ANSI colors:
```bash
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'  # No Color

log_info() { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"; }
log_warning() { printf "${YELLOW}[WARNING]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }
```

### Control Flow
- Use `[[ ]]` for conditionals (not `[ ]`)
- Always quote variables: `"$variable"`
- Use `case` statements for handling flags like `--install`, `--uninstall`, `--on`, `--off`
- Use `command -v` to check for command availability

### Error Handling
- Use `|| true` for commands that may fail intentionally
- Use `die()` function for fatal errors
- Trap cleanup functions with `trap cleanup EXIT`
- Use shellcheck disable comments where necessary (document why)

### Setup Script Interface
Setup scripts must support these flags:
- `--install` (default): Install the plugin
- `--uninstall`: Remove the plugin
- `--on`: Enable/toggle the plugin on
- `--off`: Disable/toggle the plugin off

## Plugin Structure
```
plugins/my-plugin/
├── info              # Plugin info file (title, description)
├── setup.sh          # Optional: Installation script with flags above
├── .config/          # Config files to install
│   ├── app1/         # App-specific configs
│   └── matugen/      # Matugen templates and config
└── previews/         # Preview images (ignored by installer)
```

## Key Implementation Details

### ANSI Constants (from nightfall.sh)
Use these constants for terminal control:
```bash
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
```

### Matugen Config Handling
- Use `smart_merge_matugen_config()` pattern for merging TOML configs
- Templates go in `.config/matugen/templates/`
- Config goes in `.config/matugen/config.toml`

### Cache System
- Cache file: `$HOME/.cache/nightfall_installed_plugins.txt`
- Format: First line is version (`nightfall_v1`), then one plugin per line
- Always update cache after plugin installation/removal
