#include "audiocollector.hpp"

#include <qcoreapplication.h>

#include <algorithm>
#include <array>
#include <atomic>
#include <barrier>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <stdexcept>
#include <thread>

using caelestia::shell::services::AudioCollector;
using caelestia::shell::services::ac::k_chunkSize;

namespace {

void require(bool condition, const char* message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

void verify_chunks() {
    auto& collector = AudioCollector::instance();
    std::array<qint16, k_chunkSize + 8> samples;
    std::array<float, k_chunkSize + 1> float_samples;
    std::array<double, k_chunkSize + 1> double_samples;

    collector.clearBuffer();
    require(collector.readChunk(float_samples.data()) == k_chunkSize, "Default float read must return a complete chunk");
    require(std::ranges::all_of(float_samples.begin(), float_samples.begin() + k_chunkSize, [](float sample) { return std::abs(sample) < 0.000001f; }), "Cleared float chunk must contain silence");

    samples.fill(16384);
    samples[0] = -32768;
    samples[1] = -16384;
    samples[2] = 0;
    samples[3] = 32767;
    collector.loadChunk(samples.data(), 4);
    float_samples.fill(8.0f);
    double_samples.fill(8.0);
    require(collector.readChunk(float_samples.data(), 4) == 4, "Short float read must preserve its requested count");
    require(collector.readChunk(double_samples.data(), 4) == 4, "Short double read must preserve its requested count");
    const std::array<double, 4> expected = { -1.0, -0.5, 0.0, 0.999969482421875 };
    for (size_t i = 0; i < expected.size(); i++) {
        require(std::abs(static_cast<double>(float_samples[i]) - expected[i]) < 0.000001, "Float conversion must preserve signed PCM boundaries");
        require(std::abs(double_samples[i] - expected[i]) < 0.000001, "Double conversion must preserve signed PCM boundaries");
    }
    require(float_samples[4] > 7.0f && double_samples[4] > 7.0, "Short reads must not overwrite their destination tail");

    collector.loadChunk(samples.data(), k_chunkSize);
    require(collector.readChunk(float_samples.data(), k_chunkSize + 8) == k_chunkSize, "Oversized float read must be clamped");
    require(collector.readChunk(double_samples.data(), k_chunkSize + 8) == k_chunkSize, "Oversized double read must be clamped");
    require(float_samples[k_chunkSize] > 7.0f && double_samples[k_chunkSize] > 7.0, "Clamped reads must not overflow the chunk");
    require(std::abs(float_samples[k_chunkSize - 1] - 0.5f) < 0.000001f && std::abs(double_samples[k_chunkSize - 1] - 0.5) < 0.000001, "Full chunks must preserve their final sample");

    collector.readChunk(float_samples.data(), 4);
    collector.readChunk(double_samples.data(), 4);
    for (size_t i = 0; i < 4; i++) {
        require(std::abs(float_samples[i] - 0.5f) < 0.000001f, "Short float reads must return the newest samples");
        require(std::abs(double_samples[i] - 0.5) < 0.000001, "Short double reads must return the newest samples");
    }

    samples.fill(16384);
    collector.loadChunk(samples.data(), k_chunkSize);
    samples.fill(8192);
    collector.loadChunk(samples.data(), 3);
    require(collector.readChunk(float_samples.data(), 0) == k_chunkSize, "Zero float read count must request a complete chunk");
    require(collector.readChunk(double_samples.data(), 0) == k_chunkSize, "Zero double read count must request a complete chunk");
    for (size_t i = 0; i < k_chunkSize; i++) {
        require(std::abs(float_samples[i] - (i < k_chunkSize - 3 ? 0.5f : 0.25f)) < 0.000001f, "Partial float chunks must append to the rolling window");
        require(std::abs(double_samples[i] - (i < k_chunkSize - 3 ? 0.5 : 0.25)) < 0.000001, "Partial double chunks must append to the rolling window");
    }

    collector.loadChunk(samples.data(), 0);
    collector.readChunk(float_samples.data());
    collector.readChunk(double_samples.data());
    for (size_t i = 0; i < k_chunkSize; i++) {
        require(std::abs(float_samples[i] - (i < k_chunkSize - 3 ? 0.5f : 0.25f)) < 0.000001f, "Empty float writes must preserve the rolling window");
        require(std::abs(double_samples[i] - (i < k_chunkSize - 3 ? 0.5 : 0.25)) < 0.000001, "Empty double writes must preserve the rolling window");
    }

    collector.clearBuffer();
    collector.loadChunk(samples.data(), 3);
    collector.readChunk(float_samples.data());
    collector.readChunk(double_samples.data());
    for (size_t i = 0; i < k_chunkSize; i++) {
        require(std::abs(float_samples[i] - (i < k_chunkSize - 3 ? 0.0f : 0.25f)) < 0.000001f, "Float windows must pad missing history at the front after a clear");
        require(std::abs(double_samples[i] - (i < k_chunkSize - 3 ? 0.0 : 0.25)) < 0.000001, "Double windows must pad missing history at the front after a clear");
    }

    samples.fill(-16384);
    collector.loadChunk(samples.data(), static_cast<quint32>(samples.size()));
    collector.readChunk(float_samples.data());
    collector.readChunk(double_samples.data());
    require(std::ranges::all_of(float_samples.begin(), float_samples.begin() + k_chunkSize, [](float sample) { return std::abs(sample + 0.5f) < 0.000001f; }), "Oversized writes must preserve one complete float chunk");
    require(std::ranges::all_of(double_samples.begin(), double_samples.begin() + k_chunkSize, [](double sample) { return std::abs(sample + 0.5) < 0.000001; }), "Oversized writes must preserve one complete double chunk");
}

void verify_concurrent_snapshots() {
    auto& collector = AudioCollector::instance();
    collector.clearBuffer();
    std::barrier start_gate(4);
    std::atomic_bool snapshots_valid = true;
    std::jthread writer([&] {
        std::array<qint16, k_chunkSize> positive_samples;
        std::array<qint16, k_chunkSize> negative_samples;
        positive_samples.fill(16384);
        negative_samples.fill(-16384);
        start_gate.arrive_and_wait();
        for (int i = 0; i < 200000; i++) {
            collector.loadChunk(i % 2 ? positive_samples.data() : negative_samples.data(), k_chunkSize);
        }
    });
    std::jthread float_reader([&] {
        std::array<float, k_chunkSize> samples;
        start_gate.arrive_and_wait();
        for (int i = 0; i < 100000; i++) {
            collector.readChunk(samples.data());
            const auto [minimum, maximum] = std::ranges::minmax(samples);
            if (maximum > minimum) {
                snapshots_valid.store(false, std::memory_order_relaxed);
                break;
            }
        }
    });
    std::jthread double_reader([&] {
        std::array<double, k_chunkSize> samples;
        start_gate.arrive_and_wait();
        for (int i = 0; i < 100000; i++) {
            collector.readChunk(samples.data());
            const auto [minimum, maximum] = std::ranges::minmax(samples);
            if (maximum > minimum) {
                snapshots_valid.store(false, std::memory_order_relaxed);
                break;
            }
        }
    });
    std::jthread clearer([&] {
        start_gate.arrive_and_wait();
        for (int i = 0; i < 100000; i++) {
            collector.clearBuffer();
        }
    });
    writer.join();
    float_reader.join();
    double_reader.join();
    clearer.join();
    require(snapshots_valid.load(std::memory_order_relaxed), "Concurrent reads must observe complete, uniform chunks");
}

}

int main(int argc, char** argv) {
    const QCoreApplication application(argc, argv);
    try {
        if (argc > 1) {
            verify_concurrent_snapshots();
        }
        else {
            verify_chunks();
        }
    }
    catch (const std::exception& error) {
        fprintf(stderr, "%s\n", error.what());
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}
