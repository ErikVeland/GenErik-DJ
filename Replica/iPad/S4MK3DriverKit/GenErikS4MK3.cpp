#include <DriverKit/IOBufferMemoryDescriptor.h>
#include <DriverKit/IOLib.h>
#include <USBDriverKit/IOUSBHostInterface.h>
#include "S4MK3Reports.h"
#include "GenErikS4MK3.h"
#include "GenErikS4MK3UserClient.h"

namespace {
constexpr uint8_t kInterface = 3;
constexpr uint8_t kInputEndpoint = 0x83;
constexpr uint8_t kPanelEndpoint = 0x02;

kern_return_t makeBuffer(uint64_t direction, uint32_t length, IOBufferMemoryDescriptor** buffer) {
    auto result = IOBufferMemoryDescriptor::Create(direction, length, 0, buffer);
    if (result == kIOReturnSuccess) result = (*buffer)->SetLength(length);
    return result;
}

kern_return_t sendControlLight(IOUSBHostInterface* interface, const uint8_t* bytes, uint16_t length) {
    IOBufferMemoryDescriptor* buffer = nullptr;
    auto result = makeBuffer(kIOMemoryDirectionOut, length, &buffer);
    IOAddressSegment range{};
    if (result == kIOReturnSuccess) result = buffer->GetAddressRange(&range);
    if (result == kIOReturnSuccess) {
        memcpy(reinterpret_cast<void*>(range.address), bytes, length);
        uint16_t written = 0;
        result = interface->DeviceRequest(0x21, 0x09, 0x0200 | bytes[0], kInterface, length, buffer, &written, 40);
        if (result == kIOReturnSuccess && written != length) result = kIOReturnIOError;
    }
    OSSafeReleaseNULL(buffer);
    return result;
}

uint64_t absoluteNanoseconds(uint64_t ticks, const mach_timebase_info_data_t& timebase) {
    return ticks / timebase.denom * timebase.numer
        + ticks % timebase.denom * timebase.numer / timebase.denom;
}
}

struct GenErikS4MK3_IVars {
    IOLock* lock = nullptr;
    IOUSBHostInterface* interface = nullptr;
    IOUSBHostPipe* input = nullptr;
    IOUSBHostPipe* panel = nullptr;
    IOBufferMemoryDescriptor* inputBuffer = nullptr;
    IOBufferMemoryDescriptor* panelBuffer = nullptr;
    OSAction* inputAction = nullptr;
    OSAction* panelAction = nullptr;
    S4MK3::ReportQueue reports{};
    bool open = false;
    bool active = false;
    bool panelError = false;
    bool clientOpen = false;
    uint32_t panelLength = 0;
    mach_timebase_info_data_t timebase{};
};

bool GenErikS4MK3::init() {
    if (!super::init()) return false;
    ivars = IONewZero(GenErikS4MK3_IVars, 1);
    if (!ivars) return false;
    ivars->lock = IOLockAlloc();
    return ivars->lock && mach_timebase_info(&ivars->timebase) == kIOReturnSuccess && ivars->timebase.denom != 0;
}

void GenErikS4MK3::free() {
    if (ivars) {
        IOLockFreeZero(ivars->lock);
        IOSafeDeleteNULL(ivars, GenErikS4MK3_IVars, 1);
    }
    super::free();
}

kern_return_t IMPL(GenErikS4MK3, Start) {
    auto result = Start(provider, SUPERDISPATCH);
    if (result != kIOReturnSuccess) return result;
    ivars->interface = OSDynamicCast(IOUSBHostInterface, provider);
    if (!ivars->interface) return kIOReturnBadArgument;
    result = ivars->interface->Open(this, 0, 0);
    if (result != kIOReturnSuccess) {
        ivars->interface = nullptr;
        return result;
    }
    ivars->open = true;

    result = ivars->interface->CopyPipe(kInputEndpoint, &ivars->input);
    if (result == kIOReturnSuccess) result = ivars->interface->CopyPipe(kPanelEndpoint, &ivars->panel);
    if (result == kIOReturnSuccess) result = makeBuffer(kIOMemoryDirectionIn, 96, &ivars->inputBuffer);
    if (result == kIOReturnSuccess) result = CreateActionInputComplete(0, &ivars->inputAction);
    if (result == kIOReturnSuccess) result = CreateActionPanelComplete(0, &ivars->panelAction);
    if (result == kIOReturnSuccess) {
        uint8_t initReport[27] = {0x30, 0, 1, 3};
        result = sendControlLight(ivars->interface, initReport, sizeof(initReport));
        if (result == kIOReturnSuccess) {
            initReport[1] = 1;
            IOLockLock(ivars->lock);
            result = QueuePanel(initReport, sizeof(initReport));
            IOLockUnlock(ivars->lock);
        }
    }
    if (result == kIOReturnSuccess) {
        // Seed the surface and fader state when the firmware supports GET_REPORT.
        for (uint8_t id = 1; id <= 2; id++) {
            uint16_t count = 0;
            IOAddressSegment range{};
            if (ivars->interface->DeviceRequest(0xa1, 1, 0x0100 | id, kInterface, 95,
                                                ivars->inputBuffer, &count, 30) == kIOReturnSuccess
                && ivars->inputBuffer->GetAddressRange(&range) == kIOReturnSuccess) {
                ivars->reports.receive(reinterpret_cast<const uint8_t*>(range.address), count, absoluteNanoseconds(mach_absolute_time(), ivars->timebase));
            }
        }
        ivars->active = true;
        result = StartInput();
    }
    if (result == kIOReturnSuccess) result = SetName("org.generikdj.replica.s4mk3.driver");
    if (result == kIOReturnSuccess) result = RegisterService();
    if (result != kIOReturnSuccess) CloseInterface();
    return result;
}

kern_return_t GenErikS4MK3::StartInput() {
    return ivars->input->AsyncIO(ivars->inputBuffer, 96, ivars->inputAction, 0);
}

void IMPL(GenErikS4MK3, InputComplete) {
    IOLockLock(ivars->lock);
    if (!ivars->active) {
        IOLockUnlock(ivars->lock);
        return;
    }
    IOAddressSegment range{};
    if (status == kIOReturnSuccess && ivars->inputBuffer->GetAddressRange(&range) == kIOReturnSuccess) {
        ivars->reports.receive(reinterpret_cast<const uint8_t*>(range.address), actualByteCount,
                               absoluteNanoseconds(completionTimestamp ? completionTimestamp : mach_absolute_time(), ivars->timebase));
        status = StartInput();
    } else if (status == kIOReturnSuccess) {
        status = kIOReturnIOError;
    }
    if (status != kIOReturnSuccess) ivars->active = false;
    IOLockUnlock(ivars->lock);
}

void IMPL(GenErikS4MK3, PanelComplete) {
    IOLockLock(ivars->lock);
    OSSafeReleaseNULL(ivars->panelBuffer);
    ivars->panelError = status != kIOReturnSuccess || actualByteCount != ivars->panelLength;
    IOLockUnlock(ivars->lock);
}

kern_return_t GenErikS4MK3::ReadBatch(S4MK3::Batch* batch) {
    IOLockLock(ivars->lock);
    const bool active = ivars->active;
    if (active) ivars->reports.drain(*batch);
    IOLockUnlock(ivars->lock);
    return active ? kIOReturnSuccess : kIOReturnNotAttached;
}

bool GenErikS4MK3::AcquireClient() {
    IOLockLock(ivars->lock);
    const bool acquired = ivars->active && !ivars->clientOpen;
    if (acquired) {
        ivars->clientOpen = true;
        ivars->reports.requestBaseline();
    }
    IOLockUnlock(ivars->lock);
    return acquired;
}

void GenErikS4MK3::ReleaseClient() {
    IOLockLock(ivars->lock);
    ivars->clientOpen = false;
    IOLockUnlock(ivars->lock);
}

kern_return_t GenErikS4MK3::WriteLight(const uint8_t* bytes, size_t count) {
    if (!S4MK3::validLight(bytes, count)) return kIOReturnBadArgument;
    IOLockLock(ivars->lock);
    if (!ivars->active) {
        IOLockUnlock(ivars->lock);
        return kIOReturnNotAttached;
    }
    if (bytes[0] == 0x32) {
        auto* interface = ivars->interface;
        interface->retain();
        IOLockUnlock(ivars->lock);
        auto result = sendControlLight(interface, bytes, static_cast<uint16_t>(count));
        interface->release();
        return result;
    }
    const auto result = QueuePanel(bytes, count);
    IOLockUnlock(ivars->lock);
    return result;
}

kern_return_t GenErikS4MK3::QueuePanel(const uint8_t* bytes, size_t count) {
    if (ivars->panelBuffer) return kIOReturnBusy;
    if (ivars->panelError) return kIOReturnIOError;
    auto result = makeBuffer(kIOMemoryDirectionOut, static_cast<uint32_t>(count), &ivars->panelBuffer);
    IOAddressSegment range{};
    if (result == kIOReturnSuccess) result = ivars->panelBuffer->GetAddressRange(&range);
    if (result == kIOReturnSuccess) {
        memcpy(reinterpret_cast<void*>(range.address), bytes, count);
        ivars->panelLength = static_cast<uint32_t>(count);
        result = ivars->panel->AsyncIO(ivars->panelBuffer, ivars->panelLength, ivars->panelAction, 0);
    }
    if (result != kIOReturnSuccess) OSSafeReleaseNULL(ivars->panelBuffer);
    return result;
}

void GenErikS4MK3::CloseInterface() {
    IOLockLock(ivars->lock);
    ivars->active = false;
    IOLockUnlock(ivars->lock);
    if (ivars->input) ivars->input->Abort(0, kIOReturnAborted, nullptr);
    if (ivars->panel) ivars->panel->Abort(0, kIOReturnAborted, nullptr);
    if (ivars->open) ivars->interface->Close(this, 0);
    ivars->open = false;
    ivars->interface = nullptr;
    OSSafeReleaseNULL(ivars->inputAction);
    OSSafeReleaseNULL(ivars->panelAction);
    OSSafeReleaseNULL(ivars->inputBuffer);
    IOLockLock(ivars->lock);
    OSSafeReleaseNULL(ivars->panelBuffer);
    IOLockUnlock(ivars->lock);
    OSSafeReleaseNULL(ivars->input);
    OSSafeReleaseNULL(ivars->panel);
}

kern_return_t IMPL(GenErikS4MK3, Stop) {
    CloseInterface();
    return Stop(provider, SUPERDISPATCH);
}

kern_return_t IMPL(GenErikS4MK3, NewUserClient) {
    if (type != 0) return kIOReturnUnsupported;
    IOService* service = nullptr;
    const auto result = Create(this, "UserClientProperties", &service);
    if (result != kIOReturnSuccess) return result;
    auto* client = OSDynamicCast(GenErikS4MK3UserClient, service);
    if (!client) {
        service->release();
        return kIOReturnError;
    }
    *userClient = client;
    return kIOReturnSuccess;
}
