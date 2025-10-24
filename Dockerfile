# Stage 1: builder
FROM alpine:3.22.2 AS builder

ARG UNBOUND_VERSION="1.23.1"
ARG ADGUARD_VERSION="v0.107.68"
ARG VALKEY_VERSION="8.1.3"

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
        git \
        coreutils

RUN wget https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz && \
    wget https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz.sha256 && \
    echo "$(cat unbound-${UNBOUND_VERSION}.tar.gz.sha256)  unbound-${UNBOUND_VERSION}.tar.gz" > unbound-checksum && \
    sha256sum -c unbound-checksum && \
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
    rm -rf unbound-latest* unbound-checksum unbound-${UNBOUND_VERSION}.tar.gz* /var/cache/apk/*

RUN git clone --branch ${VALKEY_VERSION} --depth 1 https://github.com/valkey-io/valkey.git /tmp/valkey && \
    cd /tmp/valkey && \
    make BUILD_TLS=yes && \
    make install && \
    rm -rf /tmp/valkey

RUN wget -O /tmp/AdGuardHome.tar.gz "https://github.com/AdguardTeam/AdGuardHome/releases/download/${ADGUARD_VERSION}/AdGuardHome_linux_amd64.tar.gz" && \
    tar -xzf /tmp/AdGuardHome.tar.gz -C /opt && \
    rm /tmp/AdGuardHome.tar.gz

# Stage 2: final
FROM alpine:latest

ENV ADGUARD_PATH="/opt/AdGuardHome"
ENV ENTRYPOINT_PATH="/usr/local/bin/entrypoint.sh"
ENV CONFIG_DEFAULT_PATH="/config_default"
ENV PATH="${ADGUARD_PATH}:${PATH}"

RUN apk update && \
    apk add --no-cache \
        busybox-suid \
        curl \
        unbound \
        bind-tools \
        shadow && \
    mkdir -p /var/lib/valkey

COPY config/ ${CONFIG_DEFAULT_PATH}
COPY entrypoint.sh ${ENTRYPOINT_PATH}
RUN chmod +x ${ENTRYPOINT_PATH}

COPY --from=builder /usr/local/sbin/unbound /usr/local/sbin/unbound
COPY --from=builder ${ADGUARD_PATH} ${ADGUARD_PATH}
COPY --from=builder /usr/local/bin/valkey-server /usr/local/bin/valkey-server
COPY --from=builder /usr/local/bin/valkey-cli /usr/local/bin/valkey-cli
COPY --from=builder /usr/local/bin/valkey-benchmark /usr/local/bin/valkey-benchmark
COPY --from=builder /usr/local/bin/valkey-check-rdb /usr/local/bin/valkey-check-rdb
COPY --from=builder /usr/local/bin/valkey-sentinel /usr/local/bin/valkey-sentinel

RUN chmod +x ${ADGUARD_PATH}/AdGuardHome && \
    chown -R root:root ${ADGUARD_PATH}

EXPOSE 53/tcp 53/udp 853/tcp 3000/tcp 443/tcp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
