// ---------------------------------------------------------------------------
// MedWand CDCDriver — driver implementation. DO NOT MODIFY.
//
// This file implements the actual USB CDC device protocol handling and is
// paired with a specific MedWandSDK release (see MEDWAND-TEMPLATE-README.md
// in the repo root). Changes here can silently break wire-protocol
// compatibility with MedWandSDK, or the ability to claim the real MedWand
// USB hardware.
//
// Settings that ARE meant to be reconfigured for your own app (bundle
// identifier, team, provisioning, entitlements) live in
// CDCDriver.xcodeproj's build settings and Configuration/Common.xcconfig,
// not in this file — see MEDWAND-TEMPLATE-README.md for the exact list.
// ---------------------------------------------------------------------------

#include "Utilities.hpp"
#include <stdint.h>
#include <stdio.h>
#include <DriverKit/DriverKit.h>

namespace CDCDriverUtilities {

RawIOBuffer GetRawIOBuffer(IOBufferMemoryDescriptor* buffer)
{
    IOAddressSegment range = {};
    kern_return_t ret = buffer->GetAddressRange(&range);
    if (ret != kIOReturnSuccess) {
        return RawIOBuffer{};
    }
    
    return RawIOBuffer { reinterpret_cast<void*>(range.address), range.length };
}

void PrintBufferContents(RawIOBuffer buffer)
{
    uint8_t *bytes = (uint8_t *)buffer.bytes;
    char string[256] = {0};
    size_t numToPrint = buffer.length;
    if (numToPrint > 255) { numToPrint = 255; }
    for (size_t i=0; i<numToPrint; i++) {
        snprintf(string, sizeof(string) - i, "%02x", bytes[i]);
    }
    os_log(OS_LOG_DEFAULT, "[CDCDriver] %s", string);
}

}
