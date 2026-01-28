FROM alpine:3.23@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659 AS base

FROM base AS builder

# renovate: datasource=github-tags depName=inspircd/inspircd
ARG INSPIRCD_VERSION=v4.9.0
ARG CONFIGUREARGS="--enable-extras=m_sslrehashsignal.cpp"
ARG EXTRASMODULES="cve_2024_39844 protoctl"
ARG BUILD_DEPENDENCIES=

# Stage 0: Build from source
RUN apk add --no-cache gcc g++ make pkgconfig perl \
       perl-net-ssleay perl-crypt-ssleay perl-lwp-protocol-https \
       perl-libwww wget gnutls-dev openssl-dev sqlite-dev pcre2-dev argon2-dev re2-dev libmaxminddb-dev $BUILD_DEPENDENCIES

RUN addgroup -g 10000 -S inspircd
RUN adduser -u 10000 -h /inspircd/ -D -S -G inspircd inspircd

ADD https://github.com/inspircd/inspircd.git#${INSPIRCD_VERSION} /inspircd-src

WORKDIR /inspircd-src

## Add modules
RUN echo $EXTRASMODULES | xargs --no-run-if-empty ./modulemanager install

RUN ./configure --prefix /inspircd --uid 10000 --gid 10000
RUN echo $CONFIGUREARGS | xargs --no-run-if-empty ./configure
RUN make -j`getconf _NPROCESSORS_ONLN` install

# Stage 1: Create optimized runtime container
FROM base

ARG RUN_DEPENDENCIES=

RUN apk add --no-cache libgcc libstdc++ gnutls gnutls-utils openssl libssl3 sqlite-libs pcre2 argon2-libs re2 libmaxminddb curl $RUN_DEPENDENCIES && \
    addgroup -g 10000 -S inspircd && \
    adduser -u 10000 -h /inspircd/ -D -S -G inspircd inspircd

COPY --from=builder --chown=inspircd:inspircd /inspircd/ /inspircd/

USER inspircd

WORKDIR /inspircd/

ENV INSPIRCD_ROOT=/inspircd/

CMD ["/inspircd/bin/inspircd", "--nofork"]

HEALTHCHECK \
        --interval=60s \
        --timeout=3s \
        --start-period=60s \
        --retries=3 \
    CMD \
        /usr/bin/nc -z localhost 6667
