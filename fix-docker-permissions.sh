#!/bin/bash

# Fix Docker permissions script
# Run this after running server-setup.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Fixing Docker Permissions${NC}"
echo "=================================="
echo ""

# Check if user is in docker group
if ! groups "$USER" | grep -q docker; then
    echo -e "${YELLOW}Adding user $USER to docker group...${NC}"
    sudo usermod -aG docker "$USER"
    echo -e "${GREEN}✅ User added to docker group${NC}"
    echo ""
    echo -e "${YELLOW}You need to log out and log back in, or run: newgrp docker${NC}"
    echo ""
    echo "Choose one of these options:"
    echo "1. Run: newgrp docker"
    echo "2. Log out and log back in"
    echo "3. Open a new SSH session"
    exit 0
fi

echo -e "${GREEN}✅ User is already in docker group${NC}"
echo ""

# Try to access docker without sudo
if docker ps > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Docker is already accessible without sudo${NC}"
else
    echo -e "${YELLOW}Attempting to fix permissions...${NC}"
    
    # Option 1: Log out and log back in
    echo ""
    echo -e "${YELLOW}📝 To fix this, choose one of these options:${NC}"
    echo ""
    echo "Option 1: Run 'newgrp docker' in your terminal:"
    echo "  newgrp docker"
    echo ""
    echo "Option 2: Log out and log back in:"
    echo "  logout"
    echo "  # Then SSH back into your server"
    echo ""
    echo "Option 3: Open a new SSH session"
    echo ""
    echo "Option 4: Use sudo for now:"
    echo "  sudo docker compose up -d"
    echo ""
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Docker permissions are now working!${NC}"
