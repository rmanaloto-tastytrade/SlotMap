/*

**SlotMap Performance Profiling with qlibs/perf**

This file provides detailed performance profiling using qlibs/perf, which offers:
- Hardware performance counters via linux/perf
- Cycle-accurate timing via rdtsc
- CPU cache statistics
- Branch prediction analysis

Note: Full perf counters require Linux with perf_event_open support.
Basic timing works on all platforms.

*/

#include <qlibs/perf>

#include <cstdint>
#include <iostream>
#include <random>
#include <vector>

// Placeholder: Include actual SlotMap when implemented
// #include <slotmap/SlotMap.hpp>

namespace {

/*

**Baseline Profiling**

Profile baseline operations to establish performance expectations.

*/

void profile_vector_operations() {
    constexpr std::size_t count = 10000;

    std::cout << "\n=== Vector Baseline Profiling ===\n\n";

    // Profile insertion
    {
        std::cout << "Vector insertion (" << count << " elements):\n";
        perf::timer timer;

        std::vector<std::uint64_t> vec;
        vec.reserve(count);

        timer.start();
        for (std::size_t i = 0; i < count; ++i) {
            vec.push_back(i);
        }
        timer.stop();

        std::cout << "  Time: " << timer.elapsed_ns() << " ns\n";
        std::cout << "  Per element: " << timer.elapsed_ns() / count << " ns\n\n";
    }

    // Profile random access
    {
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

        std::cout << "Vector random access (" << count << " lookups):\n";
        perf::timer timer;

        timer.start();
        std::uint64_t sum = 0;
        for (std::size_t idx : indices) {
            sum += vec[idx];
        }
        timer.stop();

        perf::donotoptimize(sum);
        std::cout << "  Time: " << timer.elapsed_ns() << " ns\n";
        std::cout << "  Per access: " << timer.elapsed_ns() / count << " ns\n\n";
    }

    // Profile iteration
    {
        std::vector<std::uint64_t> vec(count);
        for (std::size_t i = 0; i < count; ++i) {
            vec[i] = i;
        }

        std::cout << "Vector iteration (" << count << " elements):\n";
        perf::timer timer;

        timer.start();
        std::uint64_t sum = 0;
        for (const auto& val : vec) {
            sum += val;
        }
        timer.stop();

        perf::donotoptimize(sum);
        std::cout << "  Time: " << timer.elapsed_ns() << " ns\n";
        std::cout << "  Per element: " << timer.elapsed_ns() / count << " ns\n";
        std::cout << "  Throughput: "
                  << (count * sizeof(std::uint64_t) * 1000) / timer.elapsed_ns()
                  << " MB/s\n\n";
    }
}

#if 0  // Enable when SlotMap is implemented

void profile_slotmap_operations() {
    constexpr std::size_t count = 10000;

    std::cout << "\n=== SlotMap Profiling ===\n\n";

    // Profile insertion with perf counters
    {
        std::cout << "SlotMap insertion (" << count << " elements):\n";

        slotmap::SlotMap<std::uint64_t> sm;
        sm.reserve(count);

        perf::counter counter;  // Uses hardware performance counters if available

        counter.start();
        for (std::size_t i = 0; i < count; ++i) {
            auto handle = sm.insert(i);
            perf::donotoptimize(handle);
        }
        counter.stop();

        std::cout << "  Cycles: " << counter.cycles() << "\n";
        std::cout << "  Instructions: " << counter.instructions() << "\n";
        std::cout << "  IPC: " << counter.ipc() << "\n";
        std::cout << "  Cache misses: " << counter.cache_misses() << "\n";
        std::cout << "  Branch misses: " << counter.branch_misses() << "\n\n";
    }

    // Profile lookup patterns
    {
        slotmap::SlotMap<std::uint64_t> sm;
        sm.reserve(count);
        std::vector<slotmap::Handle> handles(count);
        for (std::size_t i = 0; i < count; ++i) {
            handles[i] = sm.insert(i);
        }

        // Shuffle for random access pattern
        std::mt19937_64 rng(42);
        std::shuffle(handles.begin(), handles.end(), rng);

        std::cout << "SlotMap random lookup (" << count << " accesses):\n";
        perf::counter counter;

        counter.start();
        std::uint64_t sum = 0;
        for (const auto& h : handles) {
            if (auto* val = sm.get(h)) {
                sum += *val;
            }
        }
        counter.stop();

        perf::donotoptimize(sum);
        std::cout << "  Cycles: " << counter.cycles() << "\n";
        std::cout << "  Instructions: " << counter.instructions() << "\n";
        std::cout << "  IPC: " << counter.ipc() << "\n";
        std::cout << "  Cache misses: " << counter.cache_misses() << "\n";
        std::cout << "  Branch misses: " << counter.branch_misses() << "\n\n";
    }

    // Profile iteration (should be cache-friendly)
    {
        slotmap::SlotMap<std::uint64_t> sm;
        sm.reserve(count);
        for (std::size_t i = 0; i < count; ++i) {
            sm.insert(i);
        }

        std::cout << "SlotMap iteration (" << count << " elements):\n";
        perf::counter counter;

        counter.start();
        std::uint64_t sum = 0;
        for (const auto& val : sm) {
            sum += val;
        }
        counter.stop();

        perf::donotoptimize(sum);
        std::cout << "  Cycles: " << counter.cycles() << "\n";
        std::cout << "  Instructions: " << counter.instructions() << "\n";
        std::cout << "  IPC: " << counter.ipc() << "\n";
        std::cout << "  Cache misses: " << counter.cache_misses() << "\n\n";
    }
}

#endif  // SlotMap implementation placeholder

}  // namespace

int main() {
    std::cout << "SlotMap Performance Profiling\n";
    std::cout << "==============================\n";

    profile_vector_operations();

#if 0  // Enable when SlotMap is implemented
    profile_slotmap_operations();
#endif

    std::cout << "\nNote: SlotMap benchmarks are disabled until implementation is complete.\n";
    std::cout << "Enable them by changing #if 0 to #if 1 in the source.\n";

    return 0;
}
