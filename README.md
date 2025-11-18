# SlotMap Modernization

This repository hosts the policy-driven rewrite of Sergey Makeev's SlotMap container using C++23/26, a clang-21 toolchain, mold, and vcpkg for dependency management.

## Developer Workflow

1. **Bootstrap dependencies**  
   Use the provided devcontainer (`.devcontainer/`) on any Ubuntu 24.04 host or bootstrap the toolchain manually with clang-21, cmake 3.28+, ninja, mold, vcpkg, Graphviz, Doxygen, and MRDocs.

2. **Configure & build**  
   ```bash
   cmake --preset clang-debug
   cmake --build --preset clang-debug
   ctest --preset clang-debug
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

### Remote devcontainer helper

Use `scripts/deploy_remote_devcontainer.sh <ssh-host> [remote-path] [branch]` to push your current branch, sync it onto a remote Linux host, and rebuild/run the devcontainer automatically. Example:

```bash
scripts/deploy_remote_devcontainer.sh c24s1.ch2 ~/dev/github/SlotMap modernization.20251118
```

The helper ensures the branch is pushed to `origin`, enables Docker on the remote, clones/updates the repo at the given path, and restarts the `slotmap-dev` container with the correct bind mounts.
Each run emits a timestamped log under `logs/` so you can review full stdout/stderr later.
