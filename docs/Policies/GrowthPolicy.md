# Growth Policy

- Defines how capacity increases (`qlibs::default_allocator_policy` doubles capacity; alternatives may use fixed slabs).  
- Must expose `next_capacity(current)` returning `std::expected<std::size_t, growth_error>`.  
- Responsible for wiring allocator sources via Intel CIB services to prevent global singletons.  
- Document any policy-specific configuration knobs here and mirror diagrams under `docs/Diagrams/`.
