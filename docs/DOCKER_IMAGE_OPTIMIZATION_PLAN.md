# Docker Image Optimization Plan

## Executive Summary

This plan addresses reducing Docker image sizes while maintaining:
- Full LLVM/Clang tooling access
- docker-bake.hcl for all builds
- devcontainer.json for runtime configuration (user, ports, timezone, etc.)
- Quick rebuild capability when tool versions update

**Key Finding**: The base image has ~370 MB of unnecessary packages (GCC-13, LLVM-18 libs) and multiple layers that can be consolidated.

---

## Current State Analysis

### Images Identified (3 Total)

| Image | Size | Description |
|-------|------|-------------|
| `dev-base:local` | 4.6 GB | Base image with Ubuntu 24.04, LLVM-21, GCC-14, binutils/gdb |
| `devcontainer:local` | 8.48 GB | Full devcontainer with all tools merged |
| `vsc-slotmap-*-features:latest` | 8.49 GB | VS Code devcontainer with SSHD feature applied |

### Base Image Layer Analysis (dev-base:local)

| Layer | Size | Component | Optimization Opportunity |
|-------|------|-----------|-------------------------|
| LLVM/Clang 21 | 3.06 GB | Full LLVM toolchain via `llvm.sh all` | Keep - you want full tooling |
| Core OS packages | 791 MB | Ubuntu base + build-essential, etc. | Consolidate into single layer |
| binutils + gdb | 367 MB | Built from source | Strip debug symbols |
| GCC-14 | 189 MB | Ubuntu Toolchain PPA | **Remove GCC-13 (~160 MB)** |
| linux-tools | 35.7 MB | perf tools | Keep |
| Git | 26.2 MB | git-core PPA | Consolidate |
| CMake | 50.4 MB | Kitware APT repo | Consolidate |
| Ninja | 291 KB | GitHub release | Consolidate |
| Make | 2.9 MB | Built from source | Consolidate |

**Current Layer Count**: 10+ separate RUN commands = 10+ layers

### Unwanted Packages Found

| Package Group | Size | Why Present | Action |
|--------------|------|-------------|--------|
| GCC-13 (gcc-13, g++-13, libstdc++-13-dev, etc.) | ~160 MB | `build-essential` pulls default GCC | Explicitly remove after GCC-14 install |
| LLVM-18 libs (libllvm18, libclang-cpp18, libclang1-18) | ~212 MB | Doxygen dependency | Cannot remove without breaking doxygen |
| libflang-21-dev | 647 MB | `llvm.sh all` | Keep if you want full LLVM tooling |
| libmlir-21-dev | 494 MB | `llvm.sh all` | Keep if you want full LLVM tooling |

**Note on LLVM-18**: The `doxygen` package from Ubuntu 24.04 depends on `libclang-cpp18` which pulls in the LLVM-18 runtime libraries. This is an Ubuntu packaging decision and cannot be avoided without building doxygen from source.

### Tool Stages Analysis (Parallel builds)

| Stage | Size | Required? | Notes |
|-------|------|-----------|-------|
| clang_p2996 | 2.31 GB | Optional | **Move to separate variant** |
| awscli | 443 MB | Yes | Cloud deployments |
| python_tools | 142 MB | Yes | uv, ruff, ty |
| valgrind | 133 MB | Yes | Memory debugging |
| vcpkg | 134 MB | Yes | Package manager |
| cppcheck | 89 MB | Yes | Static analysis |
| pixi | 63 MB | Yes | Conda package manager |
| node_mermaid | 59 MB | Yes | Diagram generation |
| mrdocs | 55 MB | Yes | C++ docs |
| iwyu | 38 MB | Yes | Include analysis |
| gh_cli | 22 MB | Yes | GitHub integration |
| sccache | 21 MB | Yes | Distributed cache |
| ccache | 6.5 MB | Yes | Local cache |
| ripgrep | 3.8 MB | Yes | Fast search |
| jq | 2.3 MB | Yes | JSON processing |
| mold | 2.3 MB | Yes | Fast linker |

---

## Optimization Strategies

### Strategy 1: Consolidate Base Image Layers (Est. 100-200 MB savings)

**Problem**: Each `RUN` command creates a new layer. Cleanup in later layers doesn't reduce earlier layer sizes.

**Current** (10 separate RUN commands):
```dockerfile
RUN apt-get install ... core packages ...
RUN apt-get install ... linux-tools ...
RUN add-apt-repository ppa:ubuntu-toolchain-r/test && apt-get install gcc-14 ...
RUN add-apt-repository ppa:git-core/ppa && apt-get install git ...
RUN curl ... kitware ... && apt-get install cmake ...
RUN curl ... ninja ...
RUN ... make from source ...
RUN curl ... llvm.sh ... && apt-get install llvm packages ...
RUN ... binutils/gdb from source ...
```

**Proposed** (3 consolidated layers):
```dockerfile
# Layer 1: All APT packages in one layer with cleanup
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists \
    set -eux; \
    # Add all PPAs first
    add-apt-repository -y ppa:ubuntu-toolchain-r/test; \
    add-apt-repository -y ppa:git-core/ppa; \
    curl -fsSL https://apt.kitware.com/keys/kitware-archive-latest.asc | gpg --dearmor -o /usr/share/keyrings/kitware-archive.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/kitware-archive.gpg] https://apt.kitware.com/ubuntu/ noble main" > /etc/apt/sources.list.d/kitware.list; \
    # Install all APT packages
    apt-get update; \
    apt-get install -y --no-install-recommends \
        # Core packages
        ca-certificates curl wget sudo gnupg software-properties-common \
        pkg-config bash-completion build-essential unzip zip tar \
        python3 python3-pip python3-venv rsync tzdata xz-utils \
        graphviz doxygen openssh-client zsh flex bison texinfo \
        libgmp-dev libmpfr-dev libmpc-dev libexpat1-dev zlib1g-dev \
        autoconf automake libtool m4 autoconf-archive patchelf \
        # Linux perf
        linux-tools-common linux-tools-generic \
        # GCC-14 only
        gcc-${GCC_VERSION} g++-${GCC_VERSION} \
        # Git and CMake
        git cmake; \
    # Remove GCC-13 that build-essential pulled in
    apt-get remove -y gcc-13 g++-13 cpp-13 || true; \
    apt-get autoremove -y; \
    # Set up alternatives
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_VERSION} 20; \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-${GCC_VERSION} 20; \
    # Cleanup
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /root/.cache

# Layer 2: LLVM (largest, kept separate for caching)
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists \
    set -eux; \
    curl -fsSL https://apt.llvm.org/llvm.sh -o /tmp/llvm.sh; \
    chmod +x /tmp/llvm.sh; \
    /tmp/llvm.sh ${LLVM_VERSION} all; \
    rm /tmp/llvm.sh; \
    rm -rf /var/lib/apt/lists/*

# Layer 3: Source builds (Ninja, Make, binutils/gdb) with stripping
RUN set -eux; \
    # Ninja
    curl -fSL "https://github.com/ninja-build/ninja/releases/download/v${NINJA_VERSION}/ninja-linux.zip" -o /tmp/ninja.zip; \
    unzip -d /tmp /tmp/ninja.zip; \
    install -m 0755 /tmp/ninja /usr/local/bin/ninja; \
    # Make
    curl -fsSL "https://mirrors.kernel.org/gnu/make/make-${MAKE_VERSION}.tar.gz" -o /tmp/make.tar.gz; \
    tar -xzf /tmp/make.tar.gz -C /tmp; \
    cd /tmp/make-${MAKE_VERSION} && ./configure --prefix=/usr/local && make -j"$(nproc)" && make install; \
    # binutils/gdb
    curl -fsSL "https://github.com/bminor/binutils-gdb/archive/refs/tags/${BINUTILS_GDB_TAG}.tar.gz" -o /tmp/binutils-gdb.tar.gz; \
    mkdir -p /tmp/binutils-gdb; \
    tar -xzf /tmp/binutils-gdb.tar.gz -C /tmp/binutils-gdb --strip-components=1; \
    mkdir -p /tmp/binutils-gdb/build && cd /tmp/binutils-gdb/build; \
    ../configure --disable-multilib --enable-gold --enable-plugins --with-system-zlib; \
    make -j"$(nproc)" && make install; \
    # Strip debug symbols from binutils (saves ~50-100 MB)
    find /usr/local -type f -name '*.a' -exec strip --strip-debug {} \; 2>/dev/null || true; \
    find /usr/local -type f -executable -exec strip --strip-unneeded {} \; 2>/dev/null || true; \
    # Cleanup
    rm -rf /tmp/*
```

**Benefits**:
- Fewer layers = smaller image (layer overhead)
- Cleanup happens in same layer as install
- GCC-13 removed before layer finishes
- Debug symbols stripped

### Strategy 2: Remove GCC-13 Packages (Est. 160 MB savings)

**Problem**: `build-essential` pulls in the default GCC (13 on Ubuntu 24.04), even though we only want GCC-14.

**Solution**: Explicitly remove after installing GCC-14:
```dockerfile
apt-get remove -y gcc-13 g++-13 cpp-13 gcc-13-x86-64-linux-gnu g++-13-x86-64-linux-gnu \
    cpp-13-x86-64-linux-gnu libstdc++-13-dev libgcc-13-dev || true
apt-get autoremove -y
```

**Packages to remove** (~160 MB total):
- gcc-13, g++-13, cpp-13
- gcc-13-x86-64-linux-gnu, g++-13-x86-64-linux-gnu, cpp-13-x86-64-linux-gnu
- libstdc++-13-dev, libgcc-13-dev

### Strategy 3: Split P2996 into Separate Image Variant (Est. 2.3 GB for slim variant)

**Rationale**: clang-p2996 is 2.31 GB and only needed for experimental C++26 reflection work.

**Proposal**: Create two devcontainer variants:
1. `devcontainer:local` - Standard LLVM-21 from apt.llvm.org (~6.2 GB)
2. `devcontainer-p2996:local` - Includes Bloomberg's P2996 fork (~8.5 GB)

**docker-bake.hcl changes**:
```hcl
# Standard devcontainer (no P2996)
target "devcontainer" {
  inherits  = ["_base"]
  target    = "devcontainer"
  tags      = ["devcontainer:local"]
}

# P2996 variant
target "devcontainer_p2996" {
  inherits  = ["_base"]
  target    = "devcontainer_p2996"
  tags      = ["devcontainer-p2996:local"]
}

group "default" {
  targets = ["devcontainer"]  # Default to slim
}

group "all" {
  targets = ["devcontainer", "devcontainer_p2996"]
}
```

**Dockerfile changes**:
```dockerfile
# tools_merge stage without P2996
FROM prebuilt_base AS tools_merge
COPY --from=node_mermaid /opt/stage/ /
COPY --from=mold /opt/stage/ /
# ... all other tools EXCEPT clang_p2996 ...

# Standard devcontainer
FROM tools_merge AS devcontainer
# ... user setup ...

# P2996 variant (inherits everything, adds P2996)
FROM devcontainer AS devcontainer_p2996
COPY --from=clang_p2996 /opt/stage/ /
```

### Strategy 4: Strip Debug Symbols (Est. 50-100 MB savings)

**Apply to**:
1. binutils/gdb build (~50 MB)
2. clang-p2996 build (~200-300 MB if built with debug)

```dockerfile
# After binutils/gdb install
find /usr/local -type f -name '*.a' -exec strip --strip-debug {} \; 2>/dev/null || true
find /usr/local -type f -executable -exec strip --strip-unneeded {} \; 2>/dev/null || true

# For clang-p2996, use MinSizeRel and strip
cmake -DCMAKE_BUILD_TYPE=MinSizeRel ...
# After install:
find "${STAGE_PREFIX}" -type f -executable -exec strip --strip-unneeded {} \; 2>/dev/null || true
```

---

## Timezone Configuration

### Current State
- `TZ=UTC` is set via `ENV` in Dockerfile
- `/etc/timezone` contains `Etc/UTC`
- `tzdata` package is installed

### Runtime Override (Recommended)
Timezone can be changed at container runtime without rebuilding:

**Option 1: Environment Variable (Simplest)**
```json
// devcontainer.json
{
  "containerEnv": {
    "TZ": "${localEnv:TZ:-UTC}"
  }
}
```

This automatically uses the user's local timezone if set, defaulting to UTC.

**Option 2: Docker run flag**
```bash
docker run -e TZ=America/New_York ...
```

**Option 3: Volume mount (for apps that read /etc/localtime)**
```json
// devcontainer.json
{
  "mounts": [
    "source=/etc/localtime,target=/etc/localtime,type=bind,readonly"
  ]
}
```

### Recommendation
Add to devcontainer.json:
```json
{
  "containerEnv": {
    "TZ": "${localEnv:TZ:-UTC}"
  }
}
```

This:
- Defaults to UTC (good for consistent timestamps in logs/builds)
- Automatically uses user's timezone if they have `TZ` set locally
- No image rebuild needed when timezone changes

---

## Version Monitoring Workflow

### Script: `scripts/check_tool_versions.sh`

The script checks GitHub releases and compares against current versions in docker-bake.hcl.

**Integration into workflow**:

1. **Manual check**: Run before starting work on Docker images
   ```bash
   ./scripts/check_tool_versions.sh
   ```

2. **CI/CD integration**: Add to weekly scheduled workflow
   ```yaml
   # .github/workflows/check-tool-versions.yml
   name: Check Tool Versions
   on:
     schedule:
       - cron: '0 9 * * 1'  # Every Monday at 9 AM UTC
     workflow_dispatch:

   jobs:
     check-versions:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - name: Check tool versions
           run: ./scripts/check_tool_versions.sh
         - name: Create issue if updates available
           if: failure()
           uses: actions/github-script@v7
           with:
             script: |
               github.rest.issues.create({
                 owner: context.repo.owner,
                 repo: context.repo.repo,
                 title: 'DevContainer tool updates available',
                 body: 'Run `./scripts/check_tool_versions.sh` for details.'
               })
   ```

3. **JSON output for automation**:
   ```bash
   ./scripts/check_tool_versions.sh --json > tool-versions.json
   ```

---

## Implementation Plan

### Phase 1: Quick Wins (Est. 300-400 MB savings)

| Task | Est. Savings | Effort |
|------|-------------|--------|
| Remove GCC-13 packages | 160 MB | Low |
| Strip binutils/gdb debug symbols | 50-100 MB | Low |
| Consolidate APT layers | 50-100 MB | Medium |

**Implementation**:
1. Modify Dockerfile base stage to consolidate RUN commands
2. Add explicit `apt-get remove gcc-13 g++-13 ...`
3. Add `strip` commands after binutils/gdb build
4. Test with `docker buildx bake base`

### Phase 2: Architecture Changes (Est. 2.3 GB for slim variant)

| Task | Impact | Effort |
|------|--------|--------|
| Split P2996 into variant | 2.3 GB smaller default | Medium |
| Add timezone env var | User convenience | Low |
| Add version check workflow | Maintenance | Low |

**Implementation**:
1. Create `devcontainer_p2996` target in docker-bake.hcl
2. Add `tools_merge_slim` stage without P2996
3. Update devcontainer.json with TZ env var
4. Add GitHub workflow for version monitoring

### Phase 3: Ongoing Maintenance

| Task | Frequency |
|------|-----------|
| Run version check script | Weekly |
| Update docker-bake.hcl versions | As needed |
| Rebuild base when LLVM updates | ~Monthly |
| Prune old images | Weekly |

---

## Expected Results

### Image Sizes After Optimization

| Image | Current | After Phase 1 | After Phase 2 |
|-------|---------|---------------|---------------|
| dev-base:local | 4.6 GB | 4.3 GB | 4.3 GB |
| devcontainer:local | 8.48 GB | 8.1 GB | **6.2 GB** (no P2996) |
| devcontainer-p2996:local | N/A | N/A | 8.5 GB |

### Build Time Impact
- Layer consolidation: Slightly longer initial build, faster rebuilds due to better caching
- P2996 split: No change (still parallel build)
- Version checks: No build time impact (separate workflow)

---

## Summary of Recommendations

1. **Consolidate Dockerfile layers** - Fewer RUN commands = smaller image
2. **Remove GCC-13** - Save ~160 MB by cleaning up unwanted packages
3. **Strip debug symbols** - Save ~50-100 MB from binutils/gdb
4. **Split P2996** - Save 2.3 GB for standard workflows
5. **Add TZ env var** - Runtime timezone without rebuild
6. **Add version monitoring** - Know when to update tools
7. **Keep LLVM full** - You want all tooling, so keep `llvm.sh all`
8. **Accept LLVM-18 libs** - Required by doxygen, ~212 MB unavoidable

**Total Estimated Savings**:
- Phase 1: ~350 MB
- Phase 2: ~2.3 GB (slim variant)
