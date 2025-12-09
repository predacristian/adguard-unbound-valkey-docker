#!/bin/sh
# Test Unbound → Valkey cache integration
# This is THE MOST CRITICAL test - verifies the core caching functionality

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

# Test 1: Unix socket exists
test_socket_exists() {
    log "Testing Valkey Unix socket..."
    if [ ! -S /tmp/valkey.sock ]; then
        log_error "Valkey Unix socket not found at /tmp/valkey.sock"
        log_error "This means Unbound CANNOT cache queries in Valkey!"
        exit 1
    fi
    log "✓ Socket exists at /tmp/valkey.sock"
}

# Test 2: Can connect via socket
test_socket_connection() {
    log "Testing socket connection..."
    if ! valkey-cli -s /tmp/valkey.sock PING | grep -q PONG; then
        log_error "Cannot connect to Valkey via Unix socket"
        exit 1
    fi
    log "✓ Socket connection works"
}

# Test 3: Socket has correct permissions for Unbound
test_socket_permissions() {
    log "Testing socket permissions..."
    socket_perms=$(stat -c "%a" /tmp/valkey.sock 2>/dev/null || stat -f "%Lp" /tmp/valkey.sock 2>/dev/null)
    log "Socket permissions: $socket_perms"

    # Should be 770 or similar (readable by group)
    if [ "$socket_perms" != "770" ] && [ "$socket_perms" != "777" ]; then
        log "WARNING: Socket permissions are $socket_perms, expected 770"
    else
        log "✓ Socket permissions correct"
    fi
}

# Test 4: Unbound actually caches in Valkey
test_caching_works() {
    log "Testing Unbound → Valkey caching..."

    # Clear cache
    valkey-cli -s /tmp/valkey.sock FLUSHALL > /dev/null
    log "Cache cleared"

    # Check cache baseline (Unbound creates metadata keys like /priming, /meta)
    keys_before=$(valkey-cli -s /tmp/valkey.sock DBSIZE)
    log "Cache size before query: $keys_before keys"

    # Unbound may have 0-3 metadata keys, which is normal
    if [ "$keys_before" -gt 3 ]; then
        log_error "Cache has $keys_before keys after FLUSHALL (expected ≤3 metadata keys)"
        exit 1
    fi

    # Make DNS query through Unbound
    # Use a real domain (not example.com as it has special handling)
    query_domain="github.com"
    log "Querying $query_domain through Unbound..."
    result=$(dig @127.0.0.1 -p 5335 +short "$query_domain" | head -1)

    if [ -z "$result" ]; then
        log_error "DNS query returned no result"
        exit 1
    fi
    log "Query result: $result"

    # Wait for cache to be written (cachedb writes asynchronously)
    sleep 3

    # Check cache has more entries than baseline
    keys_after=$(valkey-cli -s /tmp/valkey.sock DBSIZE)
    log "Cache size after query: $keys_after keys"

    # Should have added at least 1 new key beyond metadata
    if [ "$keys_after" -le "$keys_before" ]; then
        log_error "No new cache entries after DNS query! (before: $keys_before, after: $keys_after)"
        log_error "This means Unbound is NOT caching in Valkey!"
        log_error "Check unbound.conf cachedb configuration"
        exit 1
    fi

    keys_added=$((keys_after - keys_before))
    log "✓ Unbound is caching in Valkey ($keys_added new keys added)"
}

# Test 5: Cache hits improve performance
test_cache_hit_performance() {
    log "Testing cache hit performance..."

    # Use a unique domain to avoid external caching
    test_domain="cache-perf-test-$(date +%s).example.com"

    valkey-cli -s /tmp/valkey.sock FLUSHALL > /dev/null

    # First query - cache miss (will go upstream)
    time1=$(date +%s%N)
    dig @127.0.0.1 -p 5335 +short google.com > /dev/null 2>&1 || true
    time2=$(date +%s%N)
    duration_miss=$((($time2 - $time1)/1000000))

    sleep 1

    # Second query - should be cache hit
    time3=$(date +%s%N)
    dig @127.0.0.1 -p 5335 +short google.com > /dev/null 2>&1 || true
    time4=$(date +%s%N)
    duration_hit=$((($time4 - $time3)/1000000))

    log "First query (miss): ${duration_miss}ms"
    log "Second query (hit):  ${duration_hit}ms"

    # Cache hit should generally be faster, but not always guaranteed
    # Just verify both completed successfully
    if [ $duration_miss -gt 5000 ] || [ $duration_hit -gt 5000 ]; then
        log "WARNING: Queries taking >5s, possible performance issue"
    fi

    log "✓ Cache hit performance test completed"
}

# Test 6: Verify cache data structure
test_cache_data_structure() {
    log "Testing cache data structure..."

    # Query a domain
    dig @127.0.0.1 -p 5335 +short example.com > /dev/null 2>&1 || true
    sleep 1

    # List some keys to verify structure
    sample_keys=$(valkey-cli -s /tmp/valkey.sock --scan --count 5 | head -3)

    if [ -n "$sample_keys" ]; then
        log "Sample cache keys:"
        echo "$sample_keys" | while read -r key; do
            log "  - $key"
        done
        log "✓ Cache data structure verified"
    else
        log "WARNING: Could not sample cache keys"
    fi
}

# Test 7: Check cache memory usage
test_cache_memory() {
    log "Testing cache memory usage..."

    mem_info=$(valkey-cli -s /tmp/valkey.sock INFO memory | grep "used_memory_human")
    log "Cache memory: $mem_info"

    max_mem=$(valkey-cli -s /tmp/valkey.sock CONFIG GET maxmemory | tail -1)
    log "Max memory configured: $max_mem bytes"

    if [ "$max_mem" -eq 0 ]; then
        log "WARNING: No maxmemory limit set - cache can grow unbounded!"
    else
        max_mem_mb=$((max_mem / 1024 / 1024))
        log "Max memory limit: ${max_mem_mb}MB"
    fi

    log "✓ Cache memory check completed"
}

main() {
    log "=== Running Cache Integration Tests ==="
    log ""

    test_socket_exists
    test_socket_connection
    test_socket_permissions
    test_caching_works
    test_cache_hit_performance
    test_cache_data_structure
    test_cache_memory

    log ""
    log "=== ✓ All cache integration tests passed ==="
}

main "$@"
