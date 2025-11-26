# DevContainer Variant Options

This document describes the available approaches for selecting between the standard clang-21 (via llvm.sh) and the experimental clang-p2996 variant in devcontainers.

## Current Implementation: Option 3 (Runtime Selection)

The current implementation uses environment variables to select the compiler at container runtime. This keeps a single image with both compilers available.

### Usage

**Default (clang-21 via llvm.sh):**
```bash
# No environment variable needed - uses clang-21 by default
devcontainer up
```

**P2996 variant:**
```bash
# Set compiler paths before opening container
export DEVCONTAINER_CC=/opt/clang-p2996/bin/clang
export DEVCONTAINER_CXX=/opt/clang-p2996/bin/clang++
devcontainer up
```

Or add to your local `config/env/devcontainer.env`:
```bash
DEVCONTAINER_CC=/opt/clang-p2996/bin/clang
DEVCONTAINER_CXX=/opt/clang-p2996/bin/clang++
```

### How It Works

The `devcontainer.json` uses simple environment variable substitution:

```json
{
  "containerEnv": {
    "CC": "${localEnv:DEVCONTAINER_CC:-clang-21}",
    "CXX": "${localEnv:DEVCONTAINER_CXX:-clang++-21}"
  }
}
```

- When `DEVCONTAINER_CC/CXX` are unset: Uses `clang-21` and `clang++-21` from PATH (llvm.sh install)
- When set: Uses the specified compiler paths (e.g., `/opt/clang-p2996/bin/clang`)

---

## Alternative Options

### Option 1: Multiple devcontainer.json Files (Recommended for Future)

Create separate devcontainer configurations that VS Code/DevPod can list as options:

```
.devcontainer/
├── devcontainer.json              # Standard clang-21 (default)
├── p2996/
│   └── devcontainer.json          # P2996 variant
```

**Pros:**
- VS Code shows a picker when multiple configs exist
- Clear separation - user knows which variant they're using
- Aligns with Docker image optimization plan to split P2996 into separate image (~2.3 GB savings)
- No environment variable setup required

**Cons:**
- Requires building and maintaining two separate Docker images
- More disk space on the host (two images instead of one)

**Example p2996/devcontainer.json:**
```json
{
  "name": "SlotMap Dev (P2996)",
  "image": "devcontainer-p2996:local",
  "containerEnv": {
    "CC": "/opt/clang-p2996/bin/clang",
    "CXX": "/opt/clang-p2996/bin/clang++"
  }
}
```

### Option 2: Environment Variable Image Selection

Use `localEnv` to let the user choose the image at container creation:

```json
{
  "image": "${localEnv:DEVCONTAINER_IMAGE:-devcontainer:local}",
  "containerEnv": {
    "CC": "${localEnv:DEVCONTAINER_CC:-clang-21}",
    "CXX": "${localEnv:DEVCONTAINER_CXX:-clang++-21}"
  }
}
```

**Usage:**
```bash
export DEVCONTAINER_IMAGE=devcontainer-p2996:local
export DEVCONTAINER_CC=/opt/clang-p2996/bin/clang
export DEVCONTAINER_CXX=/opt/clang-p2996/bin/clang++
```

**Pros:**
- Maximum flexibility
- Can switch between any compiler configuration

**Cons:**
- Requires setting multiple environment variables
- Easy to misconfigure (e.g., wrong image with wrong compiler paths)
- More complex for users to understand

---

## Compiler Paths Reference

| Compiler | Path | Source |
|----------|------|--------|
| clang-21 | `/usr/bin/clang-21` | llvm.sh (apt.llvm.org) |
| clang++-21 | `/usr/bin/clang++-21` | llvm.sh (apt.llvm.org) |
| clang-p2996 | `/opt/clang-p2996/bin/clang` | Bloomberg P2996 branch |
| clang++-p2996 | `/opt/clang-p2996/bin/clang++` | Bloomberg P2996 branch |

## P2996 Features

The P2996 variant provides experimental C++ reflection support based on [P2996 proposal](https://wg21.link/P2996). Key features:

- `std::meta::info` - Reflection information type
- `^` operator - Reflection operator
- `[: :]` - Splice operator
- Compile-time introspection of types, functions, and namespaces

**Note:** P2996 is experimental and not part of the C++ standard yet. Use for experimentation only.

## Migration Path

When the Docker image optimization plan is implemented (see `docs/DOCKER_IMAGE_OPTIMIZATION_PLAN.md`), we recommend migrating to **Option 1** for these benefits:

1. **Smaller default image**: ~2.3 GB savings without P2996
2. **Faster pulls**: Most users don't need P2996
3. **Clear separation**: Explicit choice prevents accidental use of experimental compiler
4. **VS Code integration**: Native picker in VS Code Remote Containers

The migration would involve:
1. Building separate `devcontainer:local` and `devcontainer-p2996:local` images
2. Creating `.devcontainer/p2996/devcontainer.json`
3. Updating documentation and CI/CD workflows
