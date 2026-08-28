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

#include <os/log.h>

#include <DriverKit/IOUserServer.h>
#include <DriverKit/IOLib.h>
#include <USBDriverKit/USBDriverKit.h>
#include <DriverKit/IOUserClient.h>

#include "CDCDriver.h"
#include "CDCDriverClient.h"
#include "USBCDCInterface.hpp"
#include "Utilities.hpp"
#include "ioreturn_strings.h"

struct CDCDriver_IVars
{
    IOUSBHostDevice *device = nullptr;
    USBCDCInterface *cdcInterface = nullptr;
    CDCDriverClient *client = nullptr;
};

bool
CDCDriver::init()
{
    bool result = false;

    os_log(OS_LOG_DEFAULT, "[Driver] init");

    result = super::init();
    __Require(true == result, Exit, "super init");

    ivars = IONewZero(CDCDriver_IVars, 1);
    __Require_Action(NULL != ivars, Exit, result = false);

Exit:
    return result;
}

kern_return_t
IMPL(CDCDriver, Start)
{
    kern_return_t                    ret;
    const IOUSBDeviceDescriptor *deviceDescriptor = nullptr;
    uint8_t numConfigs = 0;
//    bool spin = true;
    
    ret = Start(provider, SUPERDISPATCH);
    __Require(kIOReturnSuccess == ret, Exit, "[Driver] super start failed");

    ivars->device = OSDynamicCast(IOUSBHostDevice, provider);
    __Require_Action(NULL != ivars->device, Exit, ret = kIOReturnNoDevice);
    
//    while (spin) {
//        IOSleep(1);
//    }

    os_log(OS_LOG_DEFAULT, "[Driver] Opening device");
    ret = ivars->device->Open(this, 0, NULL);
    __Require(kIOReturnSuccess == ret, Exit, "[Driver] device open failed");
    
    deviceDescriptor = ivars->device->CopyDeviceDescriptor();
    numConfigs = deviceDescriptor->bNumConfigurations;
    __Require(numConfigs >= 1, Exit, "[Driver] No configs found");
    
    os_log(OS_LOG_DEFAULT, "[Driver] Searching for CDC Interface");
    for (size_t i=0; i<numConfigs; i++) {
        auto configDesc = ivars->device->CopyConfigurationDescriptor(i);
        auto cdcInterface = new USBCDCInterface{this, ivars->device, configDesc};
        if (cdcInterface->is_valid()) {
            ivars->cdcInterface = cdcInterface;
            break;
        }
    }
    
    __Require(nullptr != ivars->cdcInterface, Exit, "[Driver] Device not CDC compliant");
    
    os_log(OS_LOG_DEFAULT, "[Driver] Configuring device");
    ret = ivars->cdcInterface->configure_device();
    __Require(kIOReturnSuccess == ret, Exit, "[Driver] Unable to configure device");
    
    os_log(OS_LOG_DEFAULT, "[Driver] Fetching interfaces");
    ret = ivars->cdcInterface->fetchInterfaces();
    __Require(kIOReturnSuccess == ret, Exit, "[Driver] Unable to get interfaces");
    
    os_log(OS_LOG_DEFAULT, "[Driver] Opening control endpoint");
    ret = ivars->cdcInterface->openControlEndpoint();
    __Require(kIOReturnSuccess == ret, Exit, "[Driver] Unable to open control interface");

    os_log(OS_LOG_DEFAULT, "[Driver] Setting baud rate");
    ret = ivars->cdcInterface->setBaudRate(19200);
    __Require(kIOReturnSuccess == ret, Exit, "[Driver] Unable to set baud rate");

    os_log(OS_LOG_DEFAULT, "[Driver] Opening data endpoints");
    ret = ivars->cdcInterface->openDataEndpoints();
    __Require(kIOReturnSuccess == ret, Exit, "[Driver] Unable to open control interface");

    os_log(OS_LOG_DEFAULT, "[Driver] Setting DTR high");
    ret = ivars->cdcInterface->setDTRHigh(true);
    __Require(kIOReturnSuccess == ret, Exit, "[Driver] Unable to set DTR line");

    os_log(OS_LOG_DEFAULT, "[Driver] Setting name");
    ret = SetName("MedwandCDCDriver");
    __Require(kIOReturnSuccess == ret, Exit, "[Driver] Unable to set service name");
    
    os_log(OS_LOG_DEFAULT, "[Driver] Registering service");
    ret = RegisterService();
    __Require(kIOReturnSuccess == ret, Exit, "[Driver] Unable to register service");
    
    os_log(OS_LOG_DEFAULT, "[Driver] Driver service is running and registered");
    
Exit:
    IOUSBHostFreeDescriptor(deviceDescriptor);
    if (ret != kIOReturnSuccess) {
        os_log(OS_LOG_DEFAULT, "[Driver] Driver failed to start: %{public}s", djt_ioreturn_string(ret));
    }
    return ret;
}

kern_return_t
IMPL(CDCDriver, Stop)
{
    kern_return_t ret = kIOReturnSuccess;

    os_log(OS_LOG_DEFAULT, "[Driver] Stop beginning.");

    if (ivars->cdcInterface != nullptr) {
        ret = ivars->cdcInterface->close();
        if (ret != kIOReturnSuccess) {
            os_log(OS_LOG_DEFAULT, "[Driver] Error closing cdc interface: 0x%08x", ret);
        }
    }

    os_log(OS_LOG_DEFAULT, "[Driver] Stopping");
    ret = ivars->device->Close(this, 0);
    if (ret != kIOReturnSuccess) {
        os_log(OS_LOG_DEFAULT, "[Driver] Error closing device: 0x%08x", ret);
    }
    
    ret = Stop(provider, SUPERDISPATCH);
    if (ret != kIOReturnSuccess) {
        os_log(OS_LOG_DEFAULT, "[Driver] Error closing device: 0x%08x", ret);
    }

    if (ivars->cdcInterface) {
        delete ivars->cdcInterface;
        ivars->cdcInterface = nullptr;
    }

    os_log(OS_LOG_DEFAULT, "[Driver] Stop finished.");

    return ret;
}

void
CDCDriver::free()
{
    os_log(OS_LOG_DEFAULT, "[Driver] free");
        
    if (ivars->cdcInterface) {
        delete ivars->cdcInterface;
        ivars->cdcInterface = nullptr;
    }
    OSSafeReleaseNULL(ivars->client);
    IOSafeDeleteNULL(ivars, CDCDriver_IVars, 1);
    
    super::free();
}

// When an application attaches to the DEXT via IOServiceOpen, this method is called
kern_return_t IMPL(CDCDriver, NewUserClient)
{
    kern_return_t ret = kIOReturnSuccess;
    IOService* client = nullptr;

    os_log(OS_LOG_DEFAULT, "[Driver] NewUserClient()");

    ret = Create(this, "UserClientProperties", &client);
    if (ret != kIOReturnSuccess) {
        os_log(OS_LOG_DEFAULT, "[Driver] NewUserClient() - Failed to create UserClientProperties with error: 0x%08x.", ret);
        goto Exit;
    }

    *userClient = OSDynamicCast(IOUserClient, client);
    if (*userClient == NULL) {
        os_log(OS_LOG_DEFAULT, "[Driver] NewUserClient() - Failed to cast new client.");
        client->release();
        ret = kIOReturnError;
        goto Exit;
    }

    OSSafeReleaseNULL(ivars->client);
    ivars->client = OSDynamicCast(CDCDriverClient, client);
    ivars->client->retain();   // ✅ CDCDriver now owns its own reference
    ivars->client->setInterface(ivars->cdcInterface);

    os_log(OS_LOG_DEFAULT, "[Driver] NewUserClient() - Finished.");

Exit:
    return ret;
}

void IMPL(CDCDriver, ReadComplete)
{
    // Get the read buffer
    auto readDataBuffer = ivars->cdcInterface->GetReadBuffer(status, actualByteCount, completionTimestamp);
    if (actualByteCount > 0) {
        os_log(OS_LOG_DEFAULT, "[Driver] Got %u bytes of data!", actualByteCount);
        auto rawBuffer = CDCDriverUtilities::GetRawIOBuffer(readDataBuffer);
        for (int i=0; i<rawBuffer.length; i++) {
            os_log(OS_LOG_DEFAULT, "[Driver] Buffer[%i] = '%x' ", i, ((uint8_t *)rawBuffer.bytes)[i]);
        }
        if (ivars->client != nullptr) {
            ivars->client->dataWasReceived(readDataBuffer, actualByteCount);
        }
    }
    // Poll for next incoming data
    ivars->cdcInterface->pollForData();
}
