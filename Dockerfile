# syntax = docker/dockerfile:1.4.3

FROM alpine:3.16@sha256:bc41182d7ef5ffc53a40b044e725193bc10142a1243f395ee852a8d9730fc2ad AS build-tools

RUN apk add --no-cache gcc musl-dev make perl git cmake
COPY --from=starudream/upx:latest@sha256:6f77c8fe795d114b619cf0ebd98825d5f0804ec0391a3e901102032f32c565b6 /usr/bin/upx /usr/bin/upx
WORKDIR /app


FROM build-tools AS httpd

# https://subscription.packtpub.com/book/hardware-and-creative/9781783289851/1/ch01lvl1sec08/configuring-busybox-simple
RUN git clone --depth 1 https://github.com/mirror/busybox.git .
RUN git -c advice.detachedHead=false checkout 707a7ef
COPY --link config .config
RUN make -s -j4 && make install


FROM build-tools AS tini

ENV CFLAGS="-DPR_SET_CHILD_SUBREAPER=36 -DPR_GET_CHILD_SUBREAPER=37"
RUN git clone --depth 1 https://github.com/krallin/tini.git .
RUN cmake .
RUN make -s -j4
RUN make install


FROM build-tools AS builder

COPY --link ./group /etc/group
COPY --link ./passwd /etc/passwd
COPY --link --from=tini /usr/local/bin/tini-static /bin/tini
COPY --link --from=httpd /app/_install/bin/busybox /bin/httpd

RUN upx -9 --best --ultra-brute /bin/httpd /bin/tini


FROM scratch AS squash

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