#!/bin/sh

set -e

# Default parameters
UNBOUND_PORT="5335"
UNBOUND_PROCESS="unbound"
UNBOUND_HOST="127.0.0.1"
SLEEP_SECONDS="2"
MAX_ATTEMPTS="3"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

retry() {
    cmd="$1"
    max_attempts="${2:-$MAX_ATTEMPTS}"
    sleep_seconds="${3:-$SLEEP_SECONDS}"
    attempt=1
    while [ "$attempt" -le "$max_attempts" ]; do
        if eval "$cmd"; then
            return 0
        fi
        log "Attempt $attempt failed, retrying..."
        sleep "$sleep_seconds"
        attempt=$((attempt + 1))
    done
    return 1
}

check_binaries() {
    for bin in dig pgrep grep; do
        if ! command -v "$bin" >/dev/null 2>&1; then
            log_error "Required binary '$bin' not found"
            exit 1
        fi
    done
}

check_unbound_process() {
    log "Checking Unbound process..."
    if ! pgrep "$UNBOUND_PROCESS" >/dev/null; then
        log_error "Unbound process not found"
        exit 1
    fi
    log "Unbound process is running"
}

check_unbound_port() {
    log "Checking Unbound port status..."
    if command -v ss >/dev/null 2>&1; then
        port_check_cmd="ss -tuln | grep -qE ':${UNBOUND_PORT}'"
    else
        port_check_cmd="netstat -tuln | grep -qE ':${UNBOUND_PORT}'"
    fi
    if ! eval "$port_check_cmd"; then
        log_error "Unbound port ${UNBOUND_PORT} not open"
        exit 1
    fi
    log "Unbound port ${UNBOUND_PORT} is open"
}

test_dns_resolution() {
    log "Testing basic DNS resolution..."
    retry "dig_output=\$(dig +short @${UNBOUND_HOST} -p ${UNBOUND_PORT} google.com); [ -n \"\$dig_output\" ]" "$MAX_ATTEMPTS" "$SLEEP_SECONDS"
    if [ $? -ne 0 ]; then
        log_error "Basic DNS resolution test failed"
        exit 1
    fi
    log "Basic DNS resolution working"
}

test_dnssec_validation() {
    log "Testing DNSSEC validation..."
    log "Testing valid DNSSEC domain (dnssec.works)..."
    dig_output=$(dig @${UNBOUND_HOST} -p ${UNBOUND_PORT} dnssec.works)
    echo "$dig_output"
    if ! echo "$dig_output" | grep -q 'status: NOERROR'; then
        log_error "Valid DNSSEC test failed"
        exit 1
    fi
    log "Testing invalid DNSSEC domain (fail01.dnssec.works)..."
    dig_output=$(dig @${UNBOUND_HOST} -p ${UNBOUND_PORT} fail01.dnssec.works)
    echo "$dig_output"
    if ! echo "$dig_output" | grep -q 'status: SERVFAIL'; then
        log_error "Invalid DNSSEC test failed"
        exit 1
    fi
    log "DNSSEC validation tests passed"
}

test_reverse_dns() {
    log "Testing reverse DNS..."
    dig_output=$(dig @${UNBOUND_HOST} -p ${UNBOUND_PORT} -x 8.8.8.8)
    echo "$dig_output"
    if ! echo "$dig_output" | grep -qE 'PTR.*dns.google'; then
        log_error "Reverse DNS test failed"
        exit 1
    fi
    log "Reverse DNS test passed"
}

test_dns_response_time() {
    log "Testing DNS response time..."
    start_time=$(date +%s%N)
    dig @${UNBOUND_HOST} -p ${UNBOUND_PORT} +short google.com > /dev/null
    end_time=$(date +%s%N)
    duration=$((($end_time - $start_time)/1000000))
    log "Response time: ${duration}ms"
    if [ $duration -gt 1000 ]; then
        log_error "DNS response time is high (${duration}ms)"
        exit 1
    fi
    log "DNS response time is acceptable"
}

main() {
    log "Running Unbound DNS server test..."
    check_binaries
    check_unbound_process
    check_unbound_port
    test_dns_resolution
    test_dnssec_validation
    test_reverse_dns
    test_dns_response_time
    log "All DNS tests completed successfully"
}

main "$@"
