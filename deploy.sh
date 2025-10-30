#!/bin/bash

# Blue/Green Deployment Script
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Blue/Green Deployment Script${NC}"
echo "=================================="

# Check if .env exists
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠️  .env file not found. Creating from template...${NC}"
    cp env.template .env
    echo -e "${GREEN}✅ Created .env file from template${NC}"
    echo -e "${YELLOW}📝 Please review and modify .env file if needed${NC}"
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

# Pull required images
echo -e "${BLUE}📥 Pulling Docker images...${NC}"
docker compose pull

# Start services
echo -e "${BLUE}🚀 Starting services...${NC}"
docker compose up -d

# Wait for services to be ready
echo -e "${YELLOW}⏳ Waiting for services to be ready...${NC}"
sleep 10

# Check service health
echo -e "${BLUE}🏥 Checking service health...${NC}"

# Check Nginx
if curl -s http://localhost:8080/healthz > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Nginx is healthy${NC}"
else
    echo -e "${RED}❌ Nginx health check failed${NC}"
fi

# Check Blue service
if curl -s http://localhost:8081/healthz > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Blue service is healthy${NC}"
else
    echo -e "${RED}❌ Blue service health check failed${NC}"
fi

# Check Green service
if curl -s http://localhost:8082/healthz > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Green service is healthy${NC}"
else
    echo -e "${RED}❌ Green service health check failed${NC}"
fi

# Show service status
echo ""
echo -e "${BLUE}📊 Service Status:${NC}"
docker compose ps

echo ""
echo -e "${GREEN}🎉 Deployment completed!${NC}"
echo ""
echo "🌐 Endpoints:"
echo "  Main Application: http://localhost:8080"
echo "  Blue Service:     http://localhost:8081"
echo "  Green Service:    http://localhost:8082"
echo ""
echo "🧪 Run tests: ./test-deployment.sh"
echo "📋 View logs: docker compose logs -f"
echo "🛑 Stop services: docker compose down"
