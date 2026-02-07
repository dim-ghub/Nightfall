# Nightfall
3rd party plugin and theme manager for Dusky

## 🚀 **Latest Update: Generic Variant System**

The plugin manager now features a **generic variant system** that eliminates hardcoded plugin relationships. Key improvements:

- ✅ **Dynamic variant declarations** via info files (`# variant = plugin-name`)
- ✅ **Automatic conflict resolution** during installation and toggle
- ✅ **Smart status display** showing variant-aware availability
- ✅ **Stateless architecture** - add new variants without code changes
- ✅ **Enhanced UI** with "Available (Variant ON)" status indicators

**Previously supported variants:**
- `spicetext` ↔ `spicedim` (Spotify themes)
- `textfox` ↔ `dimfox` (Firefox themes)

## Installation

### Quick Install (Recommended)

Run the installer directly without downloading:

```bash
curl -sSL https://raw.githubusercontent.com/dim-ghub/Nightfall/main/install.sh | bash
```

### Manual Install

Clone the repository and run the installer:

```bash
git clone https://github.com/dim-ghub/Nightfall ~/Nightfall
cd ~/Nightfall
chmod +x install.sh
./install.sh
```

## Usage

Run the Nightfall TUI:

```bash
./nightfall.sh
```

Or launch it from your application menu as "Nightfall Manager".

### Adding Plugins

1. Create a new directory in the `plugins/` folder (e.g., `plugins/my-plugin/`)
2. Add an `info` file with the following format:
   ```
   # Plugin Title
   
   Plugin description goes here...
   
   # variant = other-plugin-name  # Optional: Declare this as a variant of another plugin
   ```
3. Add configuration files in a `.config/` subdirectory
4. Optional: Add a `setup.sh` script for additional installation steps
5. Optional: Add preview images in a `previews/` subdirectory

#### Plugin Variants

Nightfall supports plugin variants for themes that have multiple styles. When you declare a plugin as a variant of another plugin using `# variant = plugin-name` in the info file:

- The variant will be automatically turned off when its counterpart is activated
- The UI will show appropriate availability status based on variant state
- Only one variant can be active at a time
- Variants without matugen configs will show as "Available" instead of "OFF"

**Example**: `spicetext` and `spicedim` are variants - only one can be active at a time.

### Plugin Structure

```
plugins/my-plugin/
├── info              # Plugin info file (title, description)
├── setup.sh          # Optional: Installation script with --install, --uninstall, --on, --off flags
├── .config/          # Config files to install
│   ├── app1/         # App-specific configs
│   └── matugen/      # Matugen templates and config
│       ├── config.toml
│       └── templates/
└── previews/         # Preview images (ignored by installer)
```

The TUI will automatically handle the installation of configuration files based on this structure.

## Available Plugins

### Firefox Themes

#### dimfox
A Firefox theme customization that installs the textfox-rounded theme with rounded corners and no segment labels for a cleaner browsing experience.
- **Variant of**: `textfox`
- **Toggle Support**: Yes (via setup script)

#### textfox
A Firefox theme customization that installs the textfox theme with segment labels and standard corners for a detailed Firefox browsing experience.
- **Variant of**: `dimfox`
- **Toggle Support**: Yes (via setup script)

### Spotify Themes

#### spicedim
A Spicetify theme configuration that sets the "dim" theme with rounded corners, no segment labels, and matugen-generated colors for a cleaner Spotify interface.
- **Variant of**: `spicetext`
- **Toggle Support**: Yes (via matugen templates)

#### spicetext
A Spicetify theme configuration that sets the "text" theme with segment labels and matugen-generated colors for a detailed Spotify interface.
- **Variant of**: `spicedim`
- **Toggle Support**: Yes (via matugen templates)

### System Utilities

#### steamatugen
Desktop Steam theming setup with Decky Loader integration and matugen color theming for a customized Steam client experience.

#### waybar-tui
Waybar configuration manager that switches to TUI style configuration by removing existing symlinks and creating new symlinks to the TUI config files, then restarts waybar to apply changes.

#### discordsys24
Discord theme based on system24 with Catppuccin mocha colors that provides a TUI-style Discord interface with matugen integration for dynamic theming.

#### matugenfetch
A script that gets executed automatically by fastfetch to color the Arch logo with accents from your wallpaper.

#### obsmatugen
OBS Studio theme integration with matugen color generation for Catppuccin-themed recording overlays and UI elements. This plugin provides the Catppuccin color scheme that automatically adapts to your system colors, creating a cohesive dark theme for your recording setup.

**Features:**
- Catppuccin color scheme for OBS Studio
- Automatic color generation with matugen integration
- Dark theme optimized for recording overlays
- UI element theming for professional streaming setup

**Note:** Manual setup required in OBS Studio settings to enable theme.

## Features

### 🎛️ **Interactive TUI**
- Mouse and keyboard navigation
- Real-time plugin status display
- Tab-based interface (Plugins/Installed)
- Scroll support for large plugin lists

### 🔄 **Variant Management**
- Automatic variant conflict resolution
- Smart availability status display
- Template-based toggling for matugen plugins
- Setup script integration for non-matugen plugins

### 📦 **Plugin System**
- Stateless plugin installation
- Configuration file management
- Matugen template integration
- Setup script support with standard flags

### 🎨 **Theme Integration**
- Dynamic color generation with matugen
- Cross-application theming
- Automatic theme refresh
- Conflict detection and resolution
