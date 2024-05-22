# syntax = docker/dockerfile:1.5.2
# tag needed for riscv64 support
FROM --platform=$BUILDPLATFORM alpine:3.20 AS httpd_git

RUN apk add --no-cache git
WORKDIR /app

ARG BUSYBOX_VERSION=1_36_0

# https://subscription.packtpub.com/book/hardware-and-creative/9781783289851/1/ch01lvl1sec08/configuring-busybox-simple
RUN git clone --depth 1 https://github.com/mirror/busybox.git .
RUN git fetch origin tag "$BUSYBOX_VERSION" --no-tags
RUN git -c advice.detachedHead=false -c gc.auto=0 checkout "tags/$BUSYBOX_VERSION"


FROM alpine:3.20 AS httpd

RUN apk add --no-cache gcc make musl-dev
COPY --link --from=httpd_git /app /app
COPY --link ./config /app/.config
WORKDIR /app
RUN make -s -j4 && make install


FROM --platform=$BUILDPLATFORM alpine:3.20 AS tini

RUN apk add --no-cache curl
ARG TINI_VERSION="v0.19.0"
ARG TARGETPLATFORM
RUN <<EOF
set -eu
case "$TARGETPLATFORM" in
  "linux/amd64")   TINI_ARCH='amd64'
  ;;
  "linux/arm/v6")  TINI_ARCH='armel'
  ;;
  "linux/arm/v7")  TINI_ARCH='armhf'
  ;;
  "linux/arm64")   TINI_ARCH='arm64'
  ;;
  "linux/386")     TINI_ARCH='i386'
  ;;
  "linux/ppc64le") TINI_ARCH='ppc64le'
  ;;
  "linux/s390x")   TINI_ARCH='s390x'
  ;;
  *) echo "Unsupported architecture: $TARGETPLATFORM"; exit 1
  ;;
esac
echo "downloading tiny $TINI_VERSION for arch $TINI_ARCH"
curl -fsSLo /tini "https://github.com/krallin/tini/releases/download/$TINI_VERSION/tini-static-$TINI_ARCH"
EOF


FROM scratch AS squash

COPY --link --from=httpd_git /tmp /tmp
COPY --link --from=httpd_git /opt /opt
COPY --link --chown=0:0 --chmod=644 <<EOF /etc/group
root:x:0:root
www-data:x:65532:httpd
EOF
COPY --link --chown=0:0 --chmod=644 <<EOF /etc/passwd
root:x:0:0:root:/root:/sbin/nologin
httpd:x:65532:65532::/opt/httpd:/sbin/nologin
EOF
COPY --link --chown=0:0 --chmod=644 <<EOF /etc/httpd/httpd.conf

EOF

COPY --link --chown=0:0 --chmod=755 --from=tini /tini /bin/tini
COPY --link --chown=0:0 --chmod=755 --from=httpd /app/_install/bin/busybox /bin/httpd


FROM scratch

ENV PATH=/bin
USER 65532:65532
COPY --link --from=squash / /
WORKDIR /opt/httpd
EXPOSE 8080

ENTRYPOINT ["/bin/tini", "--", "/bin/httpd"]
CMD ["-f", "-v", "-p", "8080", "-c", "/etc/httpd/httpd.conf"]