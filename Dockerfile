FROM alpine:latest

ARG UNBOUND_VERSION="1.22.0"
ARG ADGUARD_VERSION="v0.107.55"

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
    rm -rf unbound-latest*

RUN wget -O /tmp/AdGuardHome.tar.gz "https://github.com/AdguardTeam/AdGuardHome/releases/download/${ADGUARD_VERSION}/AdGuardHome_linux_amd64.tar.gz" && \
    tar -xzf /tmp/AdGuardHome.tar.gz -C /opt && \
    rm /tmp/AdGuardHome.tar.gz

RUN mkdir -p /opt/adguardhome/work /config_default && \
    chmod 755 /config_default

COPY config/ /config_default
COPY init-config.sh /usr/local/bin/init-config.sh

RUN chmod +x /usr/local/bin/init-config.sh

RUN mkdir -p /config

EXPOSE 53/tcp
EXPOSE 53/udp
EXPOSE 853/tcp
EXPOSE 3000/tcp
EXPOSE 443/tcp

ENV PATH="/opt/AdGuardHome:${PATH}"

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
