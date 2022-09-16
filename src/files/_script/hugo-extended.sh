#!/bin/sh

set -e
set -u

# Variables
# HUGO_VERSION is edited in Dockerfile.

# Architecture
TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}

if [ "$TARGETPLATFORM" = "linux/amd64" ]; then
    HUGO_ARCH="64bit"
    HUGOGURU_ARCH="x86_64"
    HUGO_FILE="hugo_extended_${HUGO_VERSION}_Linux-${HUGO_ARCH}.tar.gz"
elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then
    HUGO_ARCH="arm64"
    HUGOGURU_ARCH="aarch64"
    HUGO_FILE="hugo_extended_${HUGO_VERSION}_linux-${HUGO_ARCH}.tar.gz"
elif [ "$TARGETPLATFORM" = "linux/arm/v7" ]; then
    HUGO_ARCH="arm"
    HUGOGURU_ARCH="armv7l"
    HUGO_FILE="hugo_extended_${HUGO_VERSION}_linux-${HUGO_ARCH}.tar.gz"
else
    echo "Unknown build architecture: $TARGETPLATFORM"
    exit 2
fi

# Download binaries from release
wget https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/${HUGO_FILE}
wget https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_checksums.txt
#wget https://github.com/hugoguru/dist-hugo/releases/download/v${HUGO_VERSION}/hugo-extended-${HUGO_VERSION}-linux-${HUGOGURU_ARCH}.tar.gz
#wget https://github.com/hugoguru/dist-hugo/releases/download/v${HUGO_VERSION}/hugo-${HUGO_VERSION}-checksums-sha256.txt

# Verify checksums
grep  ${HUGO_FILE} hugo_${HUGO_VERSION}_checksums.txt | sha256sum -c
#grep hugo-extended-${HUGO_VERSION}-linux-${HUGOGURU_ARCH}.tar.gz hugo-${HUGO_VERSION}-checksums-sha256.txt | sha256sum -c

# Prepare folders
mkdir -p /files/usr/lib/hugo

# Unpack downloaded content
tar -zxf ${HUGO_FILE} -C /files/usr/lib/hugo
#tar -zxf hugo-extended-${HUGO_VERSION}-linux-${HUGOGURU_ARCH}.tar.gz -C /files/usr/lib/hugo

# Verify executable
/files/usr/lib/hugo/hugo version

# Create autocompletion script
mkdir -p /files/etc/bash_completion.d
/files/usr/lib/hugo/hugo completion bash > /files/etc/bash_completion.d/01-hugo.sh

# Create version file
echo -n "${HUGO_VERSION}" > /files/etc/hugo-release
