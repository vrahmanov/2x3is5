#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_DOMAIN=${CLUSTER_DOMAIN:-"local.io"}
HTTP_PORT=${HTTP_PORT:-"44134"}
HTTPS_PORT=${HTTPS_PORT:-"6600"}

echo -e "${BLUE}Music App Test Script${NC}"
echo "====================="

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_failure() {
    echo -e "${RED}[FAILURE]${NC} $1"
}

# Test 1: Check if pods are running
echo ""
echo "=== Test 1: Pod Status ==="
print_status "Checking pod status..."

music_app_pods=$(kubectl get pods -n music-app -l app=music-app --no-headers | wc -l)
redis_pods=$(kubectl get pods -n music-app -l app=redis --no-headers | wc -l)

if [ "$music_app_pods" -gt 0 ] && [ "$redis_pods" -gt 0 ]; then
    print_success "Found $music_app_pods music app pods and $redis_pods Redis pods"
    
    # Check if pods are ready
    ready_pods=$(kubectl get pods -n music-app --no-headers | grep -c "Running")
    total_pods=$(kubectl get pods -n music-app --no-headers | wc -l)
    
    if [ "$ready_pods" -eq "$total_pods" ]; then
        print_success "All $total_pods pods are running"
    else
        print_failure "Only $ready_pods/$total_pods pods are running"
    fi
else
    print_failure "No pods found in music-app namespace"
fi

# Test 2: Check services
echo ""
echo "=== Test 2: Service Status ==="
print_status "Checking service status..."

if kubectl get svc music-app -n music-app &> /dev/null; then
    print_success "Music app service exists"
else
    print_failure "Music app service not found"
fi

if kubectl get svc redis -n music-app &> /dev/null; then
    print_success "Redis service exists"
else
    print_failure "Redis service not found"
fi

# Test 3: Check ingress
echo ""
echo "=== Test 3: Ingress Status ==="
print_status "Checking ingress status..."

if kubectl get ingress -n music-app &> /dev/null; then
    print_success "Ingress exists"
    kubectl get ingress -n music-app
else
    print_failure "Ingress not found"
fi

# Test 4: Test health endpoint
echo ""
echo "=== Test 4: Health Check ==="
print_status "Testing health endpoint..."

health_response=$(curl -s -o /dev/null -w "%{http_code}" "http://music.$CLUSTER_DOMAIN:$HTTP_PORT/health" || echo "000")

if [ "$health_response" = "200" ]; then
    print_success "Health endpoint responding (HTTP 200)"
else
    print_failure "Health endpoint failed (HTTP $health_response)"
fi

# Test 5: Test API endpoint
echo ""
echo "=== Test 5: API Endpoint Test ==="
print_status "Testing API endpoint..."

# Test with a known key
api_response=$(curl -s "http://music.$CLUSTER_DOMAIN:$HTTP_PORT/api/v1/music-albums?key=100" || echo "ERROR")

if echo "$api_response" | grep -q "Iron Maiden"; then
    print_success "API endpoint working correctly"
    echo "Response: $api_response"
else
    print_failure "API endpoint test failed"
    echo "Response: $api_response"
fi

# Test 6: Test multiple keys
echo ""
echo "=== Test 6: Multiple API Tests ==="
print_status "Testing multiple API keys..."

test_keys=(1 50 100 200)
success_count=0

for key in "${test_keys[@]}"; do
    response=$(curl -s "http://music.$CLUSTER_DOMAIN:$HTTP_PORT/api/v1/music-albums?key=$key" || echo "ERROR")
    if echo "$response" | grep -q "album"; then
        print_success "Key $key: $(echo "$response" | jq -r '.album' 2>/dev/null || echo "Valid response")"
        ((success_count++))
    else
        print_failure "Key $key: Failed"
    fi
done

print_status "API test results: $success_count/${#test_keys[@]} successful"

# Test 7: Check Redis connectivity
echo ""
echo "=== Test 7: Redis Connectivity ==="
print_status "Checking Redis connectivity..."

if kubectl exec -it deployment/redis -n music-app -- redis-cli -a musicapp123 ping &> /dev/null; then
    print_success "Redis is responding to ping"
else
    print_failure "Redis is not responding"
fi

# Test 8: Check Redis data
echo ""
echo "=== Test 8: Redis Data ==="
print_status "Checking Redis data..."

key_count=$(kubectl exec -it deployment/redis -n music-app -- redis-cli -a musicapp123 KEYS "*" | wc -l)

if [ "$key_count" -gt 0 ]; then
    print_success "Redis contains $key_count keys"
else
    print_failure "Redis is empty"
fi

# Summary
echo ""
echo "=== Test Summary ==="
print_status "All tests completed!"

echo ""
echo "Application URLs:"
echo "  Health: http://music.$CLUSTER_DOMAIN:$HTTP_PORT/health"
echo "  API: http://music.$CLUSTER_DOMAIN:$HTTP_PORT/api/v1/music-albums?key=100"
echo ""
echo "Management Commands:"
echo "  kubectl get pods -n music-app"
echo "  kubectl logs -f deployment/music-app -n music-app"
echo "  kubectl logs -f deployment/redis -n music-app"
