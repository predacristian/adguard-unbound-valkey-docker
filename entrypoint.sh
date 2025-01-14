#!/bin/sh

# Initialize configuration
/usr/local/bin/init-config.sh || {
    echo "Failed to initialize configuration"
    exit 1
}

# Start Redis server
redis-server /config/redis/redis.conf --daemonize yes || {
    echo "Failed to start Redis server"
    exit 1
}

# Start Unbound DNS server
unbound -d -c /config/unbound/unbound.conf & || {
    echo "Failed to start Unbound DNS server"
    exit 1
}

# Start AdGuard Home
cd /opt/AdGuardHome && ./AdGuardHome --no-check-update -c /config/AdGuardHome/AdGuardHome.yaml -w /opt/adguardhome/work -h 0.0.0.0 || {
    echo "Failed to start AdGuard Home"
    exit 1
}
