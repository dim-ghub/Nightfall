#!/bin/bash

# OBS Studio Matugen Setup Script
# Provides instructions for enabling Catppuccin theme with matugen color scheme

echo "=== OBS Studio Matugin Setup ==="
echo ""
echo "This plugin provides Catppuccin theming for OBS Studio with matugen integration."
echo "Manual setup is required in OBS Studio to enable the theme."
echo ""

# Check if OBS Studio is installed
if command -v obs &>/dev/null; then
	echo "✅ OBS Studio found"
elif [[ -d "/usr/bin/obs-studio" ]] || [[ -d "/opt/obs-studio" ]]; then
	echo "✅ OBS Studio found"
else
	echo "⚠️  OBS Studio not found in standard locations"
	echo "   Please install OBS Studio first"
fi

echo ""
echo "📋 SETUP INSTRUCTIONS:"
echo "1. Open OBS Studio"
echo "2. Go to: File → Settings → General → Theme"
echo "3. Select 'Catppuccin' theme from the dropdown menu"
echo "4. Click 'Apply' to activate the theme"
echo ""

echo "🎨 THEME INFORMATION:"
echo "   Theme: Catppuccin"
echo "   Color Scheme: matugen (automatic)"
echo "   Integration: Automatic color generation"
echo ""

echo "🔄 COLOR GENERATION:"
echo "   - Run 'matugen' to generate colors"
echo "   - OBS theme colors will update automatically"
echo "   - Colors sync with your system theme"
echo ""

echo "📁 CONFIGURATION FILES:"
echo "   - Theme: ~/.config/obs-studio/themes/matugen.obt"
echo "   - Colors: ~/.config/matugen/generated/obs-studio.ovt"
echo ""

# Check if matugen is available
if command -v matugen &>/dev/null; then
	echo "✅ Matugen found - color generation ready"
else
	echo "⚠️  Matugen not found"
	echo "   Install matugen for automatic color generation"
fi

echo ""
echo "✨ OBS Studio Catppuccin theme setup complete!"
echo "   Follow the instructions above to enable the theme in OBS Studio."
