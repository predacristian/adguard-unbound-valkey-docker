#!/bin/sh

# Create necessary directories if they do not exist
mkdir -p /config/redis /config/unbound /config/AdGuardHome

# Copy default configuration files if the target directory is empty (first run)
if [ -z "$(ls -A /config/redis)" ]; then
    cp -r /config_default/redis/* /config/redis/
fi

if [ -z "$(ls -A /config/unbound)" ]; then
    cp -r /config_default/unbound/* /config/unbound/
fi

if [ -z "$(ls -A /config/AdGuardHome)" ]; then
    cp -r /config_default/AdGuardHome/* /config/AdGuardHome/
fi
