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

### Direct Devcontainer SSH

The devcontainer now bakes in the official sshd feature and forwards port `9222`. Run the deployment helper with `--setup-ssh` once to copy your public key into the container, then connect directly:

```bash
ssh -p 9222 slotmap@<remote-host>
```

Replace `<remote-host>` with hosts such as `c24s1.ch2`. This bypasses the extra hop through the host shell while keeping the container running under the managed devcontainer workflow.
