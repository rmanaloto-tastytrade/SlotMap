# SlotMap Modernization

This repository hosts the policy-driven rewrite of Sergey Makeev's SlotMap container using C++23/26, a clang-21 toolchain, mold, and vcpkg for dependency management.

## Developer Workflow

1. **Bootstrap dependencies**  
   Use the provided devcontainer (`.devcontainer/`) on any Ubuntu 24.04 host or bootstrap the toolchain manually with clang-21, gcc-14 (from the Ubuntu Toolchain PPA), cmake 3.28+, ninja, mold, vcpkg, Graphviz, Doxygen, MRDocs, IWYU, and the productivity tooling we bundle (ccache, sccache, ripgrep).

2. **Configure & build**
   ```bash
   cmake --preset clang-debug
   cmake --build --preset clang-debug
   ctest --preset clang-debug
   ```

### Available CMake Presets

All presets are available in both C++23 and C++26 variants (append `-cxx26` for C++26).

#### Build Configurations

| Preset | Description |
|--------|-------------|
| `clang-debug` | Debug build with full debug symbols |
| `clang-release` | Release build with ThinLTO optimization |
| `clang-release-full-lto` | Release build with full LTO (slower link, better optimization) |
| `clang-bolt-instrument` | Release build prepared for LLVM BOLT profiling |

#### Sanitizer Presets

| Preset | Description |
|--------|-------------|
| `clang-asan` | AddressSanitizer - detects memory errors |
| `clang-ubsan` | UndefinedBehaviorSanitizer - detects undefined behavior |
| `clang-tsan` | ThreadSanitizer - detects data races |
| `clang-lsan` | LeakSanitizer - detects memory leaks |
| `clang-asan-ubsan` | Combined ASan + UBSan |
| `clang-rtsan` | RealtimeSanitizer - detects real-time violations |
| `clang-scudo` | Scudo hardened allocator |
| `clang-cfi` | Control Flow Integrity |

> **Note on MSan:** The `clang-msan` (MemorySanitizer) preset exists but is **not recommended for regular use**. MSan requires all code—including dependencies—to be compiled with MSan instrumentation. Since vcpkg-installed libraries (like boost-ext/ut) are not MSan-instrumented, false positives will occur in third-party code. MSan is most useful when you can rebuild the entire dependency tree with instrumentation.

#### Static Analysis Presets

| Preset | Description |
|--------|-------------|
| `clang-tidy` | Build with clang-tidy static analysis enabled |
| `clang-iwyu` | Build with include-what-you-use checking |

#### Code Formatting

```bash
# Format all source files
cmake --build --preset clang-debug --target format

# Check formatting (CI-friendly, fails on violations)
cmake --build --preset clang-debug --target format-check
```

3. **Documentation**  
   Documentation (MRDocs + Doxygen + Mermaid) is generated via:
   ```bash
   cmake --build --preset clang-debug --target docs
   ```
   Artifacts will appear under `build/clang-debug/docs`.

4. **Dependencies & overlays**  
   `vcpkg.json` lists the required packages. Overlay ports under `vcpkg-overlays/` provide policy helpers (`qlibs`), stdx utilities, Intel CIB scaffolding, and a boost-ext outcome shim to guarantee deterministic builds.

5. **Policies & sources**  
   Policy headers live under `include/slotmap/`. When changing or adding policies, keep the accompanying documentation in `docs/Architecture/` and `docs/Policies/` synchronized and update diagrams in `docs/Diagrams/`.

### Remote Devcontainer Workflow

See `docs/remote-devcontainer.md` for the end-to-end diagram and detailed instructions. In short:
- Run `./scripts/deploy_remote_devcontainer.sh` from your laptop. It pushes the current branch, copies your `.pub` key to the remote cache, and triggers `run_local_devcontainer.sh` on the host.
- The remote script rebuilds the sandbox (`~/dev/devcontainers/SlotMap`), stages your keys under `.devcontainer/ssh/`, and runs `devcontainer up --remove-existing-container`.
- Container port `2222` is published as host `9222`, so you can connect directly with `ssh -i ~/.ssh/id_ed25519 -p 9222 <remote-username>@c0802s4.ny5` (the devcontainer user equals the remote host account) once the deploy finishes.

Troubleshooting tips, cleanup commands, and logging locations are captured in the doc so multiple developers can share the same remote workflow safely.

### Devcontainer Tooling Inventory

For a full list of packages and tools bundled by `.devcontainer/Dockerfile` (clang/LLVM, GCC, mold, MRDocs, vcpkg, ccache/sccache, ripgrep, etc.), see `docs/devcontainer-tools.md`. It mirrors the structure of the official devcontainers C++ image docs so you can quickly audit versions when planning upgrades.

### Devcontainer Build Automation Inspiration

We are aligning our container build steps with the [Beman Project infra-containers](https://github.com/bemanproject/infra-containers) model. Their `Dockerfile.devcontainer` and GitHub Actions workflow (`.github/workflows/devcontainer_ci.yml`) demonstrate how to matrix-build clang/gcc variants, push them to GHCR, and keep toolchains current via PPAs and Kitware mirrors. Future automation for SlotMap will follow a similar pattern (publish the devcontainer image after every main-branch update) so remote hosts can simply `docker pull` the latest image.
