FROM scratch as image

COPY --from=base--hugo--extended / /
COPY --from=base--pandoc / /
COPY --from=base--sass / /
#COPY --from=base--nodejs--glibc / /



FROM base-debian AS main

ENV HUGO_EDITION="extended" \
    HUGO_CACHEDIR="/tmp" \
    NODE_PATH=".:/usr/lib/node_modules" \
    #NODE_PATH=".:/usr/local/node/lib/node_modules" \
    #PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/node/bin" \
    GOROOT="/usr/local/lib/go"

COPY --from=image / /

USER root

IMPORT ../_imports/default_nonroot_user.df

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
 && DEBIAN_FRONTEND=noninteractive apt install -y ruby asciidoctor coderay \
 #
 # Cleaning up
 && apt remove -y curl gnupg apt-transport-https lsb-release python3-pip python3-setuptools python3-wheel \
 && apt autoremove -y \
 && rm -rf /var/lib/apt/lists/* \
 && find /tmp -mindepth 1 -maxdepth 1 | xargs rm -rf \
 && mkdir -p /src /target \
 && chown -R hugo:hugo /src /target /home/hugo \
 && chmod a+wrx /src /target \
 #
 # add /src to safe.directory
 && git config --global --add safe.directory /src

COPY --from=base--golang / /

VOLUME [ "/src", "/target" ]

IMPORT ../_imports/ci.df

RUN git config --global --add safe.directory /src

IMPORT ../_imports/onbuild.df

RUN git config --global --add safe.directory /src

FROM main

USER hugo