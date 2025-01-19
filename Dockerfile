# Stage 1: builder
FROM alpine:latest AS builder

ARG UNBOUND_VERSION="1.22.0"
ARG ADGUARD_VERSION="v0.107.55"

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
    && rm -rf /var/cache/apk/*

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

RUN wget -O /tmp/AdGuardHome.tar.gz "https://github.com/AdguardTeam/AdGuardHome/releases/download/${ADGUARD_VERSION}/AdGuardHome_linux_amd64.tar.gz" && \
    tar -xzf /tmp/AdGuardHome.tar.gz -C /opt && \
    rm /tmp/AdGuardHome.tar.gz

# Stage 2: final
FROM alpine:latest

RUN apk update && \
    apk add --no-cache \
        busybox-suid \
        curl \
        redis \
        unbound \
        bind-tools \
        hiredis \
    && rm -rf /var/cache/apk/*

# Create all necessary directories with proper permissions
RUN mkdir -p /usr/local/etc/unbound && \
    mkdir -p /opt/adguardhome/work && \
    mkdir -p /config && \
    mkdir -p /run/unbound && \
    chown -R unbound:unbound /usr/local/etc/unbound /run/unbound && \
    chmod 755 /opt/adguardhome/work

COPY config/ /config_default
COPY init-config.sh /usr/local/bin/init-config.sh
RUN chmod +x /usr/local/bin/init-config.sh

ENV PATH="/opt/AdGuardHome:${PATH}"

COPY --from=builder /usr/local/sbin/unbound /usr/local/sbin/unbound
COPY --from=builder /usr/lib/libhiredis.so.1.1.0 /usr/lib/libhiredis.so.1.1.0
COPY --from=builder /opt/AdGuardHome /opt/AdGuardHome
RUN chmod +x /opt/AdGuardHome/AdGuardHome && \
    chown -R root:root /opt/AdGuardHome

# Run initialization to ensure configs are in place
RUN /usr/local/bin/init-config.sh && \
    ln -s /config/unbound/unbound.conf /usr/local/etc/unbound/unbound.conf

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

EXPOSE 53/tcp 53/udp 853/tcp 3000/tcp 443/tcp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
