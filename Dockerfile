# syntax = docker/dockerfile:1.4.3

FROM --platform=$BUILDPLATFORM tunococ/alpine_cmake:3.16.0_3.23.1-r0 AS httpd

WORKDIR /busybox
RUN git clone --depth 1 https://github.com/mirror/busybox.git . && \
    git -c advice.detachedHead=false checkout 707a7ef
COPY config .config

# start multi arch build here
ARG TARGETOS TARGETARCH
RUN make -s
RUN make install


FROM tunococ/alpine_cmake:3.16.0_3.23.1-r0 AS tini

ENV CFLAGS="-DPR_SET_CHILD_SUBREAPER=36 -DPR_GET_CHILD_SUBREAPER=37"

WORKDIR /tini
RUN git clone https://github.com/krallin/tini.git .
RUN cmake .
RUN make -s
RUN make install


# upx is only available for amd64, but it can also take care of binaries for different architectures
FROM --platform=linux/amd64 tunococ/alpine_cmake:3.16.0_3.23.1-r0 as builder

COPY <<EOF /etc/group
root:x:0:root
www-data:x:10001:httpd
EOF

COPY <<EOF /etc/passwd
root:x:0:0:root:/root:/sbin/nologin
httpd:x:10001:10001::/opt/httpd:/sbin/nologin
EOF

COPY --from=tini /usr/local/bin/tini-static /bin/tini
COPY --from=httpd /busybox/_install/bin/busybox /bin/httpd

RUN apk add upx
RUN upx /bin/httpd /bin/tini


FROM scratch as squash

COPY ./httpd.conf /etc/httpd/httpd.conf
COPY --from=builder /tmp /tmp
COPY --from=builder /opt /opt
COPY --from=builder /etc/group /etc/passwd /etc/
COPY --from=builder /bin/httpd /bin/tini /bin/


FROM scratch

ENV PATH=/bin
USER 10001:10001
COPY --from=squash / /
WORKDIR /opt/httpd

ENTRYPOINT ["/bin/tini", "--", "/bin/httpd"]
CMD ["-f", "-v", "-p", "8080", "-c", "/etc/httpd/httpd.conf"]