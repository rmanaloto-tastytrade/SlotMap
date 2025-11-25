find_package(benchmark CONFIG REQUIRED)

# Google Benchmark-based benchmarks
add_executable(slotmap_benchmarks bench_slotmap.cpp)
target_link_libraries(slotmap_benchmarks
    PRIVATE
        slotmap
        benchmark::benchmark
        benchmark::benchmark_main
)
target_compile_features(slotmap_benchmarks PRIVATE cxx_std_23)

# Simple chrono-based profiling (no external dependencies)
add_executable(slotmap_perf perf_slotmap.cpp)
target_link_libraries(slotmap_perf
    PRIVATE
        slotmap
)
target_compile_features(slotmap_perf PRIVATE cxx_std_23)

# Note: qlibs/perf is available in vcpkg for advanced profiling with Linux perf counters.
# To use it, add: find_package(qlibs-perf CONFIG REQUIRED) and link qlibs::perf
# Requires Linux with perf_event_open support for full functionality.
