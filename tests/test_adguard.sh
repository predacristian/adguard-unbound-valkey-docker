#!/bin/sh

set -e

# Default parameters
ADGUARD_PORT="3000"
DNS_PORT="53"
ADGUARD_PROCESS="AdGuardHome"
ADGUARD_HOST="127.0.0.1"
WEB_URL="http://${ADGUARD_HOST}:${ADGUARD_PORT}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

retry() {
    cmd="$1"
    max_attempts="${2:-3}"
    sleep_seconds="${3:-2}"
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

check_ports() {
    log "Checking ports status..."
    if command -v ss >/dev/null 2>&1; then
        port_check_cmd="ss -tuln | grep -qE ':(${DNS_PORT}|${ADGUARD_PORT})'"
    else
        port_check_cmd="netstat -tuln | grep -qE ':(${DNS_PORT}|${ADGUARD_PORT})'"
    fi
    if ! eval "$port_check_cmd"; then
        log_error "Required ports ${DNS_PORT} or ${ADGUARD_PORT} are not open"
        exit 1
    fi
    log "Required ports are open"
}

check_process() {
    log "Checking AdGuard Home process..."
    if ! pgrep "$ADGUARD_PROCESS" >/dev/null; then
        log_error "AdGuard Home process not found"
        exit 1
    fi
    log "AdGuard Home process is running"
}

test_web_interface() {
    log "Testing AdGuard Home web interface..."
    retry "status_code=\$(curl -k -L -s -o /dev/null -w '%{http_code}' $WEB_URL); [ \"\$status_code\" -eq 200 ] || [ \"\$status_code\" -eq 302 ] || [ \"\$status_code\" -eq 307 ] || [ \"\$status_code\" -eq 401 ] || [ \"\$status_code\" -eq 403 ]" 3 2
    if [ $? -ne 0 ]; then
        log_error "AdGuard Home web interface is not accessible at $WEB_URL"
        exit 1
    fi
    log "AdGuard Home web interface is accessible"
}

test_dns_resolution() {
    log "Testing DNS resolution..."
    retry "nslookup_output=\$(nslookup example.com $ADGUARD_HOST); echo \"\$nslookup_output\" | grep -q 'Address'" 3 2
    if [ $? -ne 0 ]; then
        log_error "AdGuard Home DNS resolution test failed"
        exit 1
    fi
    log "DNS resolution test passed"
}

main() {
    log "Running AdGuard Home server test..."
    check_ports
    check_process
    test_web_interface
    test_dns_resolution
    log "AdGuard Home server test completed successfully"
}

main "$@"
