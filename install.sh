#!/bin/bash

# Clone Nightfall repository
echo "Cloning Nightfall to ~/Nightfall..."
git clone https://github.com/dim-ghub/Nightfall ~/Nightfall

# Create applications directory if it doesn't exist
mkdir -p ~/.local/share/applications

# Create Nightfall.desktop file
echo "Creating Nightfall.desktop file..."
cat >~/.local/share/applications/Nightfall.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Nightfall Manager
GenericName=nightfall
Comment=TUI for managing DiM's 3rd party configs for Dusky
Exec=uwsm-app -- kitty --class nightfall.sh -e /home/$USER/Nightfall/nightfall.sh
Terminal=false
Categories=Settings;DesktopSettings;System;Utility;
Keywords=dusky;hyprland;appearance;theme;tui;config;settings;matugen;nightfall
Icon=preferences-desktop-display
StartupNotify=true
StartupWMClass=nightfall.sh
EOF

echo "Nightfall installation complete!"
echo "You can now launch Nightfall from your application menu."
