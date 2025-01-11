#!/bin/sh

# Initialize configuration
/usr/local/bin/init-config.sh

# Start Redis server
redis-server /config/redis/redis.conf --daemonize yes

# Start Unbound DNS server
unbound -d -c /config/unbound/unbound.conf &

# Start AdGuard Home
cd /opt/AdGuardHome && ./AdGuardHome --no-check-update -c /config/AdGuardHome/AdGuardHome.yaml -w /opt/adguardhome/work -h 0.0.0.0
