#!/bin/sh

set -e

# Initialize configuration
/usr/local/bin/init-config.sh

# Start Redis server
redis-server /config/redis/redis.conf --daemonize yes

# Start Unbound DNS server
unbound -c /usr/local/etc/unbound/unbound.conf -d &

# Wait for Unbound to be ready
sleep 2

# Start AdGuard Home
cd /opt/AdGuardHome
./AdGuardHome \
    --no-check-update \
    --work-dir /opt/adguardhome/work \
    --config /config/AdGuardHome/AdGuardHome.yaml \
    --host 0.0.0.0 \
    --port 3000 \
    --pidfile /opt/adguardhome/adguard.pid &

# Wait for AdGuard Home to start
sleep 2

# Keep container running
tail -f /dev/null & wait
