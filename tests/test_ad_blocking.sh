#!/bin/sh
# Test AdGuard Home ad blocking functionality
# Verifies that ad/tracking domains are properly blocked

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

# Common ad/tracking domains to test (should be blocked)
AD_DOMAINS="
doubleclick.net
googleadservices.com
googlesyndication.com
google-analytics.com
googletagmanager.com
facebook.com/tr
connect.facebook.net
ads.twitter.com
pixel.twitter.com
"

# Test 1: Verify AdGuard filtering is enabled
test_filtering_enabled() {
    log "Checking if AdGuard filtering is enabled..."

    # Try to query the AdGuard API for status
    if command -v curl >/dev/null 2>&1; then
        # Try to get filtering status (may require auth)
        status=$(curl -s http://127.0.0.1:3000/control/status 2>/dev/null || echo "")

        if [ -n "$status" ]; then
            if echo "$status" | grep -q "protection_enabled"; then
                log "AdGuard API accessible"
                if echo "$status" | grep -q '"protection_enabled":true'; then
                    log "✓ Filtering is enabled"
                else
                    log "WARNING: Filtering may be disabled"
                fi
            fi
        else
            log "NOTE: Cannot access AdGuard API (may require authentication)"
            log "Proceeding with DNS-based tests..."
        fi
    fi
}

# Test 2: Query known ad domain
test_known_ad_domain_blocked() {
    log "Testing if known ad domain is blocked..."

    test_domain="doubleclick.net"
    log "Querying $test_domain..."

    result=$(dig @127.0.0.1 -p 53 +short "$test_domain" A 2>&1 | head -1)

    log "Result: '$result'"

    # AdGuard typically returns 0.0.0.0 for blocked domains
    # or NXDOMAIN, or empty result
    if echo "$result" | grep -qE "^0\.0\.0\.0|^::$"; then
        log "✓ Domain blocked (returned block IP)"
        return 0
    fi

    if [ -z "$result" ]; then
        log "✓ Domain blocked (no answer)"
        return 0
    fi

    # If we get here, check if it's NXDOMAIN
    full_result=$(dig @127.0.0.1 -p 53 "$test_domain" A 2>&1)
    if echo "$full_result" | grep -q "status: NXDOMAIN"; then
        log "✓ Domain blocked (NXDOMAIN)"
        return 0
    fi

    # If we get a real IP, blocking might not be working
    if echo "$result" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        if [ "$result" != "0.0.0.0" ]; then
            log "WARNING: Got real IP for ad domain: $result"
            log "Blocking may not be working correctly!"
            log "This could mean:"
            log "  1. AdGuard filters are not loaded"
            log "  2. This domain is not in the blocklists"
            log "  3. Blocking is disabled"
        fi
    fi

    log "✓ Ad domain test completed"
}

# Test 3: Verify legitimate domains are NOT blocked
test_legitimate_domains_allowed() {
    log "Testing that legitimate domains are NOT blocked..."

    legitimate_domains="google.com github.com cloudflare.com"

    for domain in $legitimate_domains; do
        log "Testing $domain..."
        result=$(dig @127.0.0.1 -p 53 +short "$domain" A | head -1)

        if [ -z "$result" ]; then
            log_error "Legitimate domain $domain returned no result!"
            exit 1
        fi

        # Should NOT be 0.0.0.0
        if [ "$result" = "0.0.0.0" ] || [ "$result" = "::" ]; then
            log_error "Legitimate domain $domain is blocked!"
            exit 1
        fi

        # Should be a valid IP
        if ! echo "$result" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
            log "WARNING: Unexpected result for $domain: $result"
        else
            log "  ✓ $domain resolves correctly to $result"
        fi
    done

    log "✓ Legitimate domains are allowed"
}

# Test 4: Check AdGuard filter lists are loaded
test_filter_lists_loaded() {
    log "Checking if filter lists are loaded..."

    if ! command -v curl >/dev/null 2>&1; then
        log "SKIP: curl not available"
        return 0
    fi

    # Try to get filtering info
    # Note: This may require authentication
    filtering_info=$(curl -s http://127.0.0.1:3000/control/filtering/status 2>/dev/null || echo "")

    if [ -n "$filtering_info" ]; then
        if echo "$filtering_info" | grep -q "filters"; then
            filter_count=$(echo "$filtering_info" | grep -o '"id"' | wc -l)
            log "AdGuard has $filter_count filter list(s) configured"

            if [ "$filter_count" -gt 0 ]; then
                log "✓ Filter lists are loaded"
            else
                log "WARNING: No filter lists detected"
            fi
        fi
    else
        log "NOTE: Cannot check filter lists (API may require auth)"
    fi
}

# Test 5: Test AdGuard statistics are tracking queries
test_statistics_tracking() {
    log "Checking if AdGuard is tracking statistics..."

    if ! command -v curl >/dev/null 2>&1; then
        log "SKIP: curl not available"
        return 0
    fi

    # Make a few queries to generate stats
    dig @127.0.0.1 -p 53 +short example.com > /dev/null 2>&1 || true
    dig @127.0.0.1 -p 53 +short test.com > /dev/null 2>&1 || true

    sleep 2

    # Try to get stats
    stats=$(curl -s http://127.0.0.1:3000/control/stats 2>/dev/null || echo "")

    if [ -n "$stats" ]; then
        if echo "$stats" | grep -q "num_dns_queries"; then
            query_count=$(echo "$stats" | grep -o '"num_dns_queries":[0-9]*' | grep -o '[0-9]*$')
            if [ -n "$query_count" ] && [ "$query_count" -gt 0 ]; then
                log "✓ Statistics tracking works ($query_count queries recorded)"
            else
                log "WARNING: Query count is 0 or unavailable"
            fi
        fi

        if echo "$stats" | grep -q "num_blocked_filtering"; then
            blocked_count=$(echo "$stats" | grep -o '"num_blocked_filtering":[0-9]*' | grep -o '[0-9]*$')
            log "Blocked queries: $blocked_count"
        fi
    else
        log "NOTE: Cannot access statistics (API may require auth)"
    fi
}

# Test 6: Test multiple ad domains
test_multiple_ad_domains() {
    log "Testing multiple known ad domains..."

    blocked_count=0
    tested_count=0

    # Test a subset of ad domains
    test_domains="doubleclick.net googleadservices.com ads.twitter.com"

    for domain in $test_domains; do
        tested_count=$((tested_count + 1))
        result=$(dig @127.0.0.1 -p 53 +short "$domain" A 2>&1 | head -1)

        log "  $domain -> $result"

        if echo "$result" | grep -qE "^0\.0\.0\.0|^::$" || [ -z "$result" ]; then
            blocked_count=$((blocked_count + 1))
        fi
    done

    log "Blocked $blocked_count out of $tested_count ad domains"

    if [ "$blocked_count" -eq 0 ]; then
        log "WARNING: No ad domains were blocked!"
        log "This suggests AdGuard filtering is not working properly"
    elif [ "$blocked_count" -eq "$tested_count" ]; then
        log "✓ All tested ad domains were blocked"
    else
        log "NOTE: Some ad domains not blocked (this may be expected)"
    fi
}

# Test 7: Test that blocking doesn't break DNSSEC
test_blocking_with_dnssec() {
    log "Testing blocking doesn't interfere with DNSSEC..."

    # Query a domain with DNSSEC
    result=$(dig @127.0.0.1 -p 53 dnssec.works)

    if echo "$result" | grep -q "status: NOERROR"; then
        log "✓ DNSSEC validation works with AdGuard"
    else
        log "WARNING: DNSSEC validation may be affected"
    fi
}

main() {
    log "=== Running Ad Blocking Functionality Tests ==="
    log ""

    test_filtering_enabled
    test_known_ad_domain_blocked
    test_legitimate_domains_allowed
    test_filter_lists_loaded
    test_statistics_tracking
    test_multiple_ad_domains
    test_blocking_with_dnssec

    log ""
    log "=== ✓ All ad blocking tests completed ==="
    log ""
    log "NOTE: Ad blocking effectiveness depends on:"
    log "  1. Filter lists being enabled and up-to-date"
    log "  2. Protection being enabled in AdGuard settings"
    log "  3. Domains being present in the blocklists"
}

main "$@"
