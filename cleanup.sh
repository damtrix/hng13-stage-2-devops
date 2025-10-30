#!/bin/bash

# Blue/Green Deployment Cleanup Script
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧹 Blue/Green Deployment Cleanup${NC}"
echo "=================================="

# Stop and remove containers
echo -e "${YELLOW}🛑 Stopping services...${NC}"
docker compose down

# Remove volumes (optional)
read -p "Remove volumes? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}🗑️  Removing volumes...${NC}"
    docker compose down -v
fi

# Remove images (optional)
read -p "Remove images? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}🗑️  Removing images...${NC}"
    docker compose down --rmi all
fi

# Clean up any dangling containers/images
echo -e "${YELLOW}🧽 Cleaning up dangling resources...${NC}"
docker system prune -f

echo -e "${GREEN}✅ Cleanup completed!${NC}"
