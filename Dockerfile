FROM alpine:3.20.3 AS builder

ARG VERSION=v4.3.0
ARG CONFIGUREARGS="--enable-extras=m_sslrehashsignal.cpp"
ARG EXTRASMODULES=
ARG BUILD_DEPENDENCIES=

# Stage 0: Build from source
RUN apk add --no-cache gcc g++ make git pkgconfig perl \
       perl-net-ssleay perl-crypt-ssleay perl-lwp-protocol-https \
       perl-libwww wget gnutls-dev sqlite-dev pcre-dev pcre2-dev argon2-dev re2-dev libmaxminddb-dev $BUILD_DEPENDENCIES

RUN addgroup -g 10000 -S inspircd
RUN adduser -u 10000 -h /inspircd/ -D -S -G inspircd inspircd

RUN git clone https://github.com/inspircd/inspircd.git inspircd-src

WORKDIR /inspircd-src
RUN git checkout $(git describe --abbrev=0 --tags $VERSION)

## Add modules
RUN echo $EXTRASMODULES | xargs --no-run-if-empty ./modulemanager install

RUN ./configure --prefix /inspircd --uid 10000 --gid 10000
RUN echo $CONFIGUREARGS | xargs --no-run-if-empty ./configure
RUN make -j`getconf _NPROCESSORS_ONLN` install

# Stage 1: Create optimized runtime container
FROM alpine:3.20.3

ARG RUN_DEPENDENCIES=

RUN apk add --no-cache libgcc libstdc++ gnutls gnutls-utils sqlite-libs pcre pcre2 argon2-libs re2 libmaxminddb curl $RUN_DEPENDENCIES && \
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
