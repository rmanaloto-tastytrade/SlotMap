FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=slotmap
ARG USER_UID=1000
ARG USER_GID=1000
ARG VCPKG_ROOT=/opt/vcpkg

ENV TZ=UTC \
    VCPKG_ROOT=${VCPKG_ROOT} \
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
        build-essential \
        ninja-build \
        cmake \
        unzip \
        zip \
        tar \
        python3 \
        python3-pip \
        python3-venv \
        rsync \
        tzdata \
        graphviz \
        doxygen \
        nodejs \
        npm \
        mold \
        openssh-client; \
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
        libc++-21-dev \
        libc++abi-21-dev; \
    rm -rf /var/lib/apt/lists/*

# Python tooling for documentation + MRDocs (isolated venv)
RUN python3 -m venv /opt/mrdocs-venv && \
    /opt/mrdocs-venv/bin/pip install --upgrade pip && \
    /opt/mrdocs-venv/bin/pip install "mrdocs~=0.3" && \
    ln -s /opt/mrdocs-venv/bin/mrdocs /usr/local/bin/mrdocs

# Mermaid CLI for architecture diagrams
RUN npm install -g @mermaid-js/mermaid-cli

# Bootstrap vcpkg and keep ownership consistent for dev user
RUN git clone https://github.com/microsoft/vcpkg.git ${VCPKG_ROOT} && \
    ${VCPKG_ROOT}/bootstrap-vcpkg.sh -disableMetrics && \
    ln -s ${VCPKG_ROOT}/vcpkg /usr/local/bin/vcpkg

# Create non-root user for IDE/devcontainer usage
RUN groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd --uid ${USER_UID} --gid ${USER_GID} --shell /bin/bash --create-home ${USERNAME} && \
    usermod -aG sudo ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-${USERNAME} && \
    chmod 0440 /etc/sudoers.d/99-${USERNAME}

# Prepare shared directories for vcpkg, cmake, and caches
RUN mkdir -p /workspaces /var/cache/ccache && \
    chown -R ${USERNAME}:${USERNAME} /workspaces /var/cache/ccache ${VCPKG_ROOT}

USER ${USERNAME}
WORKDIR /workspaces/SlotMap

ENV CC=clang-21 \
    CXX=clang++-21 \
    CMAKE_GENERATOR=Ninja \
    PATH="${VCPKG_ROOT}:${PATH}"

CMD ["/bin/bash"]
