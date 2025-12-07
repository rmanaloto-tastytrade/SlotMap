# Architecture Overview

The modern SlotMap is a header-only, policy-driven container. Key pillars:

1. **Handles** – 64-bit values composed of generation + slot index, validated via `std::expected`/`boost::outcome::result`.
2. **Policies** – Growth, storage, lookup, and instrumentation policies cooperate through C++ concepts (`include/slotmap/Concepts.hpp`).
3. **SIMD Acceleration** – Google Highway-backed primitives accelerate scans/compaction when policies opt in.
4. **Service Wiring** – Intel CIB-style registration provides allocator and monitoring singletons without global state.
5. **Error Handling** – No exceptions; APIs surface typed results only.

Detailed design docs will evolve alongside the policy implementations.
