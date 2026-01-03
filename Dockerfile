# Pin Alpine for reproducible builds; Renovate will manage ALPINE_VERSION updates via .github/renovate.json
ARG ALPINE_VERSION="3.23.2"

# Stage 1: builder
FROM alpine:${ALPINE_VERSION} AS builder

# Docker automatically provides TARGETARCH (amd64, arm64, arm/v7, etc.)
ARG TARGETARCH

ARG UNBOUND_VERSION="1.23.1"
ARG ADGUARD_VERSION="v0.107.71"
ARG VALKEY_VERSION="9.0.1"

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

# Valkey build and versioning notes:
# - Renovate updates ARG VALKEY_VERSION via .github/renovate.json (tracks valkey-io/valkey GitHub releases).
# - The Docker build clones the repository at the specified tag: `git clone --branch ${VALKEY_VERSION} --depth 1`.
#   This checks out the release tag (e.g. "9.0.0") and is compatible with Renovate's ARG updates.
# - For stronger reproducibility you can:
#     * Pin to a specific commit SHA in addition to the tag, or
#     * Download release tarballs (from GitHub releases) and verify checksums before building.
# - To record/verify the exact commit being built, we capture the checked-out commit hash.
RUN git clone --branch ${VALKEY_VERSION} --depth 1 https://github.com/valkey-io/valkey.git /tmp/valkey && \
    cd /tmp/valkey && \
    git rev-parse --short HEAD > /tmp/valkey-commit && \
    make BUILD_TLS=yes && \
    make install && \
    rm -rf /tmp/valkey

# Download AdGuard Home and verify SHA256 checksum from the same GitHub release.
# Map Docker's TARGETARCH to AdGuard's architecture naming convention.
RUN case "${TARGETARCH}" in \
        amd64) ADGUARD_ARCH="amd64" ;; \
        arm64) ADGUARD_ARCH="arm64" ;; \
        arm/v7) ADGUARD_ARCH="armv7" ;; \
        arm) ADGUARD_ARCH="armv7" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    wget -O /tmp/AdGuardHome.tar.gz "https://github.com/AdguardTeam/AdGuardHome/releases/download/${ADGUARD_VERSION}/AdGuardHome_linux_${ADGUARD_ARCH}.tar.gz" && \
    wget -O /tmp/adguard-checksums.txt "https://github.com/AdguardTeam/AdGuardHome/releases/download/${ADGUARD_VERSION}/checksums.txt" && \
    # Extract the checksum for the target architecture tarball and verify the downloaded file
    grep "AdGuardHome_linux_${ADGUARD_ARCH}.tar.gz" /tmp/adguard-checksums.txt | awk '{print $1 "  /tmp/AdGuardHome.tar.gz"}' > /tmp/adguard-checksum && \
    sha256sum -c /tmp/adguard-checksum && \
    tar -xzf /tmp/AdGuardHome.tar.gz -C /opt && \
    rm -f /tmp/AdGuardHome.tar.gz /tmp/adguard-checksums.txt /tmp/adguard-checksum

# Stage 2: final
FROM alpine:${ALPINE_VERSION}

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
        shadow \
        bats \
        bash \
        apache2-utils \
        openssl && \
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

# Healthcheck: verify Unbound, Valkey, and AdGuard are responding.
# - Unbound: dig against local resolver on port 5335
# - Valkey: ping via unix socket
# - AdGuard Home: HTTP check against management UI (port 3000)
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 CMD sh -c '\
    dig +short @127.0.0.1 -p 5335 example.com | grep -q . && \
    /usr/local/bin/valkey-cli -s /tmp/valkey.sock ping >/dev/null 2>&1 && \
    curl -fsS http://127.0.0.1:3000/ >/dev/null 2>&1 || exit 1'

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
