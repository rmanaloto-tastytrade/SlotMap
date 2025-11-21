FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=slotmap
ARG USER_UID=1000
ARG USER_GID=1000
ARG VCPKG_ROOT=/opt/vcpkg
ARG VCPKG_DOWNLOADS=/opt/vcpkg/downloads
ARG MRDOCS_VERSION=v0.8.0
ARG MRDOCS_ARCHIVE=MrDocs-0.8.0-Linux.tar.xz
ARG MRDOCS_DIR=MrDocs-0.8.0-Linux
ARG NINJA_VERSION=1.13.1
ARG MOLD_VERSION=2.40.4
ARG MOLD_ARCHIVE=mold-${MOLD_VERSION}-x86_64-linux.tar.gz
ARG GH_CLI_VERSION=2.83.1
ARG LLVM_VERSION=21
ARG IWYU_COMMIT=clang_${LLVM_VERSION}
ARG GCC_VERSION=14
ARG CCACHE_VERSION=4.12.1
ARG CCACHE_ARCHIVE=ccache-${CCACHE_VERSION}-linux-x86_64.tar.xz
ARG SCCACHE_VERSION=0.12.0
ARG SCCACHE_ARCHIVE=sccache-v${SCCACHE_VERSION}-x86_64-unknown-linux-musl.tar.gz
ARG RIPGREP_VERSION=14.1.0
ARG RIPGREP_ARCHIVE=ripgrep-${RIPGREP_VERSION}-x86_64-unknown-linux-musl.tar.gz
ARG NODE_VERSION=25.2.1
ARG NODE_DIST=node-v${NODE_VERSION}-linux-x64
ARG BINUTILS_GDB_TAG=binutils-2_45_1
ARG MAKE_VERSION=4.4.1

ENV TZ=UTC \
    VCPKG_ROOT=${VCPKG_ROOT} \
    VCPKG_DOWNLOADS=${VCPKG_DOWNLOADS} \
    VCPKG_FORCE_SYSTEM_BINARIES=1 \
    LLVM_VERSION=${LLVM_VERSION} \
    CCACHE_DIR=/var/cache/ccache \
    SCCACHE_DIR=/var/cache/sccache \
    PATH="/usr/lib/llvm-${LLVM_VERSION}/bin:${PATH}"

# Core OS packages, tooling, and dependencies required for building and docs
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        sudo \
        gnupg \
        software-properties-common \
        pkg-config \
        bash-completion \
        build-essential \
        unzip \
        zip \
        tar \
        python3 \
        python3-pip \
        python3-venv \
        rsync \
        tzdata \
        xz-utils \
        graphviz \
        doxygen \
        openssh-client \
        zsh \
        cppcheck \
        valgrind \
        flex \
        bison \
        texinfo \
        libgmp-dev \
        libmpfr-dev \
        libmpc-dev \
        libexpat1-dev \
        zlib1g-dev \
        autoconf \
        automake \
        libtool \
        m4 \
        autoconf-archive \
        patchelf; \
    rm -rf /var/lib/apt/lists/*

# Latest Git via official PPA
RUN set -eux; \
    add-apt-repository -y ppa:git-core/ppa; \
    apt-get update; \
    apt-get install -y --no-install-recommends git; \
    rm -rf /var/lib/apt/lists/*

# Ninja (latest GitHub release with retries)
RUN set -eux; \
    curl -fSL --retry 5 --retry-delay 5 "https://github.com/ninja-build/ninja/releases/download/v${NINJA_VERSION}/ninja-linux.zip" -o /tmp/ninja.zip; \
    unzip -d /tmp /tmp/ninja.zip; \
    install -m 0755 /tmp/ninja /usr/local/bin/ninja; \
    rm -rf /tmp/ninja /tmp/ninja.zip

# Node.js (official tarball install)
RUN set -eux; \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_DIST}.tar.xz" -o /tmp/node.tar.xz; \
    mkdir -p /usr/local/nodejs; \
    tar -xJf /tmp/node.tar.xz -C /usr/local/nodejs; \
    ln -sf /usr/local/nodejs/${NODE_DIST}/bin/node /usr/local/bin/node; \
    ln -sf /usr/local/nodejs/${NODE_DIST}/bin/npm /usr/local/bin/npm; \
    ln -sf /usr/local/nodejs/${NODE_DIST}/bin/npx /usr/local/bin/npx; \
    rm -rf /tmp/node.tar.xz

# LLVM/Clang toolchain (via official installer)
RUN set -eux; \
    curl -fsSL https://apt.llvm.org/llvm.sh -o /tmp/llvm.sh; \
    chmod +x /tmp/llvm.sh; \
    /tmp/llvm.sh ${LLVM_VERSION} all; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libmlir-${LLVM_VERSION}-dev \
        mlir-${LLVM_VERSION}-tools \
        libbolt-${LLVM_VERSION}-dev \
        bolt-${LLVM_VERSION} \
        flang-${LLVM_VERSION} \
        libclc-${LLVM_VERSION}-dev \
        libunwind-${LLVM_VERSION}-dev \
        libllvmlibc-${LLVM_VERSION}-dev; \
    LC_ALL=C apt-cache search ${LLVM_VERSION} | sort > /opt/llvm-packages-${LLVM_VERSION}.txt; \
    rm /tmp/llvm.sh; \
    rm -rf /var/lib/apt/lists/*

# Ubuntu toolchain PPA for latest GCC
RUN set -eux; \
    add-apt-repository -y ppa:ubuntu-toolchain-r/test; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        gcc-${GCC_VERSION} \
        g++-${GCC_VERSION}; \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_VERSION} 20; \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-${GCC_VERSION} 20; \
    rm -rf /var/lib/apt/lists/*

# Kitware repository for latest CMake
RUN set -eux; \
    curl -fsSL https://apt.kitware.com/keys/kitware-archive-latest.asc | gpg --dearmor -o /usr/share/keyrings/kitware-archive.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/kitware-archive.gpg] https://apt.kitware.com/ubuntu/ noble main" > /etc/apt/sources.list.d/kitware.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends cmake; \
    rm -rf /var/lib/apt/lists/*

# Mold linker
RUN set -eux; \
    curl -fsSL "https://github.com/rui314/mold/releases/download/v${MOLD_VERSION}/${MOLD_ARCHIVE}" -o /tmp/mold.tar.gz; \
    tar -xzf /tmp/mold.tar.gz -C /opt; \
    MOLD_DIR=/opt/mold-${MOLD_VERSION}-x86_64-linux; \
    install -m 0755 ${MOLD_DIR}/bin/mold /usr/local/bin/mold; \
    install -m 0755 ${MOLD_DIR}/bin/ld.mold /usr/local/bin/ld.mold; \
    rm -rf /tmp/mold.tar.gz ${MOLD_DIR}

# GitHub CLI
RUN set -eux; \
    curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_CLI_VERSION}/gh_${GH_CLI_VERSION}_linux_amd64.tar.gz" -o /tmp/gh.tar.gz; \
    tar -xzf /tmp/gh.tar.gz -C /tmp; \
    install -m 0755 /tmp/gh_${GH_CLI_VERSION}_linux_amd64/bin/gh /usr/local/bin/gh; \
    rm -rf /tmp/gh.tar.gz /tmp/gh_${GH_CLI_VERSION}_linux_amd64

# GNU Make (latest release)
RUN set -eux; \
    curl -fsSL "https://ftp.gnu.org/gnu/make/make-${MAKE_VERSION}.tar.gz" -o /tmp/make.tar.gz; \
    tar -xzf /tmp/make.tar.gz -C /tmp; \
    cd /tmp/make-${MAKE_VERSION}; \
    ./configure --prefix=/usr/local; \
    make -j"$(nproc)"; \
    make install; \
    rm -rf /tmp/make.tar.gz /tmp/make-${MAKE_VERSION}

# Linux perf tooling
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends linux-tools-common linux-tools-generic; \
    KERNEL="$(uname -r)"; \
    apt-get install -y --no-install-recommends "linux-tools-${KERNEL}" || true; \
    rm -rf /var/lib/apt/lists/*

# ccache (prebuilt binary)
RUN set -eux; \
    curl -fsSL "https://github.com/ccache/ccache/releases/download/v${CCACHE_VERSION}/${CCACHE_ARCHIVE}" -o /tmp/ccache.tar.xz; \
    tar -xJf /tmp/ccache.tar.xz -C /tmp; \
    install -m 0755 /tmp/ccache-${CCACHE_VERSION}-linux-x86_64/ccache /usr/local/bin/ccache; \
    rm -rf /tmp/ccache.tar.xz /tmp/ccache-${CCACHE_VERSION}-linux-x86_64

# sccache
RUN set -eux; \
    curl -fsSL "https://github.com/mozilla/sccache/releases/download/v${SCCACHE_VERSION}/${SCCACHE_ARCHIVE}" -o /tmp/sccache.tar.gz; \
    tar -xzf /tmp/sccache.tar.gz -C /tmp; \
    install -m 0755 /tmp/sccache-v${SCCACHE_VERSION}-x86_64-unknown-linux-musl/sccache /usr/local/bin/sccache; \
    rm -rf /tmp/sccache.tar.gz /tmp/sccache-v${SCCACHE_VERSION}-x86_64-unknown-linux-musl

# ripgrep
RUN set -eux; \
    curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/${RIPGREP_ARCHIVE}" -o /tmp/rg.tar.gz; \
    tar -xzf /tmp/rg.tar.gz -C /tmp; \
    install -m 0755 /tmp/ripgrep-${RIPGREP_VERSION}-x86_64-unknown-linux-musl/rg /usr/local/bin/rg; \
    rm -rf /tmp/rg.tar.gz /tmp/ripgrep-${RIPGREP_VERSION}-x86_64-unknown-linux-musl

# binutils + gdb (latest release)
RUN set -eux; \
    curl -fsSL "https://github.com/bminor/binutils-gdb/archive/refs/tags/${BINUTILS_GDB_TAG}.tar.gz" -o /tmp/binutils-gdb.tar.gz; \
    mkdir -p /tmp/binutils-gdb; \
    tar -xzf /tmp/binutils-gdb.tar.gz -C /tmp/binutils-gdb --strip-components=1; \
    mkdir -p /tmp/binutils-gdb/build; \
    cd /tmp/binutils-gdb/build; \
    ../configure --disable-multilib --enable-gold --enable-plugins --with-system-zlib; \
    make -j"$(nproc)"; \
    make install; \
    rm -rf /tmp/binutils-gdb.tar.gz /tmp/binutils-gdb

# Python developer utilities (uv, ruff, ty)
RUN set -eux; \
    curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh; \
    curl -LsSf https://astral.sh/ruff/install.sh | RUFF_INSTALL_DIR=/usr/local/bin sh; \
    curl -LsSf https://astral.sh/ty/install.sh | TY_INSTALL_DIR=/usr/local/bin sh

# Pixi package manager
RUN set -eux; \
    curl -fsSL https://pixi.sh/install.sh | bash -s -- -y; \
    mv /root/.pixi/bin/pixi /usr/local/bin/pixi; \
    rm -rf /root/.pixi

# Include-What-You-Use (built from source to match LLVM ${LLVM_VERSION})
RUN set -eux; \
    git clone https://github.com/include-what-you-use/include-what-you-use.git /tmp/iwyu; \
    cd /tmp/iwyu; \
    git checkout ${IWYU_COMMIT}; \
    cmake -S . -B build -G Ninja -DIWYU_LLVM_ROOT_PATH=/usr/lib/llvm-${LLVM_VERSION}; \
    cmake --build build; \
    install -m 0755 build/bin/include-what-you-use /usr/local/bin/include-what-you-use; \
    rm -rf /tmp/iwyu

# MRDocs release binary
RUN curl -fsSL "https://github.com/cppalliance/mrdocs/releases/download/${MRDOCS_VERSION}/${MRDOCS_ARCHIVE}" -o /tmp/mrdocs.tar.xz && \
    tar -xJf /tmp/mrdocs.tar.xz -C /opt && \
    mv /opt/${MRDOCS_DIR} /opt/mrdocs && \
    ln -s /opt/mrdocs/bin/mrdocs /usr/local/bin/mrdocs && \
    rm /tmp/mrdocs.tar.xz

# Mermaid CLI for architecture diagrams
RUN npm install -g @mermaid-js/mermaid-cli

# Bootstrap vcpkg and keep ownership consistent for dev user
RUN git clone https://github.com/microsoft/vcpkg.git ${VCPKG_ROOT} && \
    mkdir -p ${VCPKG_DOWNLOADS} && \
    ${VCPKG_ROOT}/bootstrap-vcpkg.sh -disableMetrics && \
    ln -s ${VCPKG_ROOT}/vcpkg /usr/local/bin/vcpkg

# Create non-root user for IDE/devcontainer usage
RUN if ! getent group ${USERNAME} >/dev/null; then \
        if getent group ${USER_GID} >/dev/null; then \
            groupadd --non-unique --gid ${USER_GID} ${USERNAME}; \
        else \
            groupadd --gid ${USER_GID} ${USERNAME}; \
        fi; \
    fi && \
    if ! id -u ${USERNAME} >/dev/null 2>&1; then \
        useradd --non-unique --uid ${USER_UID} --gid ${USERNAME} --shell /bin/bash --create-home ${USERNAME}; \
    fi && \
    usermod -aG sudo ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-${USERNAME} && \
    chmod 0440 /etc/sudoers.d/99-${USERNAME} && \
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME} && \
    chmod 0750 /home/${USERNAME} && \
    install -d -m 700 -o ${USERNAME} -g ${USERNAME} /home/${USERNAME}/.ssh

# Prepare shared directories for vcpkg, cmake, and caches
RUN mkdir -p /workspaces /var/cache/ccache /var/cache/sccache && \
    chown -R ${USERNAME}:${USERNAME} /workspaces /var/cache/ccache /var/cache/sccache ${VCPKG_ROOT} ${VCPKG_DOWNLOADS}

# Enable vcpkg shell integration for the dev user (bash/zsh)
RUN su - ${USERNAME} -c "${VCPKG_ROOT}/vcpkg integrate bash" && \
    su - ${USERNAME} -c "${VCPKG_ROOT}/vcpkg integrate zsh" || true

USER ${USERNAME}
WORKDIR /workspaces/SlotMap

ENV CC=clang-21 \
    CXX=clang++-21 \
    CMAKE_GENERATOR=Ninja \
    PATH="${VCPKG_ROOT}:${PATH}"

CMD ["sleep", "infinity"]
# cppcheck (latest)
ARG CPPCHECK_VERSION=2.13.0
RUN set -eux; \
    curl -fsSL "https://github.com/danmar/cppcheck/archive/refs/tags/${CPPCHECK_VERSION}.tar.gz" -o /tmp/cppcheck.tar.gz; \
    tar -xzf /tmp/cppcheck.tar.gz -C /tmp; \
    cd /tmp/cppcheck-${CPPCHECK_VERSION}; \
    mkdir build && cd build; \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local; \
    cmake --build . -j"$(nproc)"; \
    cmake --install .; \
    rm -rf /tmp/cppcheck.tar.gz /tmp/cppcheck-${CPPCHECK_VERSION}

# Valgrind (latest)
ARG VALGRIND_VERSION=3.23.0
RUN set -eux; \
    curl -fsSL "https://sourceware.org/pub/valgrind/valgrind-${VALGRIND_VERSION}.tar.bz2" -o /tmp/valgrind.tar.bz2; \
    tar -xjf /tmp/valgrind.tar.bz2 -C /tmp; \
    cd /tmp/valgrind-${VALGRIND_VERSION}; \
    ./configure --prefix=/usr/local; \
    make -j"$(nproc)"; \
    make install; \
    rm -rf /tmp/valgrind.tar.bz2 /tmp/valgrind-${VALGRIND_VERSION}
