# syntax = docker/dockerfile:1.5.2
# tag needed for riscv64 support
FROM alpine:edge AS build-tools

RUN apk add --no-cache gcc musl-dev make perl git cmake
WORKDIR /app


FROM build-tools AS httpd

ARG BUSYBOX_VERSION=1_36_0

# https://subscription.packtpub.com/book/hardware-and-creative/9781783289851/1/ch01lvl1sec08/configuring-busybox-simple
RUN git clone --depth 1 https://github.com/mirror/busybox.git .
RUN git fetch origin tag $BUSYBOX_VERSION --no-tags
RUN git -c advice.detachedHead=false -c gc.auto=0 checkout tags/$BUSYBOX_VERSION
COPY --link ./config .config
RUN make -s -j4 && make install


FROM build-tools AS tini

ENV CFLAGS="-DPR_SET_CHILD_SUBREAPER=36 -DPR_GET_CHILD_SUBREAPER=37"

RUN git clone --depth 1 -c gc.auto=0 https://github.com/krallin/tini.git .
RUN cmake .
RUN make -s
RUN make install


FROM scratch AS squash

COPY --link --from=build-tools /tmp /tmp
COPY --link --from=build-tools /opt /opt
COPY --link <<EOF /etc/group
root:x:0:root
www-data:x:10001:httpd
EOF
COPY --link <<EOF /etc/passwd
root:x:0:0:root:/root:/sbin/nologin
httpd:x:10001:10001::/opt/httpd:/sbin/nologin
EOF
COPY --link <<EOF /etc/httpd/httpd.conf

EOF

COPY --link --from=tini /usr/local/bin/tini-static /bin/tini
COPY --link --from=httpd /app/_install/bin/busybox /bin/httpd


FROM scratch

ENV PATH=/bin
USER 10001:10001
COPY --link --from=squash / /
WORKDIR /opt/httpd

ENTRYPOINT ["/bin/tini", "--", "/bin/httpd"]
CMD ["-f", "-v", "-p", "8080", "-c", "/etc/httpd/httpd.conf"]