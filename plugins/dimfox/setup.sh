#!/bin/bash

# Check if directory exists and remove it first
if [ -d "$HOME/textfox-rounded" ]; then
	rm -rf "$HOME/textfox-rounded"
fi

# Clone the textfox-rounded repository
git clone https://github.com/dim-ghub/textfox-rounded.git ~/textfox-rounded

# Change into the cloned directory
cd ~/textfox-rounded

# Run the installation script
sh tf-install.sh
