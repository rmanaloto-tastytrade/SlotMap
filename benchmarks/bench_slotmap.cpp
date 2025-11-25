/*

**SlotMap Performance Benchmarks**

This file provides comprehensive performance measurements for the SlotMap container
using Google Benchmark and qlibs/perf for detailed profiling.

Benchmarks are organized into categories:
- Insertion: Single and bulk insert operations
- Lookup: Handle-based access patterns
- Iteration: Full container traversal
- Removal: Single and bulk erase operations
- Mixed workloads: Realistic usage patterns

*/

#include <benchmark/benchmark.h>

#include <cstdint>
#include <random>
#include <vector>

// Placeholder: Include actual SlotMap when implemented
// #include <slotmap/SlotMap.hpp>

namespace {

/*

**Baseline Measurements**

These benchmarks establish baseline performance for comparison with SlotMap.
They use std::vector as the baseline container.

*/

void BM_VectorInsert(benchmark::State& state) {
    const auto count = static_cast<std::size_t>(state.range(0));
    for (auto _ : state) {
        std::vector<std::uint64_t> vec;
        vec.reserve(count);
        for (std::size_t i = 0; i < count; ++i) {
            vec.push_back(i);
        }
        benchmark::DoNotOptimize(vec.data());
        benchmark::ClobberMemory();
    }
    state.SetItemsProcessed(
        static_cast<std::int64_t>(static_cast<std::size_t>(state.iterations()) * count));
}

BENCHMARK(BM_VectorInsert)
    ->RangeMultiplier(4)
    ->Range(64, 1 << 16)
    ->Unit(benchmark::kMicrosecond);

void BM_VectorRandomAccess(benchmark::State& state) {
    const auto count = static_cast<std::size_t>(state.range(0));

    std::vector<std::uint64_t> vec(count);
    for (std::size_t i = 0; i < count; ++i) {
        vec[i] = i;
    }

    std::mt19937_64 rng(42);
    std::uniform_int_distribution<std::size_t> dist(0, count - 1);

    std::vector<std::size_t> indices(count);
    for (std::size_t i = 0; i < count; ++i) {
        indices[i] = dist(rng);
    }

    for (auto _ : state) {
        std::uint64_t sum = 0;
        for (std::size_t idx : indices) {
            sum += vec[idx];
        }
        benchmark::DoNotOptimize(sum);
    }
    state.SetItemsProcessed(
        static_cast<std::int64_t>(static_cast<std::size_t>(state.iterations()) * count));
}

BENCHMARK(BM_VectorRandomAccess)
    ->RangeMultiplier(4)
    ->Range(64, 1 << 16)
    ->Unit(benchmark::kMicrosecond);

void BM_VectorIteration(benchmark::State& state) {
    const auto count = static_cast<std::size_t>(state.range(0));

    std::vector<std::uint64_t> vec(count);
    for (std::size_t i = 0; i < count; ++i) {
        vec[i] = i;
    }

    for (auto _ : state) {
        std::uint64_t sum = 0;
        for (const auto& val : vec) {
            sum += val;
        }
        benchmark::DoNotOptimize(sum);
    }
    state.SetItemsProcessed(
        static_cast<std::int64_t>(static_cast<std::size_t>(state.iterations()) * count));
    state.SetBytesProcessed(
        static_cast<std::int64_t>(static_cast<std::size_t>(state.iterations()) * count * sizeof(std::uint64_t)));
}

BENCHMARK(BM_VectorIteration)
    ->RangeMultiplier(4)
    ->Range(64, 1 << 16)
    ->Unit(benchmark::kMicrosecond);

/*

**SlotMap Benchmarks (Placeholder)**

These benchmarks will be enabled once the SlotMap implementation is complete.
They follow the same patterns as the baseline benchmarks above.

*/

#if 0  // Enable when SlotMap is implemented

void BM_SlotMapInsert(benchmark::State& state) {
    const auto count = static_cast<std::size_t>(state.range(0));
    for (auto _ : state) {
        slotmap::SlotMap<std::uint64_t> sm;
        sm.reserve(count);
        for (std::size_t i = 0; i < count; ++i) {
            auto handle = sm.insert(i);
            benchmark::DoNotOptimize(handle);
        }
        benchmark::ClobberMemory();
    }
    state.SetItemsProcessed(static_cast<std::int64_t>(state.iterations() * count));
}

BENCHMARK(BM_SlotMapInsert)
    ->RangeMultiplier(4)
    ->Range(64, 1 << 16)
    ->Unit(benchmark::kMicrosecond);

void BM_SlotMapLookup(benchmark::State& state) {
    const auto count = static_cast<std::size_t>(state.range(0));

    slotmap::SlotMap<std::uint64_t> sm;
    sm.reserve(count);
    std::vector<slotmap::Handle> handles(count);
    for (std::size_t i = 0; i < count; ++i) {
        handles[i] = sm.insert(i);
    }

    std::mt19937_64 rng(42);
    std::shuffle(handles.begin(), handles.end(), rng);

    for (auto _ : state) {
        std::uint64_t sum = 0;
        for (const auto& h : handles) {
            if (auto* val = sm.get(h)) {
                sum += *val;
            }
        }
        benchmark::DoNotOptimize(sum);
    }
    state.SetItemsProcessed(static_cast<std::int64_t>(state.iterations() * count));
}

BENCHMARK(BM_SlotMapLookup)
    ->RangeMultiplier(4)
    ->Range(64, 1 << 16)
    ->Unit(benchmark::kMicrosecond);

void BM_SlotMapIteration(benchmark::State& state) {
    const auto count = static_cast<std::size_t>(state.range(0));

    slotmap::SlotMap<std::uint64_t> sm;
    sm.reserve(count);
    for (std::size_t i = 0; i < count; ++i) {
        sm.insert(i);
    }

    for (auto _ : state) {
        std::uint64_t sum = 0;
        for (const auto& val : sm) {
            sum += val;
        }
        benchmark::DoNotOptimize(sum);
    }
    state.SetItemsProcessed(static_cast<std::int64_t>(state.iterations() * count));
}

BENCHMARK(BM_SlotMapIteration)
    ->RangeMultiplier(4)
    ->Range(64, 1 << 16)
    ->Unit(benchmark::kMicrosecond);

void BM_SlotMapRemove(benchmark::State& state) {
    const auto count = static_cast<std::size_t>(state.range(0));

    for (auto _ : state) {
        state.PauseTiming();
        slotmap::SlotMap<std::uint64_t> sm;
        sm.reserve(count);
        std::vector<slotmap::Handle> handles(count);
        for (std::size_t i = 0; i < count; ++i) {
            handles[i] = sm.insert(i);
        }
        std::mt19937_64 rng(42);
        std::shuffle(handles.begin(), handles.end(), rng);
        state.ResumeTiming();

        for (const auto& h : handles) {
            sm.erase(h);
        }
        benchmark::ClobberMemory();
    }
    state.SetItemsProcessed(static_cast<std::int64_t>(state.iterations() * count));
}

BENCHMARK(BM_SlotMapRemove)
    ->RangeMultiplier(4)
    ->Range(64, 1 << 16)
    ->Unit(benchmark::kMicrosecond);

/*

**Mixed Workload Benchmarks**

Simulate realistic usage patterns with mixed insert/lookup/remove operations.

*/

void BM_SlotMapMixedWorkload(benchmark::State& state) {
    const auto count = static_cast<std::size_t>(state.range(0));

    for (auto _ : state) {
        slotmap::SlotMap<std::uint64_t> sm;
        sm.reserve(count);
        std::vector<slotmap::Handle> handles;
        handles.reserve(count);

        std::mt19937_64 rng(42);
        std::uniform_int_distribution<int> op_dist(0, 99);

        std::size_t ops = 0;
        while (ops < count * 2) {
            int op = op_dist(rng);

            if (op < 50 || handles.empty()) {
                // 50% insert (or insert if no handles)
                handles.push_back(sm.insert(ops));
            } else if (op < 80) {
                // 30% lookup
                std::uniform_int_distribution<std::size_t> idx_dist(0, handles.size() - 1);
                auto* val = sm.get(handles[idx_dist(rng)]);
                benchmark::DoNotOptimize(val);
            } else {
                // 20% remove
                std::uniform_int_distribution<std::size_t> idx_dist(0, handles.size() - 1);
                auto idx = idx_dist(rng);
                sm.erase(handles[idx]);
                handles[idx] = handles.back();
                handles.pop_back();
            }
            ++ops;
        }
        benchmark::ClobberMemory();
    }
    state.SetItemsProcessed(static_cast<std::int64_t>(state.iterations() * count * 2));
}

BENCHMARK(BM_SlotMapMixedWorkload)
    ->RangeMultiplier(4)
    ->Range(64, 1 << 14)
    ->Unit(benchmark::kMicrosecond);

#endif  // SlotMap implementation placeholder

}  // namespace

BENCHMARK_MAIN();
