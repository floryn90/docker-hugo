#!/bin/sh

# This file is triggered inside the _base/Dockerfile-base file.

set -e
set -u

# Variables
PANDOC_VERSION="3.5"

# Architecture
TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}

if [ "$TARGETPLATFORM" = "linux/amd64" ]; then
    PANDOC_ARCH="amd64"
elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then
    PANDOC_ARCH="arm64"
else
    echo "Unknown build architecture: $TARGETPLATFORM"
    exit 2
fi

# Download
url=https://github.com/jgm/pandoc/releases/download/${PANDOC_VERSION}/pandoc-${PANDOC_VERSION}-linux-${PANDOC_ARCH}.tar.gz
wget $url -O /pandoc.tar.gz

# Unpack
tar -zxvf pandoc.tar.gz

# Prepare for image
mkdir -p /files/usr/bin
mv /pandoc-${PANDOC_VERSION}/bin/pandoc /files/usr/bin/pandoc-default

/files/usr/bin/pandoc-default -v
