[![Docker Pulls](https://badgen.net/docker/pulls/cmdjulian/httpd?icon=docker&label=pulls)](https://hub.docker.com/r/cmdjulian/httpd/)
[![Docker Stars](https://badgen.net/docker/stars/cmdjulian/httpd?icon=docker&label=stars)](https://hub.docker.com/r/cmdjulian/httpd/)
[![Docker Image Size](https://badgen.net/docker/size/cmdjulian/httpd?icon=docker&label=image%20size)](https://hub.docker.com/r/cmdjulian/httpd/)

# minimal multi arch `httpd` docker image

![](logo.png)

Minimal `httpd` shell-less multi-arch docker image based on scratch.

The image is based on scratch and contains a static striped busybox binary just including `httpd` applet.
The image is published on docker hub under `cmdjulian/httpd:{version}`. It supports `arm/v6`, `arm/v7`, `arm64`, `i386`, `amd64`, `ppc64le` and `s390x`
architectures.

Per default, it runs as a non-root user `httpd(id=65532)`. Alternatively, you can also switch to `root(id=0)`.

The http process is started by [tini](https://github.com/krallin/tini), a small init wrapper. It takes responsibility in
forwarding the correct termination signals to the underlying `httpd` process.

The container does not contain a shell.

## Usage

Per default the config file for `httpd` is empty. It's located under `/etc/httpd/httpd.conf`.  
Per default the server listens on port `8080`.  
The served root folder is `/opt/httpd`.  
Commandline arguments can be easily overridden via cli: `docker run --rm -p 3000:3000 docu:latest -v -p 3000`.  
Here we keep verbose output and change the port to 3000. We don't need the config file, so we don't provide the cli
option either.

### Example

The following Dockerfile is an example for an angular app.  
The first copy instruction moves the compiled angular ap into the content root.  
The second one copies a custom config file to redirects every sub-path to the index.html.

```Dockerfile
# syntax = docker/dockerfile:1.5.2

FROM cmdjulian/httpd:v1.36.0 

COPY --link ./dist/app/ /opt/httpd
COPY --link <<EOF /etc/httpd/httpd.conf
E404:index.html
EOF
```

## Credits

The image is inspired by Florian Lipans [blog post](https://lipanski.com/posts/smallest-docker-image-static-website)
However, it does not provide multi-arch support and also lacks a proper init wrapper like `tini`.
Logo is taken from [Mario Pinkster](https://www.sentiatechblog.com/running-apache-in-a-docker-container)

## Development

- To make busybox compile for `arm/v7`, we have to set `CONFIG_LFS=y` in the
  config [GitHub issue](https://github.com/dyne/ZShaolin/blob/master/build/busybox/README.md)
- `CONFIG_STATIC=y` has to be set to compile httpd statically. If we don't do that, the error message from `tini` is
  very misleading. It says something like `/bin/httpd` not found, even if this file exists
- building a specific version can be archived by providing a build-arg as `BUSYBOX_VERSION=$VERSION`. Keep in mind
  though, that the config present in [config](./config) is most definitely not compatible and needs adjustments
