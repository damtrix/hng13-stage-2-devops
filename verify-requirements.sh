#!/bin/bash

# Blue/Green Deployment Requirements Verification Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Blue/Green Deployment Requirements Verification${NC}"
echo "=============================================================="

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    echo -e "${YELLOW}🧪 Testing: $test_name${NC}"
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    echo ""
}

# Function to check HTTP response with headers
check_response() {
    local url="$1"
    local expected_pool="$2"
    local expected_release="$3"
    
    response=$(curl -s -I "$url" 2>/dev/null)
    http_code=$(curl -s -w "%{http_code}" -o /dev/null "$url" 2>/dev/null)
    
    if [ "$http_code" = "200" ]; then
        if echo "$response" | grep -qi "x-app-pool: $expected_pool" && \
           echo "$response" | grep -qi "x-release-id: $expected_release"; then
            return 0
        fi
    fi
    return 1
}

echo "🔧 Testing Core Requirements..."
echo ""

# Test 1: Main application endpoint
run_test "Main Application Endpoint (8080)" \
    "curl -s -w '%{http_code}' -o /dev/null http://localhost:8080/version | grep -q '200'"

# Test 2: Blue service direct access
run_test "Blue Service Direct Access (8081)" \
    "curl -s -w '%{http_code}' -o /dev/null http://localhost:8081/version | grep -q '200'"

# Test 3: Green service direct access
run_test "Green Service Direct Access (8082)" \
    "curl -s -w '%{http_code}' -o /dev/null http://localhost:8082/version | grep -q '200'"

# Test 4: Headers are properly forwarded
run_test "X-App-Pool Header (Blue)" \
    "check_response 'http://localhost:8080/version' 'blue' 'blue-release-v1.0.0'"

# Test 5: Chaos endpoints work
run_test "Blue Chaos Start Endpoint" \
    "curl -s -X POST http://localhost:8081/chaos/start?mode=error | grep -q 'activated'"

run_test "Blue Chaos Stop Endpoint" \
    "curl -s -X POST http://localhost:8081/chaos/stop | grep -q 'stopped'"

# Test 6: Health check endpoints
run_test "Main Health Check" \
    "curl -s -w '%{http_code}' -o /dev/null http://localhost:8080/healthz | grep -q '200'"

run_test "Blue Health Check" \
    "curl -s -w '%{http_code}' -o /dev/null http://localhost:8081/healthz | grep -q '200'"

run_test "Green Health Check" \
    "curl -s -w '%{http_code}' -o /dev/null http://localhost:8082/healthz | grep -q '200'"

# Test 7: Failover behavior
echo -e "${YELLOW}🧪 Testing: Failover Behavior${NC}"
echo "Starting chaos on Blue service..."
curl -s -X POST http://localhost:8081/chaos/start?mode=error > /dev/null
sleep 2

# Check if traffic switches to Green
if check_response 'http://localhost:8080/version' 'green' 'green-release-v1.0.0'; then
    echo -e "${GREEN}✅ FAILOVER PASSED - Traffic switched to Green${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAILOVER FAILED - Traffic did not switch to Green${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Stop chaos
curl -s -X POST http://localhost:8081/chaos/stop > /dev/null
sleep 10

# Check if traffic returns to Blue (with retry)
recovery_passed=false
for i in {1..5}; do
    if check_response 'http://localhost:8080/version' 'blue' 'blue-release-v1.0.0'; then
        echo -e "${GREEN}✅ RECOVERY PASSED - Traffic returned to Blue${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        recovery_passed=true
        break
    fi
    echo "Waiting for recovery... attempt $i/5"
    sleep 2
done

if [ "$recovery_passed" = false ]; then
    echo -e "${RED}❌ RECOVERY FAILED - Traffic did not return to Blue${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""

# Test 8: Environment variables
echo -e "${YELLOW}🧪 Testing: Environment Configuration${NC}"
if [ -f ".env" ]; then
    echo -e "${GREEN}✅ .env file exists${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ .env file missing${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 9: Docker Compose services
echo -e "${YELLOW}🧪 Testing: Docker Compose Services${NC}"
if  ps | grep -q "Up"; then
    echo -e "${GREEN}✅ All services are running${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ Services not running${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "=============================================================="
echo -e "${BLUE}📊 VERIFICATION SUMMARY${NC}"
echo "=============================================================="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL REQUIREMENTS VERIFIED!${NC}"
    echo ""
    echo "✅ Blue/Green deployment is working correctly"
    echo "✅ All endpoints are accessible"
    echo "✅ Headers are properly forwarded"
    echo "✅ Chaos simulation works"
    echo "✅ Automatic failover is functional"
    echo "✅ Environment configuration is correct"
    echo "✅ Docker Compose services are running"
    exit 0
else
    echo -e "${RED}❌ SOME REQUIREMENTS NOT MET${NC}"
    echo "Please check the failed tests above"
    exit 1
fi
