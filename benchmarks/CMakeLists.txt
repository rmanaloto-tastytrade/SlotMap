find_package(benchmark CONFIG REQUIRED)
find_package(qlibs-perf CONFIG REQUIRED)

# Google Benchmark-based benchmarks
add_executable(slotmap_benchmarks bench_slotmap.cpp)
target_link_libraries(slotmap_benchmarks
    PRIVATE
        slotmap
        benchmark::benchmark
        benchmark::benchmark_main
)
target_compile_features(slotmap_benchmarks PRIVATE cxx_std_23)

# qlibs/perf-based profiling
add_executable(slotmap_perf perf_slotmap.cpp)
target_link_libraries(slotmap_perf
    PRIVATE
        slotmap
        qlibs::perf
)
target_compile_features(slotmap_perf PRIVATE cxx_std_23)

# Optional: Link LLVM for MCA analysis features in qlibs/perf
# target_compile_definitions(slotmap_perf PRIVATE PERF_LLVM=1)
# target_link_libraries(slotmap_perf PRIVATE LLVM)
