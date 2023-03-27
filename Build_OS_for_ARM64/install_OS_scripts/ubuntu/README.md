We adapt the script for installing Ubuntu on ARM64 devices. The main changes consisted in replacing 
1. amd64 by arm64 in the file
2. the linux-image to install


This bootstrap script needs to/will be refined to be more generic. Some parameters are hard-coded while they were initially provided as input.
