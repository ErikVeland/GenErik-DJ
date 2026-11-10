#include "DriverClient.h"
#include <IOKit/IOKitLib.h>
#include <IOKit/IOReturn.h>

uint32_t s4_mk3_driver_open(void) {
    CFMutableDictionaryRef match = IOServiceNameMatching("org.generikdj.replica.s4mk3.driver");
    if (!match) return 0;
    io_iterator_t matches = 0;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, match, &matches) != KERN_SUCCESS) return 0;
    io_service_t service = IOIteratorNext(matches);
    io_service_t second = IOIteratorNext(matches);
    IOObjectRelease(matches);
    if (second) {
        IOObjectRelease(second);
        IOObjectRelease(service);
        return 0;
    }
    if (!service) return 0;
    io_connect_t connection = 0;
    const kern_return_t status = IOServiceOpen(service, mach_task_self(), 0, &connection);
    IOObjectRelease(service);
    return status == KERN_SUCCESS ? connection : 0;
}

void s4_mk3_driver_close(uint32_t connection) {
    if (connection) IOServiceClose(connection);
}

int s4_mk3_driver_read(uint32_t connection, uint8_t* bytes, uint32_t capacity) {
    size_t count = capacity;
    const kern_return_t status = IOConnectCallStructMethod(connection, 0, NULL, 0, bytes, &count);
    return status == KERN_SUCCESS && count <= capacity ? (int)count : -1;
}

int s4_mk3_driver_write(uint32_t connection, const uint8_t* bytes, uint32_t count) {
    const kern_return_t status = IOConnectCallStructMethod(connection, 1, bytes, count, NULL, NULL);
    if (status == KERN_SUCCESS) return 0;
    return status == kIOReturnBusy ? 1 : -1;
}
