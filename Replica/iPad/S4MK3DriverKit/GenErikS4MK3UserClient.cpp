#include <DriverKit/IOLib.h>
#include <DriverKit/OSData.h>
#include "S4MK3Reports.h"
#include "GenErikS4MK3.h"
#include "GenErikS4MK3UserClient.h"

struct GenErikS4MK3UserClient_IVars {
    GenErikS4MK3* driver = nullptr;
};

bool GenErikS4MK3UserClient::init() {
    if (!super::init()) return false;
    ivars = IONewZero(GenErikS4MK3UserClient_IVars, 1);
    return ivars != nullptr;
}

void GenErikS4MK3UserClient::free() {
    if (ivars) {
        if (ivars->driver) ivars->driver->ReleaseClient();
        OSSafeReleaseNULL(ivars->driver);
        IOSafeDeleteNULL(ivars, GenErikS4MK3UserClient_IVars, 1);
    }
    super::free();
}

kern_return_t IMPL(GenErikS4MK3UserClient, Start) {
    const auto result = Start(provider, SUPERDISPATCH);
    if (result != kIOReturnSuccess) return result;
    auto* driver = OSDynamicCast(GenErikS4MK3, provider);
    if (!driver) return kIOReturnBadArgument;
    if (!driver->AcquireClient()) return kIOReturnExclusiveAccess;
    ivars->driver = driver;
    ivars->driver->retain();
    return kIOReturnSuccess;
}

kern_return_t GenErikS4MK3UserClient::ExternalMethod(uint64_t selector, IOUserClientMethodArguments* args,
                                                  const IOUserClientMethodDispatch*, OSObject*, void*) {
    if (!ivars->driver || !args || args->completion || args->scalarInputCount || args->scalarOutputCount
        || args->structureInputDescriptor || args->structureOutputDescriptor) {
        return kIOReturnBadArgument;
    }
    if (selector == 0) {
        if (args->structureInput || args->structureOutputMaximumSize != sizeof(S4MK3::Batch)) {
            return kIOReturnBadArgument;
        }
        S4MK3::Batch batch{};
        const auto result = ivars->driver->ReadBatch(&batch);
        if (result != kIOReturnSuccess) return result;
        args->structureOutput = OSData::withBytes(&batch, sizeof(batch));
        return args->structureOutput ? kIOReturnSuccess : kIOReturnNoMemory;
    }
    if (selector == 1) {
        if (!args->structureInput || args->structureOutputMaximumSize) return kIOReturnBadArgument;
        const auto size = args->structureInput->getLength();
        if (size != 41 && size != 95) return kIOReturnBadArgument;
        return ivars->driver->WriteLight(static_cast<const uint8_t*>(args->structureInput->getBytesNoCopy()), size);
    }
    return kIOReturnUnsupported;
}
