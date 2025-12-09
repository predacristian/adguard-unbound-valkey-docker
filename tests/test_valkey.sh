#!/bin/sh

set -e

# Default parameters
VALKEY_PORT="6379"
VALKEY_PROCESS="valkey-server"
VALKEY_HOST="127.0.0.1"
SLEEP_SECONDS="2"
MAX_ATTEMPTS="3"
TEST_KEY="test_key"

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
    for bin in valkey-cli pgrep grep; do
        if ! command -v "$bin" >/dev/null 2>&1; then
            log_error "Required binary '$bin' not found"
            exit 1
        fi
    done
}

check_valkey_process() {
    log "Checking Valkey process..."
    if ! pgrep "$VALKEY_PROCESS" >/dev/null; then
        log_error "Valkey process not found"
        exit 1
    fi
    log "Valkey process is running"
}

check_valkey_port() {
    log "Checking Valkey port status..."
    if command -v ss >/dev/null 2>&1; then
        port_check_cmd="ss -tuln | grep -qE ':${VALKEY_PORT}'"
    else
        port_check_cmd="netstat -tuln | grep -qE ':${VALKEY_PORT}'"
    fi
    if ! eval "$port_check_cmd"; then
        log_error "Valkey port ${VALKEY_PORT} not open"
        exit 1
    fi
    log "Valkey port ${VALKEY_PORT} is open"
}

test_valkey_connection() {
    log "Testing Valkey connection..."
    retry "valkey-cli -p ${VALKEY_PORT} ping | grep -q 'PONG'" "$MAX_ATTEMPTS" "$SLEEP_SECONDS"
    if [ $? -ne 0 ]; then
        log_error "Valkey server test failed: Cannot connect to Valkey"
        exit 1
    fi
    log "Valkey connection successful"
}

test_valkey_operations() {
    log "Testing Valkey operations..."
    if ! valkey-cli -p ${VALKEY_PORT} set ${TEST_KEY} "Hello, Valkey!" > /dev/null; then
        log_error "Valkey SET operation failed"
        exit 1
    fi
    value=$(valkey-cli -p ${VALKEY_PORT} get ${TEST_KEY})
    if [ "$value" != "Hello, Valkey!" ]; then
        log_error "Valkey GET operation failed"
        exit 1
    fi
    if ! valkey-cli -p ${VALKEY_PORT} exists ${TEST_KEY} > /dev/null; then
        log_error "Valkey EXISTS operation failed"
        exit 1
    fi
    if ! valkey-cli -p ${VALKEY_PORT} del ${TEST_KEY} > /dev/null; then
        log_error "Valkey DEL operation failed"
        exit 1
    fi
    log "Valkey operations passed"
}

test_valkey_performance() {
    log "Testing Valkey performance..."
    start_time=$(date +%s%N)
    valkey-cli -p ${VALKEY_PORT} ping | grep -q 'PONG'
    end_time=$(date +%s%N)
    duration=$((($end_time - $start_time)/1000000))
    log "Response time: ${duration}ms"
    if [ $duration -gt 1000 ]; then
        log_error "Valkey response time is high (${duration}ms)"
        exit 1
    fi
    log "Valkey response time is acceptable"
}

main() {
    log "Running Valkey server test..."
    check_binaries
    check_valkey_process
    check_valkey_port
    test_valkey_connection
    test_valkey_operations
    test_valkey_performance
    log "Valkey server test completed successfully"
}

main "$@"
