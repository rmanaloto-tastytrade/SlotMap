# Memory Layout

- **Slot Pages** – Fixed-size arrays of slots sized for cache lines (64 bytes) with padding for Highway vector alignment.
- **Metadata** – Generations and free-list indices stored adjacent to values for predictable traversal without pointer chasing.
- **Growth Policy Hooks** – `qlibs::default_allocator_policy` drives block expansion (power-of-two growth) while enabling alternative allocators via Intel CIB services.
- **Fragmentation Control** – Compaction and tombstone recycling strategies live in StoragePolicy documentation; this file summarizes constraints that each policy must satisfy.
