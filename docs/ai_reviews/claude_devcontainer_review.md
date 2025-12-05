# Claude Review: Devcontainer Toolchain Isolation

Prompt: Review Dockerfile/devcontainer.json/verify_devcontainer.sh for toolchain isolation (base generic gcc14-only; permutations only required toolchains; PATH/CC/CXX per permutation; full LLVM packages per variant; validation enforces exact compilers). List issues and fixes.

## Issues & Fixes (from Claude)
- Base installs gcc from PPA (gcc14) in base; base should be toolchain-agnostic. Move gcc installs to permutation stages.
- No separate permutation stages; all toolchains bleed into a single devcontainer target. Create explicit permutation targets that set CC/CXX/PATH and install only their toolchains.
- PATH not set per permutation (only minimal PATH); rely on permutation stages to prepend correct toolchain paths.
- CC/CXX not set; add per permutation or via post_create.
- LLVM apt install should be version-aware and may need optional packages gated; include full package set per variant.
- verify_devcontainer.sh overrides permutation-aware PATH expectations with hardcoded p2996/gcc15 entries; remove the duplicate assignment.
- ENABLE_GCC15 is set in base (bake) causing gcc15 bleed; set to 0 in base and only enable in gcc15 permutations.
- IWYU_COMMIT hardcoded to clang_21; should follow CLANG_VARIANT.
- IWYU build may use wrong LLVM_VERSION; ensure it matches the permutation.
- devcontainer.json lacks CC/CXX in containerEnv; optional to add.

Severity highlights:
- High: base bleeding toolchains; missing permutation stages; PATH/CC/CXX not per permutation; verify_devcontainer hardcoded PATH; ENABLE_GCC15 bleed.
- Medium: IWYU_COMMIT hardcoded; IWYU LLVM mismatch.
- Low: LLVM optional packages gating; containerEnv missing CC/CXX.
