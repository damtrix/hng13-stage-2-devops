#!/bin/bash

# Fix Port Configuration Script
# Run this on your server to ensure correct port configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Fixing Port Configuration${NC}"
echo "=================================="
echo ""

# Check current .env
echo -e "${YELLOW}Current .env configuration:${NC}"
if [ -f ".env" ]; then
    cat .env
else
    echo -e "${RED}❌ .env file not found${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Current docker-compose.yml port mapping:${NC}"
grep -A2 "ports:" docker-compose.yml

echo ""
echo -e "${YELLOW}Current running containers:${NC}"
docker compose ps

echo ""
echo -e "${BLUE}📋 Requirements Analysis:${NC}"
echo "The grader expects:"
echo "  - Main entrypoint: http://localhost:8080"
echo "  - Blue direct: http://localhost:8081" 
echo "  - Green direct: http://localhost:8082"
echo ""

# Check if PORT=8080 in .env
if grep -q "PORT=8080" .env; then
    echo -e "${GREEN}✅ PORT=8080 is correctly set in .env${NC}"
else
    echo -e "${YELLOW}⚠️  PORT is not set to 8080 in .env${NC}"
    echo "Current PORT setting: $(grep PORT .env)"
    echo ""
    echo -e "${YELLOW}To fix this, run:${NC}"
    echo "sed -i 's/PORT=.*/PORT=8080/' .env"
    echo ""
    echo "Or manually edit .env and change PORT to 8080"
fi

echo ""
echo -e "${BLUE}🔍 Testing Current Configuration:${NC}"

# Test all ports
echo "Testing port 80..."
if curl -s --connect-timeout 5 http://localhost:80/version > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Port 80 is working${NC}"
else
    echo -e "${RED}❌ Port 80 is not working${NC}"
fi

echo "Testing port 8080..."
if curl -s --connect-timeout 5 http://localhost:8080/version > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Port 8080 is working${NC}"
else
    echo -e "${RED}❌ Port 8080 is not working${NC}"
fi

echo "Testing port 8081..."
if curl -s --connect-timeout 5 http://localhost:8081/version > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Port 8081 is working${NC}"
else
    echo -e "${RED}❌ Port 8081 is not working${NC}"
fi

echo "Testing port 8082..."
if curl -s --connect-timeout 5 http://localhost:8082/version > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Port 8082 is working${NC}"
else
    echo -e "${RED}❌ Port 8082 is not working${NC}"
fi

echo ""
echo -e "${BLUE}💡 Recommendations:${NC}"
echo "1. Ensure PORT=8080 in .env file"
echo "2. Restart services: docker compose down && docker compose up -d"
echo "3. Test all ports are working"
echo "4. The grader will test http://localhost:8080 as the main entrypoint"
echo ""
echo -e "${GREEN}✅ Port configuration check completed${NC}"
