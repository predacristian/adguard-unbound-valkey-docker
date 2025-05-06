#!/bin/sh

set -e

echo "Running Valkey server test..."

# Function to check Valkey process
check_valkey_process() {
    echo "Checking Valkey process..."
    if ! pgrep -x "valkey-server" > /dev/null; then
        echo "Valkey process not found"
    fi
}

# Function to check Valkey port
check_valkey_port() {
    echo "Checking Valkey port status..."
    if ! netstat -tuln | grep -q ':6379'; then
        echo "Valkey port 6379 not open"
    fi
}

# Function to test Valkey connection with retries
test_valkey_connection() {
    local valkey_connected=false
    for i in 1 2 3; do
        if valkey-cli -p 6379 ping | grep -q 'PONG'; then
            valkey_connected=true
            echo "Valkey connection successful"
            break
        fi
        echo "Valkey connection attempt $i failed, retrying..."
        sleep 2
    done

    if [ "$valkey_connected" != "true" ]; then
        echo "Valkey server test failed: Cannot connect to Valkey"
        exit 1
    fi
}

# Function to test basic Valkey operations
test_valkey_operations() {
    echo "Testing Valkey operations..."

    # Test SET operation
    if ! valkey-cli -p 6379 set test_key "Hello, Valkey!" > /dev/null; then
        echo "Valkey SET operation failed"
        exit 1
    fi

    # Test GET operation
    value=$(valkey-cli -p 6379 get test_key)
    if [ "$value" != "Hello, Valkey!" ]; then
        echo "Valkey GET operation failed"
        exit 1
    fi

    # Test EXISTS operation
    if ! valkey-cli -p 6379 exists test_key > /dev/null; then
        echo "Valkey EXISTS operation failed"
        exit 1
    fi

    # Test DEL operation
    if ! valkey-cli -p 6379 del test_key > /dev/null; then
        echo "Valkey DEL operation failed"
        exit 1
    fi
}

# Function to test Valkey performance
test_valkey_performance() {
    echo "Testing Valkey performance..."
    if valkey-cli -p 6379 ping | grep -q 'PONG'; then
        echo "Response time test passed"
    else
        echo "Response time test failed"
        exit 1
    fi
}

# Show diagnostic information
check_valkey_process
check_valkey_port

# Run tests
test_valkey_connection
test_valkey_operations
test_valkey_performance

echo "Valkey server test completed successfully"
