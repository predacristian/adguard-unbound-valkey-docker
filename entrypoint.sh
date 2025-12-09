#!/bin/sh

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

cleanup() {
    log "Shutting down services..."

    if [ -f /opt/adguardhome/adguard.pid ]; then
        kill $(cat /opt/adguardhome/adguard.pid) 2>/dev/null || true
        rm -f /opt/adguardhome/adguard.pid
    fi

    killall unbound 2>/dev/null || true

    valkey-cli -p 6379 shutdown 2>/dev/null || true

    log "Services stopped, exiting."
    exit 0
}

trap cleanup SIGTERM SIGINT SIGQUIT

wait_for_service() {
    local service_name="$1"
    local check_command="$2"
    local max_attempts="${3:-30}"
    local attempt=1

    log "Waiting for $service_name..."

    while [ $attempt -le $max_attempts ]; do
        if eval "$check_command" >/dev/null 2>&1; then
            log "$service_name ready"
            return 0
        fi

        if [ $attempt -eq $max_attempts ]; then
            log_error "$service_name failed to start"
            return 1
        fi

        sleep 1
        attempt=$((attempt + 1))
    done
}

validate_configs() {
    log "Validating configs..."

    if [ ! -L "/usr/local/etc/unbound/unbound.conf" ]; then
        log_error "Unbound config symlink not found"
        return 1
    fi

    if [ ! -f "/usr/local/etc/unbound/unbound.conf" ]; then
        log_error "Unbound config target not found: $(readlink /usr/local/etc/unbound/unbound.conf)"
        return 1
    fi

    if ! unbound-checkconf /usr/local/etc/unbound/unbound.conf; then
        log_error "Unbound config validation failed"
        return 1
    fi

    if [ ! -f "/config/AdGuardHome/AdGuardHome.yaml" ]; then
        log_error "AdGuard config not found"
        return 1
    fi

    if [ ! -f "/config/valkey/valkey.conf" ]; then
        log_error "Valkey config not found"
        return 1
    fi

    if [ ! -r "/config/valkey/valkey.conf" ]; then
        log_error "Valkey config not readable"
        return 1
    fi

    log "Configs validated"
}

init_configuration() {
    log "Initializing configs..."

    mkdir -p /config/valkey /config/unbound /config/AdGuardHome \
             /opt/adguardhome/work /usr/local/etc/unbound /run/unbound

    if ! id unbound >/dev/null 2>&1; then
        addgroup -S unbound
        adduser -S -G unbound unbound
    fi

    chown -R unbound:unbound /usr/local/etc/unbound /run/unbound
    chmod 755 /opt/adguardhome/work

    for service in valkey unbound AdGuardHome; do
        if [ -z "$(ls -A /config/$service 2>/dev/null)" ]; then
            log "Copying default $service config..."
            if [ -d "/config_default/$service" ]; then
                cp -r /config_default/$service/* /config/$service/
                log "Default $service config copied"
            else
                log_error "Default config dir /config_default/$service not found"
                return 1
            fi
        else
            log "Using existing $service config"
        fi
    done

    if [ ! -f "/config/unbound/unbound.conf" ]; then
        log_error "Source Unbound config /config/unbound/unbound.conf not found"
        return 1
    fi

    log "Linking Unbound config..."
    ln -sf /config/unbound/unbound.conf /usr/local/etc/unbound/unbound.conf

    if [ ! -L "/usr/local/etc/unbound/unbound.conf" ]; then
        log_error "Failed to link Unbound config"
        return 1
    fi

    log "Unbound config linked"
    log "Config init done"
}

setup_adguard_credentials() {
    log "Setting up AdGuard Home credentials..."

    local config_file="/config/AdGuardHome/AdGuardHome.yaml"
    local credentials_file="/config/AdGuardHome/.credentials"

    if [ -f "$credentials_file" ]; then
        log "Credentials already configured"
        return 0
    fi

    local username="${ADGUARD_USERNAME:-admin}"
    local password="${ADGUARD_PASSWORD:-}"

    if [ -z "$password" ]; then
        password=$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-16)
        log "Generated random password for AdGuard Home"
    else
        log "Using provided ADGUARD_PASSWORD"
    fi

    local password_hash
    if command -v htpasswd >/dev/null 2>&1; then
        password_hash=$(htpasswd -nbB "$username" "$password" | cut -d: -f2)
    else
        log "WARNING: htpasswd not available, using AdGuard's default hashing"
        password_hash='$2y$10$TJbQGpmgYZQ34WP3WjGoC.6Ibg40RnajD6OpLnV9xlfBCDZaS7L3y'
        password="admin"
        log "WARNING: Using default credentials admin/admin"
        log "SECURITY: Set ADGUARD_PASSWORD environment variable to use custom password"
    fi

    if [ -f "$config_file" ]; then
        sed -i "s/name: .*/name: $username/" "$config_file"
        sed -i "s|password: .*|password: $password_hash|" "$config_file"
    fi

    if [ "$password" != "admin" ]; then
        cat > "$credentials_file" <<EOF
# AdGuard Home Credentials
# Generated: $(date)
Username: $username
Password: $password

⚠️  IMPORTANT: Save these credentials securely!
⚠️  This file will not be shown again on subsequent starts.

Access AdGuard Home at: http://localhost:3000
EOF
        chmod 600 "$credentials_file"

        log "═══════════════════════════════════════════════════════"
        log "AdGuard Home Credentials:"
        log "  Username: $username"
        log "  Password: $password"
        log ""
        log "⚠️  SAVE THESE CREDENTIALS NOW!"
        log "Access: http://localhost:3000"
        log "═══════════════════════════════════════════════════════"
    else
        log "⚠️  WARNING: Using default admin/admin credentials!"
        log "⚠️  Set ADGUARD_PASSWORD environment variable for production use"
    fi
}

start_valkey() {
    log "Starting Valkey..."

    if ! valkey-server /config/valkey/valkey.conf --daemonize yes; then
        log_error "Valkey start failed"
        return 1
    fi

    # Ensure the unix socket is created and adjust ownership/permissions so Unbound can access it
    SOCKET=/tmp/valkey.sock
    socket_wait=0
    socket_timeout=10
    while [ $socket_wait -lt $socket_timeout ]; do
        if [ -e "$SOCKET" ]; then
            log "Valkey socket found: $SOCKET"
            # If 'unbound' group exists, make the socket owned by root:unbound so unbound can access it
            if getent group unbound >/dev/null 2>&1; then
                chown root:unbound "$SOCKET" || true
            fi
            chmod 770 "$SOCKET" || true
            break
        fi
        sleep 1
        socket_wait=$((socket_wait + 1))
    done

    wait_for_service "Valkey" "valkey-cli -p 6379 ping | grep -q PONG"
}

start_unbound() {
    log "Starting Unbound..."

    unbound -c /usr/local/etc/unbound/unbound.conf -d &
    UNBOUND_PID=$!

    wait_for_service "Unbound" "dig @127.0.0.1 -p 5335 +short google.com"
}

start_adguard() {
    log "Starting AdGuard..."

    cd /opt/AdGuardHome
    ./AdGuardHome \
        --no-check-update \
        --work-dir /opt/adguardhome/work \
        --config /config/AdGuardHome/AdGuardHome.yaml \
        --host 0.0.0.0 \
        --port 3000 \
        --pidfile /opt/adguardhome/adguard.pid &

    ADGUARD_PID=$!

    wait_for_service "AdGuard Home" "curl -s http://127.0.0.1:3000 >/dev/null"
}

main() {
    log "Starting DNS Stack..."

    init_configuration || exit 1

    setup_adguard_credentials || exit 1

    validate_configs || exit 1

    start_valkey || exit 1
    start_unbound || exit 1
    start_adguard || exit 1

    log "All services started. DNS Stack ready."
    log "AdGuard Home: http://localhost:3000"

    while true; do
        if ! kill -0 $UNBOUND_PID 2>/dev/null; then
            log_error "Unbound died, restarting..."
            exit 1
        fi

        if ! kill -0 $ADGUARD_PID 2>/dev/null; then
            log_error "AdGuard died, restarting..."
            exit 1
        fi

        if ! valkey-cli -p 6379 ping >/dev/null 2>&1; then
            log_error "Valkey not responding, restarting..."
            exit 1
        fi

        sleep 10
    done
}

main "$@"
