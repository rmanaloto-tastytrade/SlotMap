FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=slotmap
ARG USER_UID=1000
ARG USER_GID=1000
ARG VCPKG_ROOT=/opt/vcpkg
ARG VCPKG_DOWNLOADS=/opt/vcpkg-downloads
ARG MRDOCS_VERSION=v0.8.0
ARG MRDOCS_ARCHIVE=MrDocs-0.8.0-Linux.tar.xz
ARG MRDOCS_DIR=MrDocs-0.8.0-Linux
ARG NINJA_VERSION=1.13.1
ARG MOLD_VERSION=2.40.4
ARG MOLD_ARCHIVE=mold-${MOLD_VERSION}-x86_64-linux.tar.gz
ARG GH_CLI_VERSION=2.83.1
ARG IWYU_COMMIT=clang_21
ARG GCC_VERSION=14

ENV TZ=UTC \
    VCPKG_ROOT=${VCPKG_ROOT} \
    VCPKG_DOWNLOADS=${VCPKG_DOWNLOADS} \
    VCPKG_FORCE_SYSTEM_BINARIES=1 \
    LLVM_VERSION=21

# Core OS packages, tooling, and dependencies required for building and docs
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        git \
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
        nodejs \
        npm \
        openssh-client \
        zsh \
        cppcheck \
        valgrind \
        gdb \
        autoconf \
        automake \
        libtool \
        m4 \
        autoconf-archive; \
    rm -rf /var/lib/apt/lists/*

# LLVM/Clang 21 repository and toolchain
RUN set -eux; \
    curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor -o /usr/share/keyrings/llvm.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/llvm.gpg] http://apt.llvm.org/noble/ llvm-toolchain-noble-21 main" > /etc/apt/sources.list.d/llvm-toolchain.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        clang-21 \
        clang++-21 \
        clang-tidy-21 \
        clang-format-21 \
        lld-21 \
        lldb-21 \
        llvm-21 \
        llvm-21-dev \
        libclang-21-dev \
        libc++-21-dev \
        libc++abi-21-dev; \
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

# Ninja (latest GitHub release)
RUN set -eux; \
    curl -fsSL "https://github.com/ninja-build/ninja/releases/download/v${NINJA_VERSION}/ninja-linux.zip" -o /tmp/ninja.zip; \
    unzip -d /tmp /tmp/ninja.zip; \
    install -m 0755 /tmp/ninja /usr/local/bin/ninja; \
    rm -rf /tmp/ninja /tmp/ninja.zip

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
RUN mkdir -p /workspaces /var/cache/ccache && \
    chown -R ${USERNAME}:${USERNAME} /workspaces /var/cache/ccache ${VCPKG_ROOT} ${VCPKG_DOWNLOADS}

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
