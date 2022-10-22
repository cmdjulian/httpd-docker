# syntax = docker/dockerfile:1.4.1

FROM --platform=$BUILDPLATFORM alpine:3.16 AS httpd

ARG BUSYBOX_VERSION="1.35.0"

WORKDIR /busybox
ADD https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2 busybox.tar.bz2
RUN tar --strip-components=1 -xjf busybox.tar.bz2

# start multi arch build here
ARG TARGETOS TARGETARCH
RUN apk add gcc musl-dev make perl
RUN make allnoconfig
RUN echo "\
CONFIG_STATIC=y\n\
CONFIG_HTTPD=y\n\
CONFIG_FEATURE_HTTPD_PORT_DEFAULT=80\n\
CONFIG_FEATURE_HTTPD_RANGES=y\n\
CONFIG_FEATURE_HTTPD_SETUID=y\n\
CONFIG_FEATURE_HTTPD_BASIC_AUTH=y\n\
CONFIG_FEATURE_HTTPD_AUTH_MD5=y\n\
CONFIG_FEATURE_HTTPD_CGI=y\n\
CONFIG_FEATURE_HTTPD_CONFIG_WITH_SCRIPT_INTERPR=y\n\
CONFIG_FEATURE_HTTPD_SET_REMOTE_PORT_TO_ENV=y\n\
CONFIG_FEATURE_HTTPD_ENCODE_URL_STR=y\n\
CONFIG_FEATURE_HTTPD_ERROR_PAGES=y\n\
CONFIG_FEATURE_HTTPD_PROXY=y\n\
CONFIG_FEATURE_HTTPD_GZIP=y\n\
CONFIG_FEATURE_HTTPD_ETAG=y\n\
CONFIG_FEATURE_HTTPD_LAST_MODIFIED=y\n\
CONFIG_FEATURE_HTTPD_DATE=y\n\
CONFIG_FEATURE_HTTPD_ACL_IP=y\n\
CONFIG_FEATURE_SYSLOG_INFO=y\n\
CONFIG_FEATURE_SYSLOG=y\n\
CONFIG_LOGIN=y\n\
CONFIG_FEATURE_NOLOGIN=y" | cat - .config | tee .config

RUN make -s && make install


FROM alpine:3.16 AS tini

ARG TARGETARCH
ARG TINI_VERSION="v0.19.0"
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-${TARGETARCH} /bin/tini
RUN chmod +x /bin/tini


FROM --platform=linux/amd64 alpine:3.16 as builder

COPY <<EOF /etc/group
root:x:0:root
www-data:x:10001:httpd
EOF
COPY <<EOF /etc/passwd
root:x:0:0:root:/root:/sbin/nologin
httpd:x:10001:10001::/opt/httpd:/sbin/nologin
EOF
COPY --from=tini /bin/tini /bin/tini
COPY --from=httpd /busybox/_install/bin/busybox /bin/busybox

RUN apk add coreutils upx
RUN ln -sf /bin/busybox /sbin/nologin
RUN ln -sf /bin/busybox /bin/httpd
RUN upx /bin/busybox


FROM scratch as squash

# empty config file
COPY <<EOF /etc/httpd/config.conf
EOF

COPY --from=builder /tmp /tmp
COPY --from=builder /opt /opt
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