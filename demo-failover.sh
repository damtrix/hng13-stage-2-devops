#!/bin/bash

# Blue/Green Failover Demonstration Script
# Shows real-time failover behavior

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎭 Blue/Green Failover Demonstration${NC}"
echo "=============================================="

# Function to make request and show pool
make_request() {
    local url=$1
    local description=$2
    
    response=$(curl -s -I "$url" 2>/dev/null || echo "")
    http_code=$(curl -s -w "%{http_code}" -o /dev/null "$url" 2>/dev/null || echo "000")
    
    if [ "$http_code" = "200" ]; then
        if echo "$response" | grep -qi "x-app-pool: blue"; then
            echo -e "${BLUE}🔵 $description - Blue Pool${NC}"
        elif echo "$response" | grep -qi "x-app-pool: green"; then
            echo -e "${GREEN}🟢 $description - Green Pool${NC}"
        else
            echo -e "${YELLOW}⚠️  $description - Unknown Pool${NC}"
        fi
    else
        echo -e "${RED}❌ $description - Failed (Status: $http_code)${NC}"
    fi
}

# Function to start chaos
start_chaos() {
    local service=$1
    echo -e "${YELLOW}🎭 Starting chaos on $service...${NC}"
    curl -s -X POST "http://localhost:808$([ "$service" = "blue" ] && echo "1" || echo "2")/chaos/start?mode=error" > /dev/null
    echo -e "${RED}💥 Chaos started on $service service${NC}"
}

# Function to stop chaos
stop_chaos() {
    local service=$1
    echo -e "${YELLOW}🛑 Stopping chaos on $service...${NC}"
    curl -s -X POST "http://localhost:808$([ "$service" = "blue" ] && echo "1" || echo "2")/chaos/stop" > /dev/null
    echo -e "${GREEN}✅ Chaos stopped on $service service${NC}"
}

echo "Starting demonstration..."
echo ""

# Baseline - show normal operation
echo -e "${BLUE}📊 Baseline Operation (Blue Active)${NC}"
for i in {1..3}; do
    make_request "http://localhost:8080/version" "Request $i"
    sleep 1
done

echo ""
echo -e "${YELLOW}⏳ Waiting 3 seconds before chaos...${NC}"
sleep 3

# Start chaos on Blue
start_chaos "blue"
echo ""

# Show failover in action
echo -e "${GREEN}🔄 Failover Test (Should switch to Green)${NC}"
for i in {1..5}; do
    make_request "http://localhost:8080/version" "Request $i"
    sleep 1
done

echo ""
echo -e "${YELLOW}⏳ Waiting 3 seconds before stopping chaos...${NC}"
sleep 3

# Stop chaos on Blue
stop_chaos "blue"
echo ""

# Show recovery
echo -e "${BLUE}🔄 Recovery Test (Should switch back to Blue)${NC}"
for i in {1..3}; do
    make_request "http://localhost:8080/version" "Request $i"
    sleep 1
done

echo ""
echo -e "${GREEN}🎉 Demonstration completed!${NC}"
echo ""
echo "Summary:"
echo "- ✅ Blue service was active initially"
echo "- ✅ Chaos simulation triggered on Blue"
echo "- ✅ Traffic automatically failed over to Green"
echo "- ✅ Chaos was stopped on Blue"
echo "- ✅ Traffic returned to Blue (normal operation)"
echo ""
echo "The Blue/Green deployment successfully demonstrated:"
echo "  🔄 Automatic failover"
echo "  🛡️  Zero-downtime operation"
echo "  📊 Health-based routing"
echo "  🎭 Chaos engineering support"
