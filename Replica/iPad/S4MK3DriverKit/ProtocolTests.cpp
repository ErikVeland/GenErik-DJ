#include "S4MK3Reports.h"
#include <cassert>

int main() {
    S4MK3::ReportQueue queue;
    uint8_t first[64] = {2};
    uint8_t remainder[15] = {0xcc};
    queue.receive(first, sizeof(first), 100);
    S4MK3::Batch batch{};
    queue.drain(batch);
    assert(batch.count == 0);
    queue.receive(remainder, sizeof(remainder), 200);
    queue.drain(batch);
    assert(batch.count == 1 && batch.reports[0].length == 79);
    assert(batch.reports[0].bytes[64] == 0xcc);

    queue.receive(first, sizeof(first), 300);
    queue.receive(remainder, sizeof(remainder), 30'000'300);
    queue.drain(batch);
    assert(batch.count == 0);

    uint8_t button[23] = {1};
    queue.receive(button, sizeof(button), 30'000'301);
    for (int i = 1; i <= 40; i++) {
        button[1] = static_cast<uint8_t>(i);
        queue.receive(button, sizeof(button), 30'000'301 + i);
    }
    queue.drain(batch);
    assert((batch.flags & S4MK3::kReset) != 0);
    assert(batch.count == 2 && batch.reports[0].bytes[1] == 40);
    assert(batch.reports[1].length == 79);

    uint8_t ring[41] = {0x32, 1, 5};
    ring[9] = 47;
    assert(S4MK3::validLight(ring, sizeof(ring)));
    ring[3] = 1;
    assert(!S4MK3::validLight(ring, sizeof(ring)));
    ring[3] = 0;
    ring[0] = 0x31;
    assert(!S4MK3::validLight(ring, sizeof(ring)));
    assert(!S4MK3::validLight(nullptr, 95));
}
