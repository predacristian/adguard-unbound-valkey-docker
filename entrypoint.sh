#!/bin/sh

/usr/local/bin/init-config.sh
if [ $? -ne 0 ]; then
    echo "Failed to initialize configuration"
    exit 1
fi

redis-server /config/redis/redis.conf --daemonize yes
if [ $? -ne 0 ]; then
    echo "Failed to start Redis server"
    exit 1
fi

unbound -d &
if [ $? -ne 0 ]; then
    echo "Failed to start Unbound DNS server"
    exit 1
fi

# Wait for unbound to be ready
sleep 2

cd /opt/AdGuardHome
./AdGuardHome \
    --no-check-update \
    --work-dir /opt/adguardhome/work \
    --config /config/AdGuardHome/AdGuardHome.yaml \
    --host 0.0.0.0 \
    --port 3000 \
    --pidfile /opt/adguardhome/adguard.pid &

# Wait for AdGuard to start
sleep 2

# Keep container running
tail -f /dev/null & wait
