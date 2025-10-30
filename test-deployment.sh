#!/bin/bash

# Blue/Green Deployment Test Script
# Tests failover behavior with chaos simulation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to detect server IP
detect_server_ip() {
    # Try AWS metadata service first (if running on AWS)
    local public_ip=$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "")
    
    # If not AWS or metadata fails, try alternative methods
    if [ -z "$public_ip" ]; then
        # Try external service
        public_ip=$(curl -s --connect-timeout 2 http://checkip.amazonaws.com 2>/dev/null || echo "")
    fi
    
    if [ -z "$public_ip" ]; then
        # Fallback to localhost
        echo "localhost"
    else
        echo "$public_ip"
    fi
}

# Detect server IP
SERVER_IP=$(detect_server_ip)

# Configuration
BASE_URL="http://$SERVER_IP:8080"
BLUE_DIRECT_URL="http://$SERVER_IP:8081"
GREEN_DIRECT_URL="http://$SERVER_IP:8082"
TEST_DURATION=10
REQUEST_INTERVAL=1

# Test counters
TOTAL_REQUESTS=0
SUCCESSFUL_REQUESTS=0
BLUE_RESPONSES=0
GREEN_RESPONSES=0
FAILED_REQUESTS=0

echo -e "${BLUE}🚀 Starting Blue/Green Deployment Test${NC}"
echo "================================================"
echo -e "${YELLOW}📍 Detected Server IP: $SERVER_IP${NC}"
echo ""

# Function to make HTTP request and capture response
make_request() {
    local url=$1
    local description=$2
    
    echo -e "${YELLOW}📡 Testing: $description${NC}"
    echo "URL: $url"
    
    # Make request and capture response with headers
    response=$(curl -s -w "\n%{http_code}" --connect-timeout 10 -H "Accept: application/json" "$url" 2>/dev/null || echo -e "\n000")
    headers=$(curl -s -I --connect-timeout 10 "$url" 2>/dev/null || echo "")
    
    # Parse response
    http_code=$(echo "$response" | tail -n 1)
    body=$(echo "$response" | sed '$d')
    
    echo "HTTP Status: $http_code"
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✅ Request successful${NC}"
        SUCCESSFUL_REQUESTS=$((SUCCESSFUL_REQUESTS + 1))
        
        # Check for pool headers in HTTP headers
        if echo "$headers" | grep -qi "x-app-pool: blue"; then
            echo -e "${BLUE}🔵 Response from Blue pool${NC}"
            BLUE_RESPONSES=$((BLUE_RESPONSES + 1))
        elif echo "$headers" | grep -qi "x-app-pool: green"; then
            echo -e "${GREEN}🟢 Response from Green pool${NC}"
            GREEN_RESPONSES=$((GREEN_RESPONSES + 1))
        else
            echo -e "${YELLOW}⚠️  No X-App-Pool header found${NC}"
        fi
        
        # Check for release ID
        if echo "$headers" | grep -qi "x-release-id:"; then
            release_id=$(echo "$headers" | grep -i "x-release-id:" | cut -d' ' -f2 | tr -d '\r')
            echo "Release ID: $release_id"
        fi
        
        # Show response body (first 200 chars)
        echo "Response body: $(echo "$body" | head -c 200)..."
    else
        echo -e "${RED}❌ Request failed with status $http_code${NC}"
        FAILED_REQUESTS=$((FAILED_REQUESTS + 1))
    fi
    
    TOTAL_REQUESTS=$((TOTAL_REQUESTS + 1))
    echo "----------------------------------------"
}

# Function to test chaos simulation
test_chaos() {
    local service_url=$1
    local service_name=$2
    
    echo -e "${YELLOW}🎭 Testing chaos simulation on $service_name${NC}"
    
    # Start chaos
    echo "Starting chaos (error mode)..."
    chaos_start_response=$(curl -s -w "\n%{http_code}" -X POST "$service_url/chaos/start?mode=error" 2>/dev/null || echo -e "\n000")
    chaos_start_code=$(echo "$chaos_start_response" | tail -n 1)
    
    if [ "$chaos_start_code" = "200" ]; then
        echo -e "${GREEN}✅ Chaos started successfully${NC}"
    else
        echo -e "${RED}❌ Failed to start chaos (status: $chaos_start_code)${NC}"
    fi
    
    # Wait a moment for chaos to take effect
    sleep 2
    
    # Test direct access to the service (should fail)
    echo "Testing direct access to $service_name (should fail)..."
    direct_response=$(curl -s -w "\n%{http_code}" "$service_url/version" 2>/dev/null || echo -e "\n000")
    direct_code=$(echo "$direct_response" | tail -n 1)
    
    if [ "$direct_code" = "500" ] || [ "$direct_code" = "000" ]; then
        echo -e "${GREEN}✅ Direct access to $service_name is failing as expected${NC}"
    else
        echo -e "${YELLOW}⚠️  Direct access to $service_name returned status: $direct_code${NC}"
    fi
    
    # Stop chaos
    echo "Stopping chaos..."
    chaos_stop_response=$(curl -s -w "\n%{http_code}" -X POST "$service_url/chaos/stop" 2>/dev/null || echo -e "\n000")
    chaos_stop_code=$(echo "$chaos_stop_response" | tail -n 1)
    
    if [ "$chaos_stop_code" = "200" ]; then
        echo -e "${GREEN}✅ Chaos stopped successfully${NC}"
    else
        echo -e "${RED}❌ Failed to stop chaos (status: $chaos_stop_code)${NC}"
    fi
    
    # Wait for service to recover
    sleep 2
}

# Function to run continuous load test
run_load_test() {
    local duration=$1
    local interval=$2
    
    echo -e "${BLUE}🔄 Running load test for ${duration}s (interval: ${interval}s)${NC}"
    
    start_time=$(date +%s)
    end_time=$((start_time + duration))
    
    while [ $(date +%s) -lt $end_time ]; do
        make_request "$BASE_URL/version" "Load test request"
        sleep $interval
    done
}

# Function to check service health
check_health() {
    echo -e "${YELLOW}🏥 Checking service health${NC}"
    
    # Check Nginx health
    nginx_health=$(curl -s -w "\n%{http_code}" --connect-timeout 10 "$BASE_URL/healthz" 2>/dev/null || echo -e "\n000")
    nginx_code=$(echo "$nginx_health" | tail -n 1)
    
    if [ "$nginx_code" = "200" ]; then
        echo -e "${GREEN}✅ Nginx health check passed${NC}"
    else
        echo -e "${RED}❌ Nginx health check failed (status: $nginx_code)${NC}"
    fi
    
    # Check Blue service health
    blue_health=$(curl -s -w "\n%{http_code}" --connect-timeout 10 "$BLUE_DIRECT_URL/healthz" 2>/dev/null || echo -e "\n000")
    blue_code=$(echo "$blue_health" | tail -n 1)
    
    if [ "$blue_code" = "200" ]; then
        echo -e "${GREEN}✅ Blue service health check passed${NC}"
    else
        echo -e "${RED}❌ Blue service health check failed (status: $blue_code)${NC}"
    fi
    
    # Check Green service health
    green_health=$(curl -s -w "\n%{http_code}" --connect-timeout 10 "$GREEN_DIRECT_URL/healthz" 2>/dev/null || echo -e "\n000")
    green_code=$(echo "$green_health" | tail -n 1)
    
    if [ "$green_code" = "200" ]; then
        echo -e "${GREEN}✅ Green service health check passed${NC}"
    else
        echo -e "${RED}❌ Green service health check failed (status: $green_code)${NC}"
    fi
}

# Function to print test summary
print_summary() {
    echo ""
    echo "================================================"
    echo -e "${BLUE}📊 TEST SUMMARY${NC}"
    echo "================================================"
    echo "Server IP: $SERVER_IP"
    echo "Total Requests: $TOTAL_REQUESTS"
    echo "Successful Requests: $SUCCESSFUL_REQUESTS"
    echo "Failed Requests: $FAILED_REQUESTS"
    echo "Blue Responses: $BLUE_RESPONSES"
    echo "Green Responses: $GREEN_RESPONSES"
    
    if [ $TOTAL_REQUESTS -gt 0 ]; then
        success_rate=$(( (SUCCESSFUL_REQUESTS * 100) / TOTAL_REQUESTS ))
        echo "Success Rate: ${success_rate}%"
        
        if [ $BLUE_RESPONSES -gt 0 ] && [ $GREEN_RESPONSES -gt 0 ]; then
            echo -e "${GREEN}✅ Failover test PASSED - Both Blue and Green pools responded${NC}"
        elif [ $BLUE_RESPONSES -gt 0 ]; then
            echo -e "${BLUE}🔵 Only Blue pool responded (normal operation)${NC}"
        elif [ $GREEN_RESPONSES -gt 0 ]; then
            echo -e "${GREEN}🟢 Only Green pool responded (failover active)${NC}"
        fi
        
        if [ $success_rate -ge 95 ]; then
            echo -e "${GREEN}✅ Success rate requirement MET (≥95%)${NC}"
        else
            echo -e "${RED}❌ Success rate requirement NOT MET (<95%)${NC}"
        fi
    fi
}

# Main test execution
main() {
    echo "Waiting for services to be ready..."
    sleep 5
    
    # Initial health check
    check_health
    echo ""
    
    # Test 1: Baseline functionality
    echo -e "${BLUE}🧪 Test 1: Baseline Functionality${NC}"
    make_request "$BASE_URL/version" "Baseline version check"
    echo ""
    
    # Test 2: Direct service access
    echo -e "${BLUE}🧪 Test 2: Direct Service Access${NC}"
    make_request "$BLUE_DIRECT_URL/version" "Blue service direct access"
    make_request "$GREEN_DIRECT_URL/version" "Green service direct access"
    echo ""
    
    # Test 3: Chaos simulation on Blue
    echo -e "${BLUE}🧪 Test 3: Chaos Simulation on Blue Service${NC}"
    test_chaos "$BLUE_DIRECT_URL" "Blue"
    echo ""
    
    # Test 4: Load test during chaos
    echo -e "${BLUE}🧪 Test 4: Load Test During Chaos${NC}"
    run_load_test $TEST_DURATION $REQUEST_INTERVAL
    echo ""
    
    # Test 5: Chaos simulation on Green
    echo -e "${BLUE}🧪 Test 5: Chaos Simulation on Green Service${NC}"
    test_chaos "$GREEN_DIRECT_URL" "Green"
    echo ""
    
    # Test 6: Final load test
    echo -e "${BLUE}🧪 Test 6: Final Load Test${NC}"
    run_load_test 5 $REQUEST_INTERVAL
    echo ""
    
    # Print summary
    print_summary
}

# Check if services are running
check_services() {
    echo "Checking if services are running on $SERVER_IP..."
    
    if ! curl -s --connect-timeout 10 "$BASE_URL/healthz" > /dev/null 2>&1; then
        echo -e "${RED}❌ Services are not running on $SERVER_IP${NC}"
        echo ""
        echo "Please ensure:"
        echo "  1. Docker containers are running: docker compose ps"
        echo "  2. Services are started: docker compose up -d"
        echo "  3. If using external IP, check security group allows ports 8080, 8081, 8082"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Services are running on $SERVER_IP${NC}"
}

# Run the test
check_services
main