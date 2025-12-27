#!/bin/sh

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

log "===== AdGuard Home Architecture Validation Test ====="

# Get container architecture
CONTAINER_ARCH=$(uname -m)
log "Container architecture: $CONTAINER_ARCH"

# Verify AdGuard Home binary exists
if [ ! -f "/opt/AdGuardHome/AdGuardHome" ]; then
    log_error "AdGuard Home binary not found at /opt/AdGuardHome/AdGuardHome"
    exit 1
fi
log "✓ AdGuard Home binary exists"

# Check binary architecture using file command
if command -v file >/dev/null 2>&1; then
    BINARY_INFO=$(file /opt/AdGuardHome/AdGuardHome)
    log "Binary info: $BINARY_INFO"

    # Validate binary architecture matches container
    case "$CONTAINER_ARCH" in
        x86_64)
            if echo "$BINARY_INFO" | grep -q "x86-64\|x86_64"; then
                log "✓ Binary architecture matches container (x86_64)"
            else
                log_error "Binary architecture mismatch: expected x86-64, got: $BINARY_INFO"
                exit 1
            fi
            ;;
        aarch64)
            if echo "$BINARY_INFO" | grep -q "aarch64\|ARM aarch64"; then
                log "✓ Binary architecture matches container (aarch64)"
            else
                log_error "Binary architecture mismatch: expected aarch64, got: $BINARY_INFO"
                exit 1
            fi
            ;;
        armv7l)
            if echo "$BINARY_INFO" | grep -q "ARM"; then
                log "✓ Binary architecture matches container (armv7l)"
            else
                log_error "Binary architecture mismatch: expected ARM, got: $BINARY_INFO"
                exit 1
            fi
            ;;
        *)
            log "Warning: Unknown architecture $CONTAINER_ARCH, skipping architecture match validation"
            ;;
    esac
else
    log "Warning: 'file' command not available, skipping detailed binary architecture check"
fi

# Test binary execution - check if it can run and display version
log "Testing binary execution..."
if /opt/AdGuardHome/AdGuardHome --version >/dev/null 2>&1; then
    VERSION=$(/opt/AdGuardHome/AdGuardHome --version 2>&1 | head -n1)
    log "✓ AdGuard Home binary is executable"
    log "  Version: $VERSION"
else
    log_error "AdGuard Home binary failed to execute (possible architecture mismatch)"
    exit 1
fi

# Verify binary has correct permissions
BINARY_PERMS=$(stat -c '%a' /opt/AdGuardHome/AdGuardHome 2>/dev/null || stat -f '%A' /opt/AdGuardHome/AdGuardHome 2>/dev/null)
if [ -x "/opt/AdGuardHome/AdGuardHome" ]; then
    log "✓ Binary has execute permissions ($BINARY_PERMS)"
else
    log_error "Binary does not have execute permissions"
    exit 1
fi

log "===== Architecture Validation: PASSED ====="
exit 0
