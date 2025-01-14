#!/bin/sh

# Initialize configuration
/usr/local/bin/init-config.sh
if [ $? -ne 0 ]; then
    echo "Failed to initialize configuration"
    exit 1
fi

# Start Redis server
redis-server /config/redis/redis.conf --daemonize yes
if [ $? -ne 0 ]; then
    echo "Failed to start Redis server"
    exit 1
fi

# Start Unbound DNS server
unbound -d -c /config/unbound/unbound.conf &
if [ $? -ne 0 ]; then
    echo "Failed to start Unbound DNS server"
    exit 1
fi

# Start AdGuard Home
cd /opt/AdGuardHome
./AdGuardHome --no-check-update -c /config/AdGuardHome/AdGuardHome.yaml -w /opt/adguardhome/work -h 0.0.0.0
if [ $? -ne 0 ]; then
    echo "Failed to start AdGuard Home"
    exit 1
fi
