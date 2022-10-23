# syntax = docker/dockerfile:1.4.3

FROM alpine:3.16 AS httpd

WORKDIR /busybox
RUN apk add --no-cache gcc musl-dev make perl git
RUN git clone --depth 1 https://github.com/mirror/busybox.git . && \
    git -c advice.detachedHead=false checkout 707a7ef

# https://subscription.packtpub.com/book/hardware-and-creative/9781783289851/1/ch01lvl1sec08/configuring-busybox-simple
COPY --link config .config

RUN make -s -j4 && make install


FROM tunococ/alpine_cmake:3.16.0_3.23.1-r0 AS tini

ENV CFLAGS="-DPR_SET_CHILD_SUBREAPER=36 -DPR_GET_CHILD_SUBREAPER=37"

WORKDIR /tini
RUN git clone https://github.com/krallin/tini.git .
RUN cmake .
RUN make -s
RUN make install


# upx is only available for amd64, but it can also take care of binaries for different architectures
FROM starudream/upx:latest as builder

COPY --link ./group /etc/group
COPY --link ./passwd /etc/passwd
COPY --link --from=tini /usr/local/bin/tini-static /bin/tini
COPY --link --from=httpd /busybox/_install/bin/busybox /bin/httpd

RUN upx /bin/httpd /bin/tini


FROM scratch as squash

COPY --link ./httpd.conf /etc/httpd/httpd.conf
COPY --link --from=builder /tmp /tmp
COPY --link --from=builder /opt /opt
COPY --link --from=builder /etc/group /etc/passwd /etc/
COPY --link --from=builder /bin/httpd /bin/tini /bin/


FROM scratch

ENV PATH=/bin
USER 10001:10001
COPY --link --from=squash / /
WORKDIR /opt/httpd

ENTRYPOINT ["/bin/tini", "--", "/bin/httpd"]
CMD ["-f", "-v", "-p", "8080", "-c", "/etc/httpd/httpd.conf"]