# Nightfall
3rd party plugin and theme manager for Dusky

## Usage

Run the Nightfall TUI:

```bash
./nightfall.sh
```

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
