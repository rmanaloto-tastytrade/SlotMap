/*

**SlotMap Performance Profiling**

This file provides detailed performance profiling using std::chrono for timing.
Future versions will integrate qlibs/perf for hardware counter access.

Note: For full hardware performance counters, use the Google Benchmark-based
bench_slotmap.cpp which integrates better with standard tooling.

*/

#include <chrono>
#include <cstdint>
#include <iostream>
#include <random>
#include <vector>

// Placeholder: Include actual SlotMap when implemented
// #include <slotmap/SlotMap.hpp>

namespace {

/*

**Timing Utilities**

Simple RAII timer for measuring operation durations.

*/

class Timer {
public:
    void start() { start_ = std::chrono::high_resolution_clock::now(); }
    void stop() { stop_ = std::chrono::high_resolution_clock::now(); }

    [[nodiscard]] auto elapsed_ns() const {
        return std::chrono::duration_cast<std::chrono::nanoseconds>(stop_ - start_).count();
    }

    [[nodiscard]] auto elapsed_us() const {
        return std::chrono::duration_cast<std::chrono::microseconds>(stop_ - start_).count();
    }

    [[nodiscard]] auto elapsed_ms() const {
        return std::chrono::duration_cast<std::chrono::milliseconds>(stop_ - start_).count();
    }

private:
    std::chrono::high_resolution_clock::time_point start_{};
    std::chrono::high_resolution_clock::time_point stop_{};
};

template <typename T>
void do_not_optimize(T const& value) {
    asm volatile("" : : "r,m"(value) : "memory");
}

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
        Timer timer;

        std::vector<std::uint64_t> vec;
        vec.reserve(count);

        timer.start();
        for (std::size_t i = 0; i < count; ++i) {
            vec.push_back(i);
        }
        timer.stop();

        std::cout << "  Time: " << timer.elapsed_ns() << " ns\n";
        std::cout << "  Per element: " << timer.elapsed_ns() / static_cast<std::int64_t>(count) << " ns\n\n";
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
        Timer timer;

        timer.start();
        std::uint64_t sum = 0;
        for (std::size_t idx : indices) {
            sum += vec[idx];
        }
        timer.stop();

        do_not_optimize(sum);
        std::cout << "  Time: " << timer.elapsed_ns() << " ns\n";
        std::cout << "  Per access: " << timer.elapsed_ns() / static_cast<std::int64_t>(count) << " ns\n\n";
    }

    // Profile iteration
    {
        std::vector<std::uint64_t> vec(count);
        for (std::size_t i = 0; i < count; ++i) {
            vec[i] = i;
        }

        std::cout << "Vector iteration (" << count << " elements):\n";
        Timer timer;

        timer.start();
        std::uint64_t sum = 0;
        for (const auto& val : vec) {
            sum += val;
        }
        timer.stop();

        do_not_optimize(sum);
        std::cout << "  Time: " << timer.elapsed_ns() << " ns\n";
        std::cout << "  Per element: " << timer.elapsed_ns() / static_cast<std::int64_t>(count) << " ns\n";
        std::cout << "  Throughput: "
                  << (count * sizeof(std::uint64_t) * 1000) / static_cast<std::size_t>(timer.elapsed_ns())
                  << " MB/s\n\n";
    }
}

#if 0  // Enable when SlotMap is implemented

void profile_slotmap_operations() {
    constexpr std::size_t count = 10000;

    std::cout << "\n=== SlotMap Profiling ===\n\n";

    // Profile insertion
    {
        std::cout << "SlotMap insertion (" << count << " elements):\n";

        slotmap::SlotMap<std::uint64_t> sm;
        sm.reserve(count);

        Timer timer;

        timer.start();
        for (std::size_t i = 0; i < count; ++i) {
            auto handle = sm.insert(i);
            do_not_optimize(handle);
        }
        timer.stop();

        std::cout << "  Time: " << timer.elapsed_ns() << " ns\n";
        std::cout << "  Per element: " << timer.elapsed_ns() / static_cast<std::int64_t>(count) << " ns\n\n";
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
        Timer timer;

        timer.start();
        std::uint64_t sum = 0;
        for (const auto& h : handles) {
            if (auto* val = sm.get(h)) {
                sum += *val;
            }
        }
        timer.stop();

        do_not_optimize(sum);
        std::cout << "  Time: " << timer.elapsed_ns() << " ns\n";
        std::cout << "  Per access: " << timer.elapsed_ns() / static_cast<std::int64_t>(count) << " ns\n\n";
    }

    // Profile iteration (should be cache-friendly)
    {
        slotmap::SlotMap<std::uint64_t> sm;
        sm.reserve(count);
        for (std::size_t i = 0; i < count; ++i) {
            sm.insert(i);
        }

        std::cout << "SlotMap iteration (" << count << " elements):\n";
        Timer timer;

        timer.start();
        std::uint64_t sum = 0;
        for (const auto& val : sm) {
            sum += val;
        }
        timer.stop();

        do_not_optimize(sum);
        std::cout << "  Time: " << timer.elapsed_ns() << " ns\n";
        std::cout << "  Per element: " << timer.elapsed_ns() / static_cast<std::int64_t>(count) << " ns\n\n";
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
