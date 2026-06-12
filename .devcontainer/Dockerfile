# Build stage with Spack pre-installed and ready to be used
FROM spack/ubuntu-jammy:latest AS builder

ENV MAKEFLAGS="-j1"
ENV R_MAKEVARS_USER="/dev/null"

# What we want to install and how we want to install it
# is specified in a manifest file (spack.yaml)
RUN mkdir -p /opt/spack-environment && \
set -o noclobber \
&&  (echo spack: \
&&   echo '  # add package specs to the `specs` list' \
&&   echo '  specs:' \
&&   echo '  - r@4.5.1' \
&&   echo '  - r-terra' \
&&   echo '  - r-sf' \
&&   echo '  - r-exactextractr' \
&&   echo '  - python' \
&&   echo '  - neovim' \
&&   echo '  - gdal' \
&&   echo '  - geos' \
&&   echo '  - proj' \
&&   echo '  - sqlite' \
&&   echo '  - curl' \
&&   echo '  - git' \
&&   echo '  - cmake' \
&&   echo '  - gmake' \
&&   echo '  - abseil-cpp' \
&&   echo '  - openssl' \
&&   echo '  - udunits' \
&&   echo '  - libxml2' \
&&   echo '  - libuv' \
&&   echo '  view: /opt/views/view' \
&&   echo '  concretizer:' \
&&   echo '    unify: true' \
&&   echo '  config:' \
&&   echo '    install_tree:' \
&&   echo '      root: /opt/software') > /opt/spack-environment/spack.yaml

# Install the software, remove unnecessary deps
RUN . /opt/spack/share/spack/setup-env.sh && \
    cd /opt/spack-environment && \
    spack env activate . && \
    export MAKEFLAGS="-j1" && \
    export R_MAKEVARS_USER="/dev/null" && \
    spack install --fail-fast -j1 && \
    spack gc -y

# Strip all the binaries
RUN find -L /opt/views/view/* -type f -exec readlink -f '{}' \; | \
    xargs file -i | \
    grep 'charset=binary' | \
    grep 'x-executable\|x-archive\|x-sharedlib' | \
    awk -F: '{print $1}' | xargs strip

# Modifications to the environment that are necessary to run
RUN . /opt/spack/share/spack/setup-env.sh && \
    cd /opt/spack-environment && \
    spack env activate --sh -d . > activate.sh


# Bare OS image to run the installed executables
FROM ubuntu:22.04

COPY --from=builder /opt/spack-environment /opt/spack-environment
COPY --from=builder /opt/software /opt/software
COPY --from=builder /opt/views /opt/views

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    bash \
    locales \
    libgomp1 \
    libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/views/view/bin:${PATH}"
ENV R_HOME="/opt/views/view/rlib/R"
ENV R_LIBS_USER="/work/rv/library"
ENV PROJ_LIB="/opt/views/view/share/proj"
ENV GDAL_DATA="/opt/views/view/share/gdal"
ENV PKG_CONFIG_PATH="/opt/views/view/lib/pkgconfig:/opt/views/view/lib64/pkgconfig:/opt/views/view/share/pkgconfig"

RUN { \
      echo '#!/bin/sh' \
      && echo '. /opt/spack-environment/activate.sh' \
      && echo 'exec "$@"'; \
    } > /entrypoint.sh \
&& chmod a+x /entrypoint.sh \
&& ln -s /opt/views/view /opt/view

WORKDIR /work

RUN echo " ================= Installing arf =================== "
RUN set -eux; \
    case "${TARGETARCH:-amd64}" in \
      amd64) ARF_ARCH="x86_64-unknown-linux-gnu" ;; \
      arm64) ARF_ARCH="aarch64-unknown-linux-gnu" ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL \
      "https://github.com/eitsupi/arf/releases/download/v${ARF_VERSION}/arf-console-${ARF_ARCH}.tar.xz" \
      -o /tmp/arf.tar.xz; \
    mkdir -p /tmp/arf; \
    tar -xJf /tmp/arf.tar.xz -C /tmp/arf; \
    find /tmp/arf -type f -name 'arf' -exec install -m 0755 {} /usr/local/bin/arf \;; \
    rm -rf /tmp/arf /tmp/arf.tar.xz
RUN arf --version

RUN echo " ================ Installing Quarto ================= "
RUN curl -LO https://quarto.org/download/latest/quarto-linux-amd64.deb
RUN gdebi --non-interactive quarto-linux-amd64.deb

RUN echo " ============= Installing VS Code CLI =============== "

RUN set -eux; \
    case "${TARGETARCH:-amd64}" in \
      amd64) VSCODE_OS="cli-alpine-x64" ;; \
      arm64) VSCODE_OS="cli-alpine-arm64" ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://code.visualstudio.com/sha/download?build=stable&os=${VSCODE_OS}" \
      -o /tmp/vscode-cli.tar.gz; \
    mkdir -p /opt/vscode-cli; \
    tar -xzf /tmp/vscode-cli.tar.gz -C /opt/vscode-cli; \
    ln -sf /opt/vscode-cli/code /usr/local/bin/code; \
    rm /tmp/vscode-cli.tar.gz; \
    /usr/local/bin/code --version

RUN echo " ======= Installing VS Code R extension runtime packages ========= "
RUN R -q -e "install.packages(c( \
    'websocket', \
    'later', \
    'jsonlite', \
    'rstudioapi', \
    'svglite', \
    'languageserver', \
    'httpgd' \
  ), repos = 'https://cloud.r-project.org')"
RUN echo " ============ Project Package Managers ============== "
RUN set -eux; \
    curl -sSL https://raw.githubusercontent.com/A2-ai/rv/refs/heads/main/scripts/install.sh | bash; \
    RV_BIN="$(command -v rv || true)"; \
    if [ -z "$RV_BIN" ]; then \
      RV_BIN="$(find /root /usr/local /opt -type f -name rv 2>/dev/null | head -n 1)"; \
    fi; \
    test -n "$RV_BIN"; \
    install -m 0755 "$RV_BIN" /usr/local/bin/rv; \
    /usr/local/bin/rv --version
RUN echo "installing R packages..."
RUN rv sync


# setup the vscode user and workspace
RUN id -u vscode >/dev/null 2>&1 || useradd -m -s /bin/bash vscode
USER vscode
WORKDIR /home/vscode
ENV PATH="/home/vscode/.local/bin:/home/vscode/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
RUN mkdir -p ~/.local/bin ~/.cargo

# Neovim stable-ish binary
# RUN wget -q https://github.com/neovim/neovim/releases/download/v0.11.3/nvim-linux-x86_64.tar.gz \
#     && tar xzf nvim-linux-x86_64.tar.gz -C /opt \
#     && ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim \
#     && rm nvim-linux-x86_64.tar.gz

# health check
RUN echo " ============ Running Tool Health Check ============= "
RUN echo "Checking Quarto installation..."
RUN quarto check
RUN echo "Checking ARF installation..."
RUN arf --version
RUN echo "Checking R installation..."
RUN which R
RUN echo "Checking VS Code CLI installation..."
RUN command -v code && code --version

RUN echo " ================ Setting Up Project ================ "
RUN echo "Installing project dependencies with rv..."
RUN rv --version
RUN echo " ============= Container Setup Complete ============= "
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "/bin/bash" ]
