# httpd-docker

## General

Minimal `httpd` shell-less multi-arch docker image based on scratch.

The image is based on scratch and contains a static striped busybox binary just including `httpd` applet.
The image is published on docker hub under `cmdjulian/httpd:{version}`. It supports `amd64`, `arm` and  `arm64`
architecture.

Per default, it runs as a non-root user `httpd(id=10001)`. Alternatively, you can also switch to `root(id=0)`.

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
# syntax = docker/dockerfile:1.4.3

FROM cmdjulian/httpd:v1.35.0 

COPY --link ./dist/app/ /opt/httpd
COPY --link <<EOF /etc/httpd/httpd.conf
E404:index.html
EOF
```

## Credits

The image is inspired by Florian Lipans blog post regarding minimal http server docker
image [click me](https://lipanski.com/posts/smallest-docker-image-static-website) by does better by providing multi-arch
support and using `tini` init wrapper for graceful init signal handling. I also used `upx` to further reduce the image
size, to actually achieve a total image size of just `134kB`!