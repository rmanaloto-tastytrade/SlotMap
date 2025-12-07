# Storage Policy

- Owns slot buffers, freelists, and Highway-friendly metadata arrays.  
- Provides `allocate()`, `erase(handle)`, and iteration adapters returning policy-specific views.  
- Interacts with GrowthPolicy to request capacity increases through `std::expected`.  
- All state transitions must be reflected in `docs/Diagrams/storage-state.mmd` (to be added once implementation starts).
