#
# Image: base
#

FROM alpine:latest AS base--image--alpine

FROM busybox:latest AS base--image--busybox

FROM debian:stable-slim AS base--image--debian

FROM ubuntu:latest AS base--image--ubuntu

# Extended edition
FROM --platform=$BUILDPLATFORM base--image--debian AS base--hugo--fetcher-extended

ARG VERSION_ARG=0.0.0

ENV HUGO_VERSION=${VERSION_ARG}

ARG TARGETPLATFORM

RUN apt update && apt full-upgrade -y && apt install -y wget

#COPY --from=base--files--script /hugo-extended.sh hugo.sh
ADD _script/hugo-extended.sh hugo.sh
RUN sh hugo.sh



FROM scratch AS base--hugo--extended

COPY --from=base--hugo--fetcher-extended /files /




# Standard edition
FROM --platform=$BUILDPLATFORM base--image--alpine AS base--hugo--fetcher-standard

ARG VERSION_ARG=0.0.0

ENV HUGO_VERSION=${VERSION_ARG}

ARG TARGETPLATFORM

# RUN echo "I am running on $BUILDPLATFORM, building for $TARGETPLATFORM"

#COPY --from=base--files--scripts /hugo-standard.sh hugo.sh
ADD _script/hugo-standard.sh hugo.sh
RUN sh hugo.sh



FROM scratch AS base--hugo--standard

COPY --from=base--hugo--fetcher-standard /files /

FROM base--image--alpine AS base--certs--source

RUN apk -U upgrade && apk --no-cache add ca-certificates \
 && cp -r -L /etc/ssl/certs /certs


FROM scratch AS base--certs

COPY --from=base--certs--source /certs /etc/ssl/certs

FROM base--image--alpine AS base--golang--fetcher

ARG TARGETPLATFORM

ADD _script/golang.sh golang.sh
#COPY --from=base--files--scripts golang.sh golang.sh
RUN sh golang.sh



FROM scratch AS base--golang

COPY --from=base--golang--fetcher /files /

# FROM base--image--alpine AS fetcher-glibc

# ARG TARGETPLATFORM

# ADD _script/nodejs-glibc.sh nodejs.sh
# RUN sh nodejs.sh



# FROM scratch AS glibc

# COPY --from=fetcher-glibc /files /





# FROM base--image--alpine AS fetcher-musl

# ARG TARGETPLATFORM

# ADD _script/nodejs-musl.sh nodejs.sh
# RUN sh nodejs.sh



# # FROM scratch AS musl

# # COPY --from=fetcher-musl /files /



# Use the official Node.js Alpine image as the first stage
FROM node:current-alpine AS base--nodejs--node-base

# Initialize the second stage with your custom image
FROM scratch AS base--nodejs--musl

# Copy Node.js, npm, and yarn related files and directories from the first stage to the second stage
COPY --from=base--nodejs--node-base /usr/lib /usr/lib
COPY --from=base--nodejs--node-base /usr/local/share /usr/local/share
COPY --from=base--nodejs--node-base /usr/local/lib /usr/local/lib
COPY --from=base--nodejs--node-base /usr/local/include /usr/local/include
COPY --from=base--nodejs--node-base /usr/local/bin /usr/local/bin
COPY --from=base--nodejs--node-base /opt /opt

FROM base--image--alpine AS base--pandoc--fetcher

ARG TARGETPLATFORM

ADD _script/pandoc.sh pandoc.sh
RUN sh pandoc.sh

ADD pandoc /files


FROM scratch AS base--pandoc

COPY --from=base--pandoc--fetcher /files /

FROM base--image--alpine AS base--sass--fetcher

ARG TARGETPLATFORM

ADD _script/sass.sh sass.sh
RUN sh sass.sh



FROM scratch AS base--sass

COPY --from=base--sass--fetcher /files /

FROM base--image--alpine AS base--files--fetcher

ADD . /files

RUN chmod a+x /files/**/bin/* /files/**/usr/bin/*
RUN chmod a+x /files/pandoc/usr/bin/pandoc

FROM scratch AS base--files--scripts

COPY --from=base--files--fetcher /files/_script /


FROM scratch AS base--files--alpine

COPY --from=base--files--fetcher /files/alpine /


FROM scratch AS base--files--busybox

COPY --from=base--files--fetcher /files/busybox /


FROM scratch AS base--files--debian

COPY --from=base--files--fetcher /files/debian /


FROM base--files--debian AS base--files--ubuntu



FROM alpine:latest AS base--combine

# Copy content of files folder to populate base image
COPY --from=base--files--alpine / /files/alpine
COPY --from=base--files--busybox / /files/busybox
COPY --from=base--files--debian / /files/debian
COPY --from=base--files--ubuntu / /files/ubuntu

# Copy Hugo files
COPY --from=base--hugo--standard / /files/hugo-standard
COPY --from=base--hugo--extended / /files/hugo-extended

RUN ls /files

RUN  getent group hugo 2>&1 > /dev/null || addgroup -g 1234 hugo \
    && getent passwd hugo 2>&1 > /dev/null || adduser -u 1234 -D -H -G hugo -g "" hugo 

USER hugo

FROM scratch AS base

# Copy prepared files to root of base image
COPY --from=base--combine /files /

USER hugo

#
# Image: alpine
#

FROM scratch AS alpine--image

COPY --from=base--files--alpine / /
COPY --from=base--hugo--standard / /
COPY --from=base--certs / /



FROM base--image--alpine AS alpine--main

ARG VERSION_ARG=0.0.0

ENV HUGO_VERSION=${VERSION_ARG}

ENV HUGO_BIND="0.0.0.0" \
    HUGO_DESTINATION="public" \
    HUGO_ENV="DEV" \
    HOME="/home/hugo"

COPY --from=alpine--image / /
USER root
RUN  getent group hugo 2>&1 > /dev/null || addgroup -g 1234 hugo \
    && getent passwd hugo 2>&1 > /dev/null || adduser -u 1234 -D -H -G hugo -g "" hugo 
RUN apk -U upgrade && apk --no-cache add busybox-suid bash bash-completion tzdata make \
 && find /tmp -mindepth 1 -maxdepth 1 | xargs rm -rf \
 && mkdir -p /src /target \
 && chown -R hugo:hugo /src /target \
 && chmod a+rwx /src /target 

VOLUME [ "/src", "/target" ]


EXPOSE 1313
WORKDIR /src
ENTRYPOINT ["hugo"]

FROM alpine--main AS alpine--ci

ENV HUGO_ENV="production"
RUN chown -R hugo:hugo /src /target
USER hugo
ENTRYPOINT [ "" ]
CMD [ "hugo" ]

FROM alpine--main AS alpine--onbuild

ONBUILD ARG HUGO_CMD
ONBUILD ARG HUGO_DESTINATION_ARG
ONBUILD ARG HUGO_ENV_ARG
ONBUILD ARG HUGO_DIR
ONBUILD ARG ONBUILD_SCRIPT

ONBUILD ENV HUGO_DESTINATION="${HUGO_DESTINATION_ARG:-/target}" \
            HUGO_ENV="${HUGO_ENV_ARG:-DEV}" \
            ONBUILD_SCRIPT_VALUE="${ONBUILD_SCRIPT:-.hugo-onbuild.sh}"

ONBUILD COPY . /src
ONBUILD WORKDIR ${HUGO_DIR:-/src}
ONBUILD RUN chown -R hugo:hugo /src /target
ONBUILD USER hugo

ONBUILD RUN if [ -e "$ONBUILD_SCRIPT_VALUE" ]; then exec sh $ONBUILD_SCRIPT_VALUE; else exec hugo $HUGO_CMD; fi

FROM alpine--main AS alpine
USER hugo

FROM alpine AS asciidoctor--main
USER root
RUN  getent group hugo 2>&1 > /dev/null || addgroup -g 1234 hugo \
    && getent passwd hugo 2>&1 > /dev/null || adduser -u 1234 -D -H -G hugo -g "" hugo 
RUN apk -U upgrade && apk --no-cache add asciidoctor \
 && gem install coderay asciidoctor-rouge --no-document \
 && find /tmp -mindepth 1 -maxdepth 1 | xargs rm -rf

VOLUME [ "/src", "/target" ]


FROM asciidoctor--main AS asciidoctor--ci

ENV HUGO_ENV="production"
RUN chown -R hugo:hugo /src /target
USER hugo
ENTRYPOINT [ "" ]
CMD [ "hugo" ]

FROM asciidoctor--main AS asciidoctor--onbuild

ONBUILD ARG HUGO_CMD
ONBUILD ARG HUGO_DESTINATION_ARG
ONBUILD ARG HUGO_ENV_ARG
ONBUILD ARG HUGO_DIR
ONBUILD ARG ONBUILD_SCRIPT

ONBUILD ENV HUGO_DESTINATION="${HUGO_DESTINATION_ARG:-/target}" \
            HUGO_ENV="${HUGO_ENV_ARG:-DEV}" \
            ONBUILD_SCRIPT_VALUE="${ONBUILD_SCRIPT:-.hugo-onbuild.sh}"

ONBUILD COPY . /src
ONBUILD WORKDIR ${HUGO_DIR:-/src}
ONBUILD RUN chown -R hugo:hugo /src /target
ONBUILD USER hugo

ONBUILD RUN if [ -e "$ONBUILD_SCRIPT_VALUE" ]; then exec sh $ONBUILD_SCRIPT_VALUE; else exec hugo $HUGO_CMD; fi

USER hugo

FROM asciidoctor--main AS asciidoctor

USER hugo

FROM alpine AS pandoc--main

ENV HUGO_PANDOC="pandoc-default"

COPY --from=base--pandoc / /

RUN  getent group hugo 2>&1 > /dev/null || addgroup -g 1234 hugo \
    && getent passwd hugo 2>&1 > /dev/null || adduser -u 1234 -D -H -G hugo -g "" hugo 

VOLUME [ "/src", "/target" ]

FROM pandoc--main AS pandoc--ci

ENV HUGO_ENV="production"
RUN chown -R hugo:hugo /src /target
USER hugo
ENTRYPOINT [ "" ]
CMD [ "hugo" ]

FROM pandoc--main AS pandoc--onbuild

ONBUILD ARG HUGO_CMD
ONBUILD ARG HUGO_DESTINATION_ARG
ONBUILD ARG HUGO_ENV_ARG
ONBUILD ARG HUGO_DIR
ONBUILD ARG ONBUILD_SCRIPT

ONBUILD ENV HUGO_DESTINATION="${HUGO_DESTINATION_ARG:-/target}" \
            HUGO_ENV="${HUGO_ENV_ARG:-DEV}" \
            ONBUILD_SCRIPT_VALUE="${ONBUILD_SCRIPT:-.hugo-onbuild.sh}"

ONBUILD COPY . /src
ONBUILD WORKDIR ${HUGO_DIR:-/src}
ONBUILD RUN chown -R hugo:hugo /src /target
ONBUILD USER hugo

ONBUILD RUN if [ -e "$ONBUILD_SCRIPT_VALUE" ]; then exec sh $ONBUILD_SCRIPT_VALUE; else exec hugo $HUGO_CMD; fi

USER hugo

FROM pandoc--main AS pandoc

USER hugo

#
# Image: ext-alpine
#

FROM scratch AS ext-alpine--image

COPY --from=base--files--alpine / /
COPY --from=base--hugo--extended / /
COPY --from=base--certs / /
COPY --from=base--nodejs--musl / /
COPY --from=base--golang / /



FROM base--image--alpine AS ext-alpine--main

ARG VERSION_ARG=0.0.0

ENV HUGO_VERSION=${VERSION_ARG}

ENV HUGO_BIND="0.0.0.0" \
    HUGO_DESTINATION="public" \
    HUGO_ENV="DEV" \
    HUGO_EDITION="extended" \
    HUGO_CACHEDIR="/tmp" \
    NODE_PATH=".:/usr/local/lib/node_modules:/usr/local/node/lib/node_modules" \
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/node/bin" \
    GOROOT="/usr/local/lib/go" \
    HOME="/home/hugo"

USER root

RUN apk -U upgrade && apk add --no-cache libc6-compat gcompat libstdc++ openssl ncurses-libs busybox-suid bash bash-completion git tzdata make \
    # Python 3
    python3 py3-pip py3-setuptools

COPY --from=ext-alpine--image / /

RUN  getent group hugo 2>&1 > /dev/null || addgroup -g 1234 hugo \
    && getent passwd hugo 2>&1 > /dev/null || adduser -u 1234 -D -H -G hugo -g "" hugo 

RUN true \
 #
 # Install npm packages
 && npm install -g autoprefixer postcss postcss-cli @babel/cli @babel/core @fullhuman/postcss-purgecss \
 #
 # Install rst2html
 && pip install --break-system-packages rst2html \
 #
 # Cleaning
 && apk del py-pip py-setuptools \ 
 && find /tmp -mindepth 1 -maxdepth 1 | xargs rm -rf \
 #
 # Prepare folders
 && mkdir -p /src /target \
 && chown -R hugo:hugo /src /target \
 && chmod a+wrx /src /target \
 #
 # add /src to safe.directory
 && git config --global --add safe.directory /src

VOLUME [ "/src", "/target" ]

EXPOSE 1313

WORKDIR /src

USER hugo

ENTRYPOINT ["hugo"]

FROM ext-alpine--main AS ext-alpine--ci

ENV HUGO_ENV="production"
RUN chown -R hugo:hugo /src /target
USER hugo
ENTRYPOINT [ "" ]
CMD [ "hugo" ]

FROM ext-alpine--main AS ext-alpine--onbuild

ONBUILD ARG HUGO_CMD
ONBUILD ARG HUGO_DESTINATION_ARG
ONBUILD ARG HUGO_ENV_ARG
ONBUILD ARG HUGO_DIR
ONBUILD ARG ONBUILD_SCRIPT

ONBUILD ENV HUGO_DESTINATION="${HUGO_DESTINATION_ARG:-/target}" \
            HUGO_ENV="${HUGO_ENV_ARG:-DEV}" \
            ONBUILD_SCRIPT_VALUE="${ONBUILD_SCRIPT:-.hugo-onbuild.sh}"

ONBUILD COPY . /src
ONBUILD WORKDIR ${HUGO_DIR:-/src}
ONBUILD RUN chown -R hugo:hugo /src /target
ONBUILD USER hugo

ONBUILD RUN if [ -e "$ONBUILD_SCRIPT_VALUE" ]; then exec sh $ONBUILD_SCRIPT_VALUE; else exec hugo $HUGO_CMD; fi

FROM ext-alpine--main AS ext-alpine

USER hugo

FROM ext-alpine AS ext-asciidoctor--main

USER root

RUN  getent group hugo 2>&1 > /dev/null || addgroup -g 1234 hugo \
    && getent passwd hugo 2>&1 > /dev/null || adduser -u 1234 -D -H -G hugo -g "" hugo 

RUN apk -U upgrade && apk --no-cache add asciidoctor \
 && gem install coderay --no-document \
 && find /tmp -mindepth 1 -maxdepth 1 | xargs rm -rf \
 && mkdir -p /src /target \
 && chown -R hugo:hugo /src /target \
 && chmod -R a+rwx /src /target

 VOLUME [ "/src", "/target" ]

FROM ext-asciidoctor--main AS ext-asciidoctor--ci

ENV HUGO_ENV="production"
RUN chown -R hugo:hugo /src /target
USER hugo
ENTRYPOINT [ "" ]
CMD [ "hugo" ]

FROM ext-asciidoctor--main AS ext-asciidoctor--onbuild

ONBUILD ARG HUGO_CMD
ONBUILD ARG HUGO_DESTINATION_ARG
ONBUILD ARG HUGO_ENV_ARG
ONBUILD ARG HUGO_DIR
ONBUILD ARG ONBUILD_SCRIPT

ONBUILD ENV HUGO_DESTINATION="${HUGO_DESTINATION_ARG:-/target}" \
            HUGO_ENV="${HUGO_ENV_ARG:-DEV}" \
            ONBUILD_SCRIPT_VALUE="${ONBUILD_SCRIPT:-.hugo-onbuild.sh}"

ONBUILD COPY . /src
ONBUILD WORKDIR ${HUGO_DIR:-/src}
ONBUILD RUN chown -R hugo:hugo /src /target
ONBUILD USER hugo

ONBUILD RUN if [ -e "$ONBUILD_SCRIPT_VALUE" ]; then exec sh $ONBUILD_SCRIPT_VALUE; else exec hugo $HUGO_CMD; fi

USER hugo

FROM ext-asciidoctor--main AS ext-asciidoctor

USER hugo

FROM ext-alpine AS ext-pandoc--main

VOLUME [ "/src", "/target" ]

COPY --from=base--pandoc / /

RUN  getent group hugo 2>&1 > /dev/null || addgroup -g 1234 hugo \
    && getent passwd hugo 2>&1 > /dev/null || adduser -u 1234 -D -H -G hugo -g "" hugo 

FROM ext-pandoc--main AS ext-pandoc--ci

ENV HUGO_ENV="production"
RUN chown -R hugo:hugo /src /target
USER hugo
ENTRYPOINT [ "" ]
CMD [ "hugo" ]

FROM ext-pandoc--main AS ext-pandoc--onbuild

ONBUILD ARG HUGO_CMD
ONBUILD ARG HUGO_DESTINATION_ARG
ONBUILD ARG HUGO_ENV_ARG
ONBUILD ARG HUGO_DIR
ONBUILD ARG ONBUILD_SCRIPT

ONBUILD ENV HUGO_DESTINATION="${HUGO_DESTINATION_ARG:-/target}" \
            HUGO_ENV="${HUGO_ENV_ARG:-DEV}" \
            ONBUILD_SCRIPT_VALUE="${ONBUILD_SCRIPT:-.hugo-onbuild.sh}"

ONBUILD COPY . /src
ONBUILD WORKDIR ${HUGO_DIR:-/src}
ONBUILD RUN chown -R hugo:hugo /src /target
ONBUILD USER hugo

ONBUILD RUN if [ -e "$ONBUILD_SCRIPT_VALUE" ]; then exec sh $ONBUILD_SCRIPT_VALUE; else exec hugo $HUGO_CMD; fi

FROM ext-pandoc--main AS ext-pandoc

USER hugo

#
# Image: busybox
#

FROM scratch AS busybox--image

COPY --from=base--files--busybox / /
COPY --from=base--hugo--standard / /
COPY --from=base--certs / /



FROM base--image--busybox AS busybox--main

ARG VERSION_ARG=0.0.0

ENV HUGO_VERSION=${VERSION_ARG}

ENV HUGO_BIND="0.0.0.0" \
    HUGO_DESTINATION="public" \
    HUGO_ENV="DEV" \
    HUGO_EDITION="standard" \
    HOME="/home/hugo"

COPY --from=busybox--image / /

RUN  getent group hugo 2>&1 > /dev/null || addgroup -g 1234 hugo \
    && getent passwd hugo 2>&1 > /dev/null || adduser -u 1234 -D -H -G hugo -g "" hugo 

RUN mkdir -p /src /target \
 && chown -R hugo:hugo /src /target \
 && chmod a+wrx /src /target

VOLUME [ "/src", "/target" ]

EXPOSE 1313

WORKDIR /src

ENTRYPOINT ["hugo"]

FROM busybox--main AS busybox--ci

ENV HUGO_ENV="production"
RUN chown -R hugo:hugo /src /target
USER hugo
ENTRYPOINT [ "" ]
CMD [ "hugo" ]

USER hugo

FROM busybox--main AS busybox--onbuild

ONBUILD ARG HUGO_CMD
ONBUILD ARG HUGO_DESTINATION_ARG
ONBUILD ARG HUGO_ENV_ARG
ONBUILD ARG HUGO_DIR
ONBUILD ARG ONBUILD_SCRIPT

ONBUILD ENV HUGO_DESTINATION="${HUGO_DESTINATION_ARG:-/target}" \
            HUGO_ENV="${HUGO_ENV_ARG:-DEV}" \
            ONBUILD_SCRIPT_VALUE="${ONBUILD_SCRIPT:-.hugo-onbuild.sh}"

ONBUILD COPY . /src
ONBUILD WORKDIR ${HUGO_DIR:-/src}
ONBUILD RUN chown -R hugo:hugo /src /target
ONBUILD USER hugo

ONBUILD RUN if [ -e "$ONBUILD_SCRIPT_VALUE" ]; then exec sh $ONBUILD_SCRIPT_VALUE; else exec hugo $HUGO_CMD; fi

USER hugo

FROM busybox--main AS busybox

USER hugo

#
# Image: debian
#

FROM base--image--debian AS base-debian

ARG VERSION_ARG=0.0.0

ENV HUGO_VERSION=${VERSION_ARG}

ENV HUGO_BIND="0.0.0.0" \
    HUGO_DESTINATION="public" \
    HUGO_ENV="DEV" \
    HOME="/home/hugo"
USER root

# Create a custom user with UID 1234 and GID 1234
RUN getent group hugo 2>&1 > /dev/null || groupadd -g 1234 hugo && \
    getent passwd hugo 2>&1 > /dev/null || useradd -m -u 1234 -g hugo hugo 

RUN apt update \
 && apt full-upgrade -y \
 && DEBIAN_FRONTEND=noninteractive apt install -y wget bash-completion tzdata make ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && find /tmp -mindepth 1 -maxdepth 1 | xargs rm -rf \
 && mkdir -p /src /target \
 && chown -R hugo:hugo /src /target \
 && chmod a+wrx /src /target

COPY --from=base--files--debian / /

VOLUME [ "/src", "/target" ]

EXPOSE 1313
WORKDIR /src
USER hugo
ENTRYPOINT ["hugo"]

FROM base-debian AS debian--main

ENV HUGO_EDITION="standard"

COPY --from=base--hugo--standard / /


# Create a custom user with UID 1234 and GID 1234
RUN getent group hugo 2>&1 > /dev/null || groupadd -g 1234 hugo && \
    getent passwd hugo 2>&1 > /dev/null || useradd -m -u 1234 -g hugo hugo 

FROM debian--main AS debian--ci

ENV HUGO_ENV="production"
RUN chown -R hugo:hugo /src /target
USER hugo
ENTRYPOINT [ "" ]
CMD [ "hugo" ]

FROM debian--main AS debian--onbuild

ONBUILD ARG HUGO_CMD
ONBUILD ARG HUGO_DESTINATION_ARG
ONBUILD ARG HUGO_ENV_ARG
ONBUILD ARG HUGO_DIR
ONBUILD ARG ONBUILD_SCRIPT

ONBUILD ENV HUGO_DESTINATION="${HUGO_DESTINATION_ARG:-/target}" \
            HUGO_ENV="${HUGO_ENV_ARG:-DEV}" \
            ONBUILD_SCRIPT_VALUE="${ONBUILD_SCRIPT:-.hugo-onbuild.sh}"

ONBUILD COPY . /src
ONBUILD WORKDIR ${HUGO_DIR:-/src}
ONBUILD RUN chown -R hugo:hugo /src /target
ONBUILD USER hugo

ONBUILD RUN if [ -e "$ONBUILD_SCRIPT_VALUE" ]; then exec sh $ONBUILD_SCRIPT_VALUE; else exec hugo $HUGO_CMD; fi

VOLUME [ "/src", "/target" ]

FROM debian--main AS debian

USER hugo

#
# Image: ext-debian
#

FROM scratch AS ext-debian--image

COPY --from=base--hugo--extended / /
COPY --from=base--pandoc / /
COPY --from=base--sass / /
#COPY --from=base--nodejs--glibc / /



FROM base-debian AS ext-debian--main

ENV HUGO_EDITION="extended" \
    HUGO_CACHEDIR="/tmp" \
    NODE_PATH=".:/usr/lib/node_modules" \
    #NODE_PATH=".:/usr/local/node/lib/node_modules" \
    #PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/node/bin" \
    GOROOT="/usr/local/lib/go"

COPY --from=ext-debian--image / /

USER root


# Create a custom user with UID 1234 and GID 1234
RUN getent group hugo 2>&1 > /dev/null || groupadd -g 1234 hugo && \
    getent passwd hugo 2>&1 > /dev/null || useradd -m -u 1234 -g hugo hugo 

RUN true \
 #
 # Install software
 && apt update \
 && apt -y full-upgrade \
 && DEBIAN_FRONTEND=noninteractive apt install -y curl git gnupg apt-transport-https lsb-release \
 #
 # Install Python 3 and rst2html
 && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends python3-minimal python3-pip python3-setuptools python3-wheel \
 && pip install --break-system-packages rst2html \
 #
 # Install NodeJS and tooling
 && apt install -y ca-certificates curl gnupg \
 && mkdir -p /etc/apt/keyrings \
 && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_23.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
 && apt update \
 && apt install nodejs -y \
#
# && curl -sL https://deb.nodesource.com/setup_20.x | bash - \
# && apt install -y nodejs \
 && npm install -g autoprefixer postcss postcss-cli yarn @babel/cli @babel/core @fullhuman/postcss-purgecss \
 #
 # Install Asciidoctor
 && DEBIAN_FRONTEND=noninteractive apt install -y ruby \
 && gem install asciidoctor coderay --no-document \
 #
 # Cleaning up
 && apt remove -y curl gnupg apt-transport-https lsb-release python3-pip python3-setuptools python3-wheel \
 && apt autoremove -y \
 && rm -rf /var/lib/apt/lists/* \
 && find /tmp -mindepth 1 -maxdepth 1 | xargs rm -rf \
 && mkdir -p /src /target \
 && chown -R hugo:hugo /src /target \
 && chmod a+wrx /src /target \
 #
 # add /src to safe.directory
 && git config --global --add safe.directory /src

COPY --from=base--golang / /

VOLUME [ "/src", "/target" ]

FROM ext-debian--main AS ext-debian--ci

ENV HUGO_ENV="production"
RUN chown -R hugo:hugo /src /target
USER hugo
ENTRYPOINT [ "" ]
CMD [ "hugo" ]

FROM ext-debian--main AS ext-debian--onbuild

ONBUILD ARG HUGO_CMD
ONBUILD ARG HUGO_DESTINATION_ARG
ONBUILD ARG HUGO_ENV_ARG
ONBUILD ARG HUGO_DIR
ONBUILD ARG ONBUILD_SCRIPT

ONBUILD ENV HUGO_DESTINATION="${HUGO_DESTINATION_ARG:-/target}" \
            HUGO_ENV="${HUGO_ENV_ARG:-DEV}" \
            ONBUILD_SCRIPT_VALUE="${ONBUILD_SCRIPT:-.hugo-onbuild.sh}"

ONBUILD COPY . /src
ONBUILD WORKDIR ${HUGO_DIR:-/src}
ONBUILD RUN chown -R hugo:hugo /src /target
ONBUILD USER hugo

ONBUILD RUN if [ -e "$ONBUILD_SCRIPT_VALUE" ]; then exec sh $ONBUILD_SCRIPT_VALUE; else exec hugo $HUGO_CMD; fi

FROM ext-debian--main AS ext-debian

USER hugo

#
# Image: ubuntu
#

FROM base--image--ubuntu AS base-ubuntu

ARG VERSION_ARG=0.0.0

ENV HUGO_VERSION=${VERSION_ARG}

ENV HUGO_BIND="0.0.0.0" \
    HUGO_DESTINATION="public" \
    HUGO_ENV="DEV" \
    HOME="/home/hugo"

COPY --from=base--files--ubuntu / /

USER root


# Create a custom user with UID 1234 and GID 1234
RUN getent group hugo 2>&1 > /dev/null || groupadd -g 1234 hugo && \
    getent passwd hugo 2>&1 > /dev/null || useradd -m -u 1234 -g hugo hugo 

RUN apt update \
 && apt -y full-upgrade \
 && DEBIAN_FRONTEND=noninteractive apt install -y wget bash-completion tzdata make ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && find /tmp -mindepth 1 -maxdepth 1 | xargs rm -rf \
 && mkdir -p /src /target \
 && chown -R hugo:hugo /src /target \
 && chmod a+wrx /src /target 

VOLUME [ "/src", "/target" ]

EXPOSE 1313
WORKDIR /src

USER hugo

ENTRYPOINT ["hugo"]

FROM base-ubuntu AS ubuntu--main

ENV HUGO_EDITION="standard"

COPY --from=base--hugo--standard / /


# Create a custom user with UID 1234 and GID 1234
RUN getent group hugo 2>&1 > /dev/null || groupadd -g 1234 hugo && \
    getent passwd hugo 2>&1 > /dev/null || useradd -m -u 1234 -g hugo hugo 

FROM ubuntu--main AS ubuntu--ci

ENV HUGO_ENV="production"
RUN chown -R hugo:hugo /src /target
USER hugo
ENTRYPOINT [ "" ]
CMD [ "hugo" ]

FROM ubuntu--main AS ubuntu--onbuild

ONBUILD ARG HUGO_CMD
ONBUILD ARG HUGO_DESTINATION_ARG
ONBUILD ARG HUGO_ENV_ARG
ONBUILD ARG HUGO_DIR
ONBUILD ARG ONBUILD_SCRIPT

ONBUILD ENV HUGO_DESTINATION="${HUGO_DESTINATION_ARG:-/target}" \
            HUGO_ENV="${HUGO_ENV_ARG:-DEV}" \
            ONBUILD_SCRIPT_VALUE="${ONBUILD_SCRIPT:-.hugo-onbuild.sh}"

ONBUILD COPY . /src
ONBUILD WORKDIR ${HUGO_DIR:-/src}
ONBUILD RUN chown -R hugo:hugo /src /target
ONBUILD USER hugo

ONBUILD RUN if [ -e "$ONBUILD_SCRIPT_VALUE" ]; then exec sh $ONBUILD_SCRIPT_VALUE; else exec hugo $HUGO_CMD; fi

VOLUME [ "/src", "/target" ]

FROM ubuntu--main AS ubuntu

USER hugo

#
# Image: ext-ubuntu
#

FROM scratch AS ext-ubuntu--image

COPY --from=base--hugo--extended / /
COPY --from=base--pandoc / /
COPY --from=base--sass / /
#COPY --from=base--nodejs--glibc / /



FROM base-ubuntu AS ext-ubuntu--main

ENV HUGO_EDITION="extended" \
    HUGO_CACHEDIR="/tmp" \
    NODE_PATH=".:/usr/lib/node_modules" \
    #NODE_PATH=".:/usr/local/node/lib/node_modules" \
    #PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/node/bin" \
    GOROOT="/usr/local/lib/go"

COPY --from=ext-ubuntu--image / /

USER root


# Create a custom user with UID 1234 and GID 1234
RUN getent group hugo 2>&1 > /dev/null || groupadd -g 1234 hugo && \
    getent passwd hugo 2>&1 > /dev/null || useradd -m -u 1234 -g hugo hugo 

RUN true \
 #
 # Install software
 && apt update \
 && apt -y autoremove \
 && apt -y full-upgrade \
 && DEBIAN_FRONTEND=noninteractive apt install -y curl git gnupg apt-transport-https lsb-release \
 #
 # Install Python 3 and rst2html
 && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends python3-minimal python3-pip python3-setuptools python3-wheel \
 && pip install --break-system-packages rst2html \
 #
 # Install NodeJS and tooling
 && apt install -y ca-certificates curl gnupg \
 && mkdir -p /etc/apt/keyrings \
 && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_23.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
 && apt update \
 && apt install nodejs -y \
#
#  && curl -sL https://deb.nodesource.com/setup_20.x | bash - \
#  && apt install -y nodejs \
 && npm install -g autoprefixer postcss postcss-cli yarn @babel/cli @babel/core @fullhuman/postcss-purgecss \
 #
 # Install Asciidoctor
 && DEBIAN_FRONTEND=noninteractive apt install -y ruby \
 && gem install asciidoctor coderay --no-document \
 #
 # Cleaning up
 && apt remove -y curl gnupg apt-transport-https lsb-release python3-pip python3-setuptools python3-wheel \
 && apt autoremove -y \
 && rm -rf /var/lib/apt/lists/* \
 && find /tmp -mindepth 1 -maxdepth 1 | xargs rm -rf \
 && mkdir -p /src /target \
 && chown -R hugo:hugo /src /target \
 && chmod a+wrx /src /target \
 #
 # add /src to safe.directory
 && git config --global --add safe.directory /src 
 
COPY --from=base--golang / /

VOLUME [ "/src", "/target" ]

FROM ext-ubuntu--main AS ext-ubuntu--ci

ENV HUGO_ENV="production"
RUN chown -R hugo:hugo /src /target
USER hugo
ENTRYPOINT [ "" ]
CMD [ "hugo" ]

FROM ext-ubuntu--main AS ext-ubuntu--onbuild

ONBUILD ARG HUGO_CMD
ONBUILD ARG HUGO_DESTINATION_ARG
ONBUILD ARG HUGO_ENV_ARG
ONBUILD ARG HUGO_DIR
ONBUILD ARG ONBUILD_SCRIPT

ONBUILD ENV HUGO_DESTINATION="${HUGO_DESTINATION_ARG:-/target}" \
            HUGO_ENV="${HUGO_ENV_ARG:-DEV}" \
            ONBUILD_SCRIPT_VALUE="${ONBUILD_SCRIPT:-.hugo-onbuild.sh}"

ONBUILD COPY . /src
ONBUILD WORKDIR ${HUGO_DIR:-/src}
ONBUILD RUN chown -R hugo:hugo /src /target
ONBUILD USER hugo

ONBUILD RUN if [ -e "$ONBUILD_SCRIPT_VALUE" ]; then exec sh $ONBUILD_SCRIPT_VALUE; else exec hugo $HUGO_CMD; fi

USER hugo

FROM ext-ubuntu--main AS ext-ubuntu

USER hugo