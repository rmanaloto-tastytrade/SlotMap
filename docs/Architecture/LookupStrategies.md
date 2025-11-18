# Lookup Strategies

1. **Direct Index** – Default dense lookup for contiguous slot arrays with generation validation.
2. **Sparse Map** – Optional policy using open addressing for very large sparse key spaces.
3. **Tagged Handles** – Lookup policy can embed policy identifiers in the handle to route to alternative storage (useful for sharded SlotMaps).
4. **SIMD Validation** – Highway-enabled policies validate multiple handles per vector for batch `find` operations.
