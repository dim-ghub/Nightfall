#!/bin/bash

# Check if spicetify is available
if ! command -v spicetify &>/dev/null; then
	echo "Warning: spicetify not found. Skipping theme configuration."
	exit 0
fi

echo "Setting Spicetify theme to dim..."
spicetify config theme dim

echo "Setting color scheme to matugen..."
spicetify config color_scheme matugen

echo "Applying Spicetify changes..."
spicetify apply

echo "Spicetify dim theme with matugen colors configured!"
