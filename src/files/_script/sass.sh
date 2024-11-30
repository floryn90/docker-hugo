#!/bin/sh

# This file is triggered inside the _base/Dockerfile-base file.

set -e
set -u

# Variables
SASS_VERSION="1.81.0"

# Architecture
TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}

if [ "$TARGETPLATFORM" = "linux/amd64" ]; then
    ARCH="x64"
elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then
    ARCH="arm64"
else
    echo "Unknown build architecture: $TARGETPLATFORM"
    exit 2
fi

# Download
wget https://github.com/sass/dart-sass/releases/download/${SASS_VERSION}/dart-sass-${SASS_VERSION}-linux-${ARCH}.tar.gz \
  -O /sass.tar.gz

# Unpack
mkdir -p /files/usr/local/lib /files/usr/local/bin
tar -zxvf sass.tar.gz -C /files/usr/local/lib

# Create symlink
ln -s /usr/local/lib/dart-sass/sass /files/usr/local/bin/sass

# Create alias for saas --embedded
alias dart-sass-embedded="sass --embedded"