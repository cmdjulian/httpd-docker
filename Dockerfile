# syntax = docker/dockerfile:1.4.1

FROM --platform=$BUILDPLATFORM alpine:3.16 AS httpd

ARG BUSYBOX_VERSION="1.35.0"

WORKDIR /busybox
ADD https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2 busybox.tar.bz2
RUN tar --strip-components=1 -xjf busybox.tar.bz2

# start multi arch build here
ARG TARGETOS TARGETARCH
RUN <<EOF
set -e

apk add gcc musl-dev make perl
make allnoconfig

echo -n \
"CONFIG_STATIC=y
CONFIG_HTTPD=y
CONFIG_FEATURE_HTTPD_PORT_DEFAULT=80
CONFIG_FEATURE_HTTPD_RANGES=y
CONFIG_FEATURE_HTTPD_SETUID=y
CONFIG_FEATURE_HTTPD_BASIC_AUTH=y
CONFIG_FEATURE_HTTPD_AUTH_MD5=y
CONFIG_FEATURE_HTTPD_CGI=y
CONFIG_FEATURE_HTTPD_CONFIG_WITH_SCRIPT_INTERPR=y
CONFIG_FEATURE_HTTPD_SET_REMOTE_PORT_TO_ENV=y
CONFIG_FEATURE_HTTPD_ENCODE_URL_STR=y
CONFIG_FEATURE_HTTPD_ERROR_PAGES=y
CONFIG_FEATURE_HTTPD_PROXY=y
CONFIG_FEATURE_HTTPD_GZIP=y
CONFIG_FEATURE_HTTPD_ETAG=y
CONFIG_FEATURE_HTTPD_LAST_MODIFIED=y
CONFIG_FEATURE_HTTPD_DATE=y
CONFIG_FEATURE_HTTPD_ACL_IP=y
CONFIG_FEATURE_SYSLOG_INFO=y
CONFIG_FEATURE_SYSLOG=y
CONFIG_LOGIN=y
CONFIG_FEATURE_NOLOGIN=y" | cat - .config | tee .config

make -s
make install
EOF


FROM alpine:3.16 AS tini

ARG TARGETARCH
ARG TINI_VERSION="v0.19.0"
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-${TARGETARCH} /bin/tini
RUN chmod +x /bin/tini


FROM debian:11-slim as builder

COPY --from=tini /bin/tini /bin/tini
COPY --from=httpd /busybox/_install/bin/busybox /bin/busybox

RUN <<EOF
apt update
apt install upx-ucl -y
touch /home/config.conf
upx /bin/busybox
ln -s /bin/busybox /sbin/nologin
ln -s /bin/busybox /bin/httpd
EOF

COPY <<EOF /etc/group
root:x:0:root
www-data:x:10001:httpd
EOF

COPY <<EOF /etc/passwd
root:x:0:0:root:/root:/sbin/nologin
httpd:x:10001:10001::/opt/httpd:/sbin/nologin
EOF


FROM scratch as squash

COPY --from=builder /tmp /tmp
COPY --from=builder /opt /opt
COPY --from=builder /home/config.conf /etc/httpd/config.conf
COPY --from=builder /etc/group /etc/passwd /etc/
COPY --from=builder /bin/busybox /bin/httpd /bin/tini /bin/
COPY --from=builder /sbin/ /sbin/


FROM scratch

ARG BUILDTIME REVISION VERSION
LABEL org.opencontainers.image.authors="cmdjulian" \
      org.opencontainers.image.base.name="scratch" \
      org.opencontainers.image.created=${BUILDTIME} \
      org.opencontainers.image.description="busybox httpd server" \
      org.opencontainers.image.documentation="https://github.com/cmdjulian/minimal-httpd-docker/blob/main/README.md" \
      org.opencontainers.image.ref.name="main" \
      org.opencontainers.image.revision=${REVISION} \
      org.opencontainers.image.source="https://github.com/cmdjulian/minimal-httpd-docker/tree/main" \
      org.opencontainers.image.title="httpd" \
      org.opencontainers.image.url="https://github.com/cmdjulian/minimal-httpd-docker/tree/main" \
      org.opencontainers.image.vendor="cmdjulian" \
      org.opencontainers.image.version=${VERSION}

ENV PATH=/bin
USER 10001:10001
COPY --from=squash / /
WORKDIR /opt/httpd

ENTRYPOINT ["/bin/tini", "--", "/bin/httpd"]
CMD ["-f", "-v", "-p", "8080", "-c", "/etc/httpd/config.conf"]