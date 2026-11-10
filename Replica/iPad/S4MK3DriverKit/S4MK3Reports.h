#pragma once

#include <stddef.h>
#include <stdint.h>
#include <string.h>

namespace S4MK3 {
constexpr size_t kReportCapacity = 95;
constexpr size_t kBatchCapacity = 16;
constexpr uint8_t kProtocol = 1;
constexpr uint8_t kReset = 1;

struct Report {
    uint8_t length;
    uint8_t bytes[kReportCapacity];
};

struct Batch {
    uint8_t version;
    uint8_t flags;
    uint8_t count;
    uint8_t reserved;
    Report reports[kBatchCapacity];
};
static_assert(sizeof(Batch) == 1540);

inline bool validLight(const uint8_t* bytes, size_t count) {
    if (!bytes) return false;
    if (count == 95 && bytes[0] == 0x80) {
        for (size_t i = 1; i < count; i++) {
            if (bytes[i] > 127) return false;
        }
        return true;
    }
    if (count != 41 || bytes[0] != 0x32 || bytes[1] > 1 || (bytes[2] != 0 && bytes[2] != 5)) return false;
    for (size_t i = 3; i < 9; i++) {
        if (bytes[i] != 0) return false;
    }
    for (size_t i = 9; i < count; i++) {
        const uint8_t color = bytes[i];
        if (color && (bytes[2] == 0 || !((color >= 12 && color <= 15) || (color >= 44 && color <= 47)))) {
            return false;
        }
    }
    return true;
}

class ReportQueue {
    static constexpr size_t kButtons = 32;
    Report buttons[kButtons]{};
    Report latest[3]{};
    uint8_t head = 0;
    uint8_t count = 0;
    bool dirty[3]{};
    bool reset = false;
    uint8_t split[79]{};
    bool awaitingTail = false;
    uint64_t splitAt = 0;

    void store(const uint8_t* data, size_t length) {
        const unsigned index = data[0] - 1;
        Report& current = latest[index];
        if (current.length == length && memcmp(current.bytes, data, length) == 0) return;
        current = {};
        current.length = static_cast<uint8_t>(length);
        memcpy(current.bytes, data, length);
        if (index != 0) {
            dirty[index] = true;
        } else if (count == kButtons) {
            head = count = 0;
            reset = true;
        } else if (!reset) {
            buttons[(head + count) % kButtons] = current;
            count++;
        }
    }

public:
    void receive(const uint8_t* data, size_t length, uint64_t now) {
        if (!data || length == 0 || length > kReportCapacity) return;
        if (awaitingTail) {
            awaitingTail = false;
            if (length == 15 && now - splitAt <= 20'000'000) {
                memcpy(split + 64, data, length);
                store(split, sizeof(split));
                return;
            }
        }
        if (data[0] == 2 && length == 64) {
            memcpy(split, data, length);
            splitAt = now;
            awaitingTail = true;
        } else if ((data[0] == 1 && length >= 23) || (data[0] == 2 && length >= 79)
                   || (data[0] == 3 && length >= 44)) {
            store(data, length);
        }
    }

    void requestBaseline() {
        reset = true;
        head = count = 0;
    }

    void drain(Batch& batch) {
        batch = {};
        batch.version = kProtocol;
        if (reset) {
            batch.flags = kReset;
            for (const auto& report : latest) {
                if (report.length) batch.reports[batch.count++] = report;
            }
            dirty[1] = dirty[2] = reset = false;
            return;
        }
        while (count && batch.count < kBatchCapacity - 2) {
            batch.reports[batch.count++] = buttons[head];
            head = (head + 1) % kButtons;
            count--;
        }
        // Delay wheel and pot positions until earlier button edges have been delivered.
        if (count == 0) {
            for (unsigned i = 1; i < 3; i++) {
                if (dirty[i]) batch.reports[batch.count++] = latest[i];
                dirty[i] = false;
            }
        }
    }
};
}
