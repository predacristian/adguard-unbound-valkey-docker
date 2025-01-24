#!/bin/sh

set -e

echo "Running AdGuard Home server test..."

# Function to check ports
check_ports() {
    echo "Checking ports status..."
    if ! netstat -tuln | grep -qE ':(5353|3000)'; then
        echo "Required ports are not open"
    fi
}

# Function to check process
check_process() {
    echo "Checking AdGuard Home process..."
    if ! pgrep -x "AdGuardHome" > /dev/null; then
        echo "AdGuard Home process not found"
    fi
}

# Function to test AdGuard Home web interface accessibility
test_web_interface() {
    echo "Attempting to connect to AdGuard Home web interface..."
    local web_accessible=false
    for i in 1 2 3; do
        status_code=$(curl -k -L -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3000)
        echo "Attempt $i: HTTP status code: ${status_code}"
        if [ "$status_code" -eq 200 ] || [ "$status_code" -eq 302 ] || [ "$status_code" -eq 307 ]; then
            echo "AdGuard Home web interface is accessible"
            web_accessible=true
            break
        fi
        sleep 2
    done

    if [ "$web_accessible" != "true" ]; then
        echo "AdGuard Home server test failed: Web interface is not accessible"
        exit 1
    fi
}

# Function to test DNS resolution through AdGuard Home
test_dns_resolution() {
    echo "Testing DNS resolution..."
    local dns_working=false
    for i in 1 2 3; do
        nslookup_output=$(nslookup example.com 127.0.0.1)
        echo "$nslookup_output"
        if echo "$nslookup_output" | grep -q 'Address'; then
            echo "DNS resolution test passed"
            dns_working=true
            break
        fi
        echo "DNS resolution attempt $i failed, retrying..."
        sleep 2
    done

    if [ "$dns_working" != "true" ]; then
        echo "AdGuard Home DNS resolution test failed"
        exit 1
    fi
}

# Show diagnostic information
check_ports
check_process

# Run tests
test_web_interface
test_dns_resolution

echo "AdGuard Home server test completed successfully"
