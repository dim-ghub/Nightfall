# Nightfall
3rd party plugin and theme manager for Dusky

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
   ```
3. Add configuration files in a `.config/` subdirectory
4. Optional: Add a `setup.sh` script for additional installation steps
5. Optional: Add preview images in a `previews/` subdirectory

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

### dimfox
A Firefox theme customization that installs the textfox-rounded theme with rounded corners and no segment labels for a cleaner browsing experience.

### textfox
A Firefox theme customization that installs the textfox theme with segment labels and standard corners for a detailed Firefox browsing experience.

### spicedim
A Spicetify theme configuration that sets the "dim" theme with rounded corners, no segment labels, and matugen-generated colors for a cleaner Spotify interface.

### spicetext
A Spicetify theme configuration that sets the "text" theme with segment labels and matugen-generated colors for a detailed Spotify interface.

### steamatugen
Desktop Steam theming setup with Decky Loader integration and matugen color theming for a customized Steam client experience.

### waybar-tui
Waybar configuration manager that switches to TUI style configuration by removing existing symlinks and creating new symlinks to the TUI config files, then restarts waybar to apply changes.

### discordsys24
Discord theme based on system24 with Catppuccin mocha colors that provides a TUI-style Discord interface with matugen integration for dynamic theming.

### matugenfetch
A script that gets executed automatically by fastfetch to color the Arch logo with accents from your wallpaper.

### obsmatugen
OBS Studio theme integration with matugen color generation for Catppuccin-themed recording overlays and UI elements. This plugin provides the Catppuccin color scheme that automatically adapts to your system colors, creating a cohesive dark theme for your recording setup.

Features:
- Catppuccin color scheme for OBS Studio
- Automatic color generation with matugen integration
- Dark theme optimized for recording overlays
- UI element theming for professional streaming setup

Note: Manual setup required in OBS Studio settings to enable theme.
