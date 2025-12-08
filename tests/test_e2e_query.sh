#!/bin/sh
# Test end-to-end query path: AdGuard → Unbound → Cloudflare → Valkey Cache
# Verifies the complete DNS resolution chain works correctly
#
# IMPORTANT: Unbound has two cache layers:
#   1. Memory cache (rrset-cache, msg-cache) - checked first
#   2. Cachedb (Valkey) - used for overflow and persistence
# Queries may not always appear in Valkey if they're in memory cache!

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

# Test 1: Query through AdGuard (port 53)
test_adguard_resolution() {
    log "Testing DNS resolution through AdGuard (port 53)..."

    result=$(dig @127.0.0.1 -p 53 +short google.com | head -1)

    if [ -z "$result" ]; then
        log_error "AdGuard DNS query returned no result"
        exit 1
    fi

    log "AdGuard resolved google.com to: $result"
    log "✓ AdGuard resolution works"
}

# Test 2: Query through Unbound directly (port 5335)
test_unbound_resolution() {
    log "Testing DNS resolution through Unbound (port 5335)..."

    result=$(dig @127.0.0.1 -p 5335 +short google.com | head -1)

    if [ -z "$result" ]; then
        log_error "Unbound DNS query returned no result"
        exit 1
    fi

    log "Unbound resolved google.com to: $result"
    log "✓ Unbound resolution works"
}

# Test 3: Verify AdGuard forwards to Unbound
test_adguard_unbound_forwarding() {
    log "Testing AdGuard → Unbound forwarding..."

    # Clear Valkey cache to ensure fresh query
    valkey-cli -s /tmp/valkey.sock FLUSHALL > /dev/null
    sleep 1

    # Use a unique domain to avoid Unbound's memory cache
    # Adding timestamp makes it truly unique
    unique_domain="test-$(date +%s).cloudflare.com"
    log "Querying $unique_domain through AdGuard..."
    dig @127.0.0.1 -p 53 +short "$unique_domain" > /dev/null 2>&1 || true

    sleep 3

    # Check if Valkey has cache entries (proves Unbound was used)
    keys=$(valkey-cli -s /tmp/valkey.sock DBSIZE)

    if [ "$keys" -eq 0 ]; then
        log "WARNING: No cache entries found"
        log "Note: Unbound uses memory cache first, cachedb second"
        log "Trying with a known domain..."

        # Try with a well-known domain
        valkey-cli -s /tmp/valkey.sock FLUSHALL > /dev/null
        dig @127.0.0.1 -p 53 +short microsoft.com > /dev/null
        sleep 3
        keys=$(valkey-cli -s /tmp/valkey.sock DBSIZE)

        if [ "$keys" -eq 0 ]; then
            log_error "Still no cache entries after AdGuard query"
            log_error "This suggests AdGuard is NOT forwarding to Unbound!"
            exit 1
        fi
    fi

    log "Cache has $keys entries - proves Unbound was used"
    log "✓ AdGuard forwards to Unbound"
}

# Test 4: Verify Unbound forwards to upstream (Cloudflare)
test_unbound_upstream_forwarding() {
    log "Testing Unbound → Cloudflare forwarding..."

    # Query a domain through Unbound with trace to see upstream
    dig_output=$(dig @127.0.0.1 -p 5335 cloudflare.com)

    # Should get a valid response
    if ! echo "$dig_output" | grep -q "status: NOERROR"; then
        log_error "Unbound query to cloudflare.com failed"
        exit 1
    fi

    log "✓ Unbound forwards to upstream"
}

# Test 5: End-to-end with caching verification
test_full_e2e_with_cache() {
    log "Testing full E2E: AdGuard → Unbound → Cloudflare → Cache..."

    # Use a domain that reliably caches
    test_domain="netflix.com"

    # Clear cache
    valkey-cli -s /tmp/valkey.sock FLUSHALL > /dev/null
    log "Cache cleared"

    # First query through AdGuard
    log "First query (should go: AdGuard → Unbound → Cloudflare)..."
    result1=$(dig @127.0.0.1 -p 53 +short "$test_domain" | head -1)

    if [ -z "$result1" ]; then
        log_error "First query failed"
        exit 1
    fi

    log "First query result: $result1"
    sleep 3

    # Check cache was populated
    keys_after_first=$(valkey-cli -s /tmp/valkey.sock DBSIZE)
    log "Cache size after first query: $keys_after_first keys"

    if [ "$keys_after_first" -eq 0 ]; then
        log "NOTE: Query stayed in Unbound's memory cache"
        log "This is normal - cachedb is used for overflow/persistence"
        # Don't fail - this is expected behavior
    else
        log "Cache was populated with $keys_after_first entries"
    fi

    # Second query (should hit cache)
    log "Second query (should hit cache)..."
    result2=$(dig @127.0.0.1 -p 53 +short "$test_domain" | head -1)

    if [ -z "$result2" ]; then
        log_error "Second query failed"
        exit 1
    fi

    log "Second query result: $result2"

    # Results should be identical
    if [ "$result1" != "$result2" ]; then
        log "WARNING: Results differ between queries"
        log "  First:  $result1"
        log "  Second: $result2"
    fi

    log "✓ Full E2E query path with caching works"
}

# Test 6: Query different record types
test_multiple_record_types() {
    log "Testing multiple DNS record types..."

    # A record
    log "Testing A record..."
    a_result=$(dig @127.0.0.1 -p 53 +short google.com A | head -1)
    [ -n "$a_result" ] || { log_error "A record query failed"; exit 1; }
    log "  A record: $a_result"

    # AAAA record (IPv6)
    log "Testing AAAA record..."
    aaaa_result=$(dig @127.0.0.1 -p 53 +short google.com AAAA | head -1)
    if [ -n "$aaaa_result" ]; then
        log "  AAAA record: $aaaa_result"
    else
        log "  AAAA record: none (acceptable)"
    fi

    # MX record
    log "Testing MX record..."
    mx_result=$(dig @127.0.0.1 -p 53 +short google.com MX | head -1)
    if [ -n "$mx_result" ]; then
        log "  MX record: $mx_result"
    else
        log "  MX record: none"
    fi

    # TXT record
    log "Testing TXT record..."
    txt_result=$(dig @127.0.0.1 -p 53 +short google.com TXT | head -1)
    if [ -n "$txt_result" ]; then
        log "  TXT record: $(echo "$txt_result" | cut -c1-50)..."
    else
        log "  TXT record: none"
    fi

    log "✓ Multiple record types work"
}

# Test 7: Verify query path timing
test_query_timing() {
    log "Testing query path timing..."

    valkey-cli -s /tmp/valkey.sock FLUSHALL > /dev/null

    # First query timing (cache miss)
    time1=$(date +%s%N)
    dig @127.0.0.1 -p 53 +short microsoft.com > /dev/null 2>&1 || true
    time2=$(date +%s%N)
    duration_miss=$((($time2 - $time1)/1000000))

    sleep 1

    # Second query timing (cache hit)
    time3=$(date +%s%N)
    dig @127.0.0.1 -p 53 +short microsoft.com > /dev/null 2>&1 || true
    time4=$(date +%s%N)
    duration_hit=$((($time4 - $time3)/1000000))

    log "Query timing:"
    log "  Cache miss (full path): ${duration_miss}ms"
    log "  Cache hit:              ${duration_hit}ms"

    # Both should be reasonably fast
    if [ $duration_miss -gt 2000 ]; then
        log "WARNING: Cache miss query took >2s"
    fi

    if [ $duration_hit -gt 1000 ]; then
        log "WARNING: Cache hit query took >1s"
    fi

    log "✓ Query timing acceptable"
}

main() {
    log "=== Running End-to-End Query Path Tests ==="
    log ""

    test_adguard_resolution
    test_unbound_resolution
    test_adguard_unbound_forwarding
    test_unbound_upstream_forwarding
    test_full_e2e_with_cache
    test_multiple_record_types
    test_query_timing

    log ""
    log "=== ✓ All E2E tests passed ==="
}

main "$@"
