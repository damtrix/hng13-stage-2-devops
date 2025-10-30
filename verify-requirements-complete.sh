#!/bin/bash

# Complete Requirements Verification Script
# Tests all requirements from the DevOps Stage 2 task

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SERVER_IP=${SERVER_IP:-"18.219.113.57"}
BASE_URL="http://$SERVER_IP:8080"
BLUE_DIRECT_URL="http://$SERVER_IP:8081"
GREEN_DIRECT_URL="http://$SERVER_IP:8082"

echo -e "${BLUE}🔍 Complete Requirements Verification${NC}"
echo "=============================================="
echo "Server: $SERVER_IP"
echo ""

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

# Function to check response with headers
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

# Test 1: Main application endpoint (8080)
run_test "Main Application Endpoint (8080)" \
    "curl -s -w '%{http_code}' -o /dev/null $BASE_URL/version | grep -q '200'"

# Test 2: Blue service direct access (8081)
run_test "Blue Service Direct Access (8081)" \
    "curl -s -w '%{http_code}' -o /dev/null $BLUE_DIRECT_URL/version | grep -q '200'"

# Test 3: Green service direct access (8082)
run_test "Green Service Direct Access (8082)" \
    "curl -s -w '%{http_code}' -o /dev/null $GREEN_DIRECT_URL/version | grep -q '200'"

# Test 4: Headers are properly forwarded (Blue active)
run_test "X-App-Pool Header (Blue Active)" \
    "check_response '$BASE_URL/version' 'blue' 'blue-release-v1.0.0'"

# Test 5: Chaos endpoints work
run_test "Blue Chaos Start Endpoint" \
    "curl -s -X POST '$BLUE_DIRECT_URL/chaos/start?mode=error' | grep -q 'activated'"

run_test "Blue Chaos Stop Endpoint" \
    "curl -s -X POST '$BLUE_DIRECT_URL/chaos/stop' | grep -q 'stopped'"

# Test 6: Health check endpoints
run_test "Main Health Check" \
    "curl -s -w '%{http_code}' -o /dev/null $BASE_URL/healthz | grep -q '200'"

run_test "Blue Health Check" \
    "curl -s -w '%{http_code}' -o /dev/null $BLUE_DIRECT_URL/healthz | grep -q '200'"

run_test "Green Health Check" \
    "curl -s -w '%{http_code}' -o /dev/null $GREEN_DIRECT_URL/healthz | grep -q '200'"

# Test 7: Failover behavior
echo -e "${YELLOW}🧪 Testing: Failover Behavior${NC}"
echo "Starting chaos on Blue service..."
curl -s -X POST "$BLUE_DIRECT_URL/chaos/start?mode=error" > /dev/null
sleep 2

# Check if traffic switches to Green
if check_response "$BASE_URL/version" "green" "green-release-v1.0.0"; then
    echo -e "${GREEN}✅ FAILOVER PASSED - Traffic switched to Green${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAILOVER FAILED - Traffic did not switch to Green${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 8: Stability under failure (multiple requests)
echo "Testing stability under failure (5 requests)..."
stability_passed=true
for i in {1..5}; do
    if ! check_response "$BASE_URL/version" "green" "green-release-v1.0.0"; then
        echo -e "${RED}❌ Request $i failed stability test${NC}"
        stability_passed=false
        break
    fi
done

if [ "$stability_passed" = true ]; then
    echo -e "${GREEN}✅ STABILITY PASSED - All requests successful during failure${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ STABILITY FAILED - Some requests failed during failure${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Stop chaos
curl -s -X POST "$BLUE_DIRECT_URL/chaos/stop" > /dev/null
sleep 5

# Test 9: Recovery behavior
echo "Testing recovery behavior..."
recovery_passed=false
for i in {1..5}; do
    if check_response "$BASE_URL/version" "blue" "blue-release-v1.0.0"; then
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
echo "=============================================="
echo -e "${BLUE}📊 VERIFICATION SUMMARY${NC}"
echo "=============================================="
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
    echo "✅ Stability under failure is maintained"
    echo "✅ Recovery behavior is working"
    exit 0
else
    echo -e "${RED}❌ SOME REQUIREMENTS NOT MET${NC}"
    echo "Please check the failed tests above"
    exit 1
fi
