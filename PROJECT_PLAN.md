# Project Plan

1. **Environment & Tooling (Current phase)**  
   - **Remote Docker bake + devcontainer matrix** – baked on `c24s1.ch2` (all permutations built and verified). On `c0903s4.ny5`, images are baked; `gcc14-clang21` container is up and validated via `scripts/run_local_devcontainer.sh` + `scripts/verify_devcontainer.sh --require-ssh` after fixing SSH key paths (`~/.ssh/tastytrade_key`). Remaining permutations on `c0903s4.ny5` still need run/verify.  
   - Clang branch mapping is centralized in `scripts/clang_branch_utils.sh` (stable→20, qualification→21, development→22) and flows through Dockerfile/bake/verify.  
   - Tooling installs live under `/usr/local` (clang via apt.llvm.org pockets, gcc from source with symlinks, p2996 staged under `/usr/local/clang-p2996`).  
   - **Mutagen sync planned (later)** – we will add a mutagen session to sync `config/env/*.env` and workspace files from macOS to the remote host/devcontainer to avoid ad-hoc scp. For now, env files are copied manually. See `docs/mutagen_sync.md` for the intended approach; implementation is deferred.  
   - Add/maintain workflow diagrams and ensure Dockerfile lint rules remain satisfied; keep package versions pinned once stable.  
   - Keep `docs/ai_devcontainer_workflow.md` and `docs/CURRENT_WORKFLOW.md` as the entry points for new agents.

2. **Policy & Concept Scaffolding**  
   - Formalize concepts in `include/slotmap/Concepts.hpp` for handles, slots, storage, and lookup.  
   - Provide default policies (growth, storage, lookup, instrumentation) backed by qlibs/stdx overlays.  
   - Document each policy in `docs/Policies/*.md` and illustrate flows in `docs/Diagrams/`.

3. **SlotMap Core Implementation**  
   - Implement handle generation, slot storage, and error propagation via `std::expected`/`boost::outcome::result`.  
   - Integrate Google Highway for SIMD-assisted scans where policy allows.  
   - Align `docs/Architecture/*.md` with real data-flow diagrams.

4. **Instrumentation & Logging**  
   - Wire Quill logging and policy-based tracing hooks.  
   - Introduce Intel CIB service registration for pluggable allocators/growth behaviors.

5. **Validation & Packaging**  
   - Expand gtest coverage, add sanitizers presets, and document release/deployment steps.  
   - Ensure `scripts/generate_docs.sh` artifacts feed CI/publishing.
