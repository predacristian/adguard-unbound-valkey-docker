# Stage 1: builder
FROM alpine:latest AS builder

ARG UNBOUND_VERSION="1.23.1"
ARG ADGUARD_VERSION="v0.107.64"
ARG VALKEY_VERSION="8.1.3"

# Install build dependencies
RUN apk update && \
    apk add --no-cache \
        build-base \
        openssl-dev \
        expat-dev \
        hiredis-dev \
        libcap-dev \
        libevent-dev \
        wget \
        perl \
        git

# Build Unbound
RUN wget https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz && \
    mkdir unbound-latest && \
    tar -xzf unbound-${UNBOUND_VERSION}.tar.gz --strip-components=1 -C unbound-latest && \
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
    rm -rf unbound-latest* /var/cache/apk/*

# Build Valkey
RUN git clone --branch ${VALKEY_VERSION} --depth 1 https://github.com/valkey-io/valkey.git /tmp/valkey && \
    cd /tmp/valkey && \
    make BUILD_TLS=yes && \
    make install && \
    rm -rf /tmp/valkey

# Download AdGuard Home
RUN wget -O /tmp/AdGuardHome.tar.gz "https://github.com/AdguardTeam/AdGuardHome/releases/download/${ADGUARD_VERSION}/AdGuardHome_linux_amd64.tar.gz" && \
    tar -xzf /tmp/AdGuardHome.tar.gz -C /opt && \
    rm /tmp/AdGuardHome.tar.gz

# Stage 2: final
FROM alpine:latest

# Install runtime dependencies
RUN apk update && \
    apk add --no-cache \
        busybox-suid \
        curl \
        unbound \
        bind-tools

# Ensure Valkey data directory exists
RUN mkdir -p /var/lib/valkey

# Copy default configurations
COPY config/ /config_default
COPY init-config.sh /usr/local/bin/init-config.sh
RUN chmod +x /usr/local/bin/init-config.sh

# Set environment variables
ENV PATH="/opt/AdGuardHome:${PATH}"

# Copy built binaries and AdGuard Home
COPY --from=builder /usr/local/sbin/unbound /usr/local/sbin/unbound
COPY --from=builder /opt/AdGuardHome /opt/AdGuardHome
RUN chmod +x /opt/AdGuardHome/AdGuardHome && \
    chown -R root:root /opt/AdGuardHome

# Copy Valkey binaries
COPY --from=builder /usr/local/bin/valkey-server /usr/local/bin/valkey-server
COPY --from=builder /usr/local/bin/valkey-cli /usr/local/bin/valkey-cli
COPY --from=builder /usr/local/bin/valkey-benchmark /usr/local/bin/valkey-benchmark
COPY --from=builder /usr/local/bin/valkey-check-rdb /usr/local/bin/valkey-check-rdb
COPY --from=builder /usr/local/bin/valkey-sentinel /usr/local/bin/valkey-sentinel

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

# Expose necessary ports
EXPOSE 53/tcp 53/udp 853/tcp 3000/tcp 443/tcp

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
