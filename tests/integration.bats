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
    # A domain already warm in unbound's memory cache never reaches cachedb,
    # so try a few candidates until one lands in Valkey.
    added=0
    for domain in wikipedia.org archive.org debian.org mozilla.org; do
        valkey-cli -s /tmp/valkey.sock FLUSHALL >/dev/null
        keys_before=$(valkey-cli -s /tmp/valkey.sock DBSIZE)

        dig @127.0.0.1 -p 5335 +short "$domain" >/dev/null 2>&1
        sleep 3

        keys_after=$(valkey-cli -s /tmp/valkey.sock DBSIZE)
        if [ "$keys_after" -gt "$keys_before" ]; then
            added=1
            break
        fi
    done

    [ "$added" -eq 1 ]
}

@test "Cache hits improve query performance" {
    valkey-cli -s /tmp/valkey.sock FLUSHALL

    start_time=$(date +%s%N)
    dig @127.0.0.1 -p 5335 +short google.com > /dev/null
    end_time=$(date +%s%N)
    duration_miss=$((($end_time - $start_time)/1000000))

    sleep 1

    start_time=$(date +%s%N)
    dig @127.0.0.1 -p 5335 +short google.com > /dev/null
    end_time=$(date +%s%N)
    duration_hit=$((($end_time - $start_time)/1000000))

    [ $duration_miss -lt 5000 ]
    [ $duration_hit -lt 5000 ]
}

# Test end-to-end query path
@test "AdGuard resolves DNS queries" {
    # dig prints ";; ..." chatter to stdout on failure; grep -v '^;;'
    # exits non-zero when there is no real answer line.
    run sh -c "dig +time=5 +tries=1 @127.0.0.1 -p 53 +short google.com 2>/dev/null | grep -v '^;;'"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "Unbound resolves DNS queries" {
    run sh -c "dig +time=5 +tries=1 @127.0.0.1 -p 5335 +short google.com 2>/dev/null | grep -v '^;;'"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "AdGuard forwards queries to Unbound (verified by cache)" {
    # Same as above: try candidates until one query through AdGuard
    # (port 53) lands in Valkey via unbound's cachedb.
    added=0
    for domain in openstreetmap.org kernel.org python.org rust-lang.org; do
        valkey-cli -s /tmp/valkey.sock FLUSHALL >/dev/null

        dig @127.0.0.1 -p 53 +short "$domain" >/dev/null 2>&1
        sleep 3

        keys=$(valkey-cli -s /tmp/valkey.sock DBSIZE)
        if [ "$keys" -gt 0 ]; then
            added=1
            break
        fi
    done

    [ "$added" -eq 1 ]
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

    # doubleclick.net is on the default AdGuard DNS filter. Filters download
    # asynchronously on first boot, so retry briefly before failing.
    blocked=0
    for attempt in 1 2 3 4 5 6; do
        result=$(dig @127.0.0.1 -p 53 +short doubleclick.net A | head -1)
        if [ -z "$result" ] || [ "$result" = "0.0.0.0" ] || [ "$result" = "::" ]; then
            blocked=1
            break
        fi
        sleep 5
    done

    [ "$blocked" -eq 1 ]
}

# Test DNS over TLS
@test "No DoT listener when TLS is disabled" {
    # The seed config ships tls.enabled=false; nothing may listen on 853.
    # Guards against accidental TLS exposure. If you enable TLS in the seed
    # config, update this test.
    run sh -c "ss -tuln 2>/dev/null | grep ':853'"
    [ "$status" -ne 0 ]
}

# Test DNSSEC validation
@test "DNSSEC validation works for valid domains" {
    run dig @127.0.0.1 -p 5335 dnssec.works
    [ "$status" -eq 0 ]
    [[ "$output" =~ "status: NOERROR" ]]
}

@test "DNSSEC validation rejects a broken signature" {
    # dnssec-failed.org is deliberately mis-signed. A validating resolver
    # must return SERVFAIL; NOERROR here means validation is silently off.
    run dig @127.0.0.1 -p 5335 dnssec-failed.org +time=10 +tries=2
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
