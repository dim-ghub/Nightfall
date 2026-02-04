#!/bin/bash

# Check if directory exists and remove it first
if [ -d "$HOME/textfox" ]; then
	rm -rf "$HOME/textfox"
fi

# Clone the textfox repository
git clone https://github.com/adriankarlen/textfox.git ~/textfox

# Change into the cloned directory
cd ~/textfox

# Run the installation script
sh tf-install.sh
