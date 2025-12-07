# Lookup Policy

- Receives a handle and storage view, returns `outcome::result<slot_view>` or `std::expected`.  
- Policy defines SIMD usage, parallel prefetching, and error reporting (invalid handle, recycled handle, slot tombstone).  
- Default implementation performs generation checks followed by contiguous array lookup.  
- Every change must be reflected in diagrams (handle lifecycle) and shared helpers belong to `include/slotmap/LookupPolicy.hpp` (TBD).
