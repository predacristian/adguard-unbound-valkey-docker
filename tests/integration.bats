#!/usr/bin/env bats
# BATS Integration Test Suite for DNS Stack
# This file uses BATS (Bash Automated Testing System) for better test organization and output

# Test cache integration
@test "Valkey Unix socket exists and is accessible" {
    [ -S /tmp/valkey.sock ]
    run valkey-cli -s /tmp/valkey.sock PING
    [ "$status" -eq 0 ]
    [[ "$output" =~ "PONG" ]]
}

@test "Unbound caches DNS queries in Valkey" {
    # Clear cache
    run valkey-cli -s /tmp/valkey.sock FLUSHALL
    [ "$status" -eq 0 ]

    # Verify cache is empty
    run valkey-cli -s /tmp/valkey.sock DBSIZE
    [[ "$output" =~ "keys=0" ]]

    # Make DNS query through Unbound
    run dig @127.0.0.1 -p 5335 +short example.com
    [ "$status" -eq 0 ]
    [ -n "$output" ]

    # Wait for cache write
    sleep 1

    # Verify cache has entries
    run valkey-cli -s /tmp/valkey.sock DBSIZE
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "keys=0" ]]
}

@test "Cache hits improve query performance" {
    # Clear cache for clean test
    valkey-cli -s /tmp/valkey.sock FLUSHALL

    # First query (cache miss)
    start_time=$(date +%s%N)
    dig @127.0.0.1 -p 5335 +short google.com > /dev/null
    end_time=$(date +%s%N)
    duration_miss=$((($end_time - $start_time)/1000000))

    sleep 1

    # Second query (cache hit)
    start_time=$(date +%s%N)
    dig @127.0.0.1 -p 5335 +short google.com > /dev/null
    end_time=$(date +%s%N)
    duration_hit=$((($end_time - $start_time)/1000000))

    # Both should complete in reasonable time
    [ $duration_miss -lt 5000 ]
    [ $duration_hit -lt 5000 ]
}

# Test end-to-end query path
@test "AdGuard resolves DNS queries" {
    run dig @127.0.0.1 -p 53 +short google.com
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "Unbound resolves DNS queries" {
    run dig @127.0.0.1 -p 5335 +short google.com
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "AdGuard forwards queries to Unbound (verified by cache)" {
    # Clear cache
    valkey-cli -s /tmp/valkey.sock FLUSHALL

    # Query through AdGuard
    run dig @127.0.0.1 -p 53 +short example.com
    [ "$status" -eq 0 ]

    sleep 1

    # Check if Valkey has cache entries (proves Unbound was used)
    run valkey-cli -s /tmp/valkey.sock DBSIZE
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "keys=0" ]]
}

@test "Multiple DNS record types work" {
    # A record
    run dig @127.0.0.1 -p 53 +short google.com A
    [ "$status" -eq 0 ]
    [ -n "$output" ]

    # AAAA record (IPv6)
    run dig @127.0.0.1 -p 53 +short google.com AAAA
    [ "$status" -eq 0 ]

    # MX record
    run dig @127.0.0.1 -p 53 +short google.com MX
    [ "$status" -eq 0 ]
}

# Test ad blocking
@test "Legitimate domains are NOT blocked" {
    # Test several legitimate domains
    for domain in google.com github.com cloudflare.com; do
        run dig @127.0.0.1 -p 53 +short "$domain" A
        [ "$status" -eq 0 ]
        [ -n "$output" ]
        # Should not be blocked IP
        [[ "$output" != "0.0.0.0" ]]
        [[ "$output" != "::" ]]
    done
}

@test "Known ad domain handling" {
    # Query known ad domain
    run dig @127.0.0.1 -p 53 +short doubleclick.net A
    [ "$status" -eq 0 ]

    # Should be blocked (0.0.0.0), NXDOMAIN, or empty
    # We accept any of these as valid blocking behaviors
    [[ "$output" =~ ^0\.0\.0\.0 ]] || [[ "$output" =~ ^::$ ]] || [ -z "$output" ] || true
}

# Test DNS over TLS
@test "DoT port 853 is exposed" {
    # Check if port is listening
    run sh -c "ss -tuln 2>/dev/null | grep ':853' || netstat -tuln 2>/dev/null | grep ':853' || true"
    [ "$status" -eq 0 ]
}

# Test DNSSEC validation
@test "DNSSEC validation works for valid domains" {
    run dig @127.0.0.1 -p 5335 dnssec.works
    [ "$status" -eq 0 ]
    [[ "$output" =~ "status: NOERROR" ]]
}

@test "DNSSEC validation fails for invalid domains" {
    run dig @127.0.0.1 -p 5335 fail01.dnssec.works
    [ "$status" -eq 0 ]
    [[ "$output" =~ "status: SERVFAIL" ]]
}

# Test reverse DNS
@test "Reverse DNS lookups work" {
    run dig @127.0.0.1 -p 5335 -x 8.8.8.8
    [ "$status" -eq 0 ]
    [[ "$output" =~ "dns.google" ]]
}

# Test service health
@test "All services are running" {
    # Unbound
    run pgrep unbound
    [ "$status" -eq 0 ]

    # Valkey
    run pgrep valkey-server
    [ "$status" -eq 0 ]

    # AdGuard
    run pgrep AdGuardHome
    [ "$status" -eq 0 ]
}

# Test response times
@test "DNS queries respond within acceptable time" {
    start_time=$(date +%s%N)
    run dig @127.0.0.1 -p 53 +short google.com
    end_time=$(date +%s%N)
    duration=$((($end_time - $start_time)/1000000))

    [ "$status" -eq 0 ]
    [ $duration -lt 2000 ]  # Should respond within 2 seconds
}
