#!/bin/bash

# Remove existing symlinks in ~/.config/waybar
find ~/.config/waybar -maxdepth 1 -type l -delete

# Create symlinks from TUI config to ~/.config/waybar
ln -sf ~/.config/waybar/TUI/config.jsonc ~/.config/waybar/config.jsonc
ln -sf ~/.config/waybar/TUI/style.css ~/.config/waybar/style.css

# Kill all waybar instances
pkill waybar

# Start waybar again
waybar &
