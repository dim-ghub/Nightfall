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

1. Create a new directory in the root folder (e.g., `my-plugin/`)
2. Add an `info` file with the following format:
   ```
   # Plugin Title
   
   Plugin description goes here...
   ```
3. Add configuration files in a `.config/` subdirectory
4. Optional: Add a `setup.sh` script for additional installation steps

### Plugin Structure

```
my-plugin/
├── info                    # Plugin information
├── .config/               # Configuration files
│   ├── app1/             # App configurations
│   ├── matugen/          # Matugen-specific config
│   │   ├── config.toml   # Gets appended to ~/.config/matugen/config.toml
│   │   └── templates/    # Gets copied to ~/.config/matugen/templates/
│   └── app2/
└── setup.sh              # Optional setup script
```

The TUI will automatically handle the installation of configuration files based on this structure.

## Available Plugins

### dimfox
Firefox theme customization that installs the textfox-rounded theme with rounded corners and no segment labels for a cleaner browsing experience.

<!-- ![dimfox preview](images/dimfox.png) -->

### textfox
Firefox theme customization that installs the textfox theme with segment labels and standard corners for a detailed Firefox browsing experience.

<!-- ![textfox preview](images/textfox.png) -->

### spicedim
Spicetify theme configuration that sets the "dim" theme with rounded corners, no segment labels, and matugen-generated colors for a cleaner Spotify interface.

<!-- ![spicedim preview](images/spicedim.png) -->

### spicetext
Spicetify theme configuration that sets the "text" theme with segment labels and matugen-generated colors for a detailed Spotify interface.

<!-- ![spicetext preview](images/spicetext.png) -->

### steamatugen
Desktop Steam theming setup with Decky Loader integration and matugen color theming for a customized Steam client experience.

<!-- ![steamatugen preview](images/steamatugen.png) -->

### waybar-tui
Waybar configuration manager that switches to TUI style configuration by removing existing symlinks and creating new symlinks to the TUI config files, then restarts waybar to apply changes.

<!-- ![waybar-tui preview](images/waybar-tui.png) -->

### discordsys24
Discord theme based on system24 with Catppuccin mocha colors that provides a TUI-style Discord interface with matugen integration for dynamic theming.

<!-- ![discordsys24 preview](images/discordsys24.png) -->

### matugenfetch
A script that gets executed automatically by fastfetch to color the Arch logo with accents from your wallpaper.

<!-- ![matugenfetch preview](images/matugenfetch.png) -->
