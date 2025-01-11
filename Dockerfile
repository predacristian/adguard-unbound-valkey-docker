# Base image
FROM alpine:latest

# System updates and base dependencies
RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
        busybox-suid \
        curl \
        redis \
        unbound \
        build-base \
        openssl-dev \
        libexpat \
        expat-dev \
        hiredis-dev \
        libcap-dev \
        libevent-dev \
        perl

# Install and configure Unbound DNS
RUN wget https://nlnetlabs.nl/downloads/unbound/unbound-latest.tar.gz && \
    mkdir unbound-latest && \
    tar -xzf unbound-latest.tar.gz --strip-components=1 -C unbound-latest && \
    (cd unbound-latest && \
        ./configure \
            --with-libhiredis \
            --with-libexpat=/usr \
            --with-libevent \
            --enable-cachedb \
            --disable-flto \
            --disable-shared \
            --disable-rpath \
            --with-pthreads && \
        make && \
        make install) && \
    rm -rf unbound-latest*

# Install latest AdGuard Home
RUN LATEST_VERSION="$(curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest | grep '\"tag_name\"' | sed -E 's/.*\"([^"]+)\".*/\1/')" && \
    wget -O /tmp/AdGuardHome.tar.gz "https://github.com/AdguardTeam/AdGuardHome/releases/download/${LATEST_VERSION}/AdGuardHome_linux_amd64.tar.gz" && \
    tar -xzf /tmp/AdGuardHome.tar.gz -C /opt && \
    rm /tmp/AdGuardHome.tar.gz

# Setup AdGuard Home directories
RUN mkdir -p /opt/adguardhome/work /config_default && \
    chmod 755 /config_default

# Copy configuration files
COPY config/ /config_default
COPY init-config.sh /usr/local/bin/init-config.sh

# Set permissions
RUN chmod +x /usr/local/bin/init-config.sh

# Create directory for config
RUN mkdir -p /config

# Expose ports
EXPOSE 53/tcp
EXPOSE 53/udp
EXPOSE 853/tcp
EXPOSE 3000/tcp
EXPOSE 443/tcp

# Set environment variables
ENV PATH="/opt/AdGuardHome:${PATH}"

# Copy and set entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
