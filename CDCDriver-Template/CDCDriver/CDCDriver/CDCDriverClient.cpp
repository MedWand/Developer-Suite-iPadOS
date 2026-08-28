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

#include <stdio.h>
#include "CDCDriverClient.h"
#include <DriverKit/IOLib.h>
#include <DriverKit/IOUserClient.h>
#include <DriverKit/IODispatchQueue.h>
#include <DriverKit/OSData.h>
#include <USBDriverKit/USBDriverKit.h>
#include "Utilities.hpp"
#include "CDCDriver.h"
#include "DriverClientCommunicationTypes.h"
#include "USBCDCInterface.hpp"

const IOUserClientMethodDispatch externalMethodChecks[NumberOfExternalMethods] = {
    // ExternalMethodType_Scalar and ExternalMethodType_Struct are intentionally omitted.
    // This is so they can be called directly, which is not recommended, but provided for ease of understanding.
    // Instead, prefer the "_Checked" methods, as they are safer and less prone to attacks.
    //
    // When possible choose exact sizes for all variables for security reasons, but if a size must be variable, use kIOUserClientVariableStructureSize.
    /// - Tag: ClientMethodDispatch_CheckedScalar
    [ExternalMethodType_RegisterReceivedDataCallback] =
    {
        .function = (IOUserClientMethodFunction) &CDCDriverClient::StaticRegisterReceivedDataCallback,
        .checkCompletionExists = true,
        .checkScalarInputCount = 0,
        .checkStructureInputSize = sizeof(DataStruct),
        .checkScalarOutputCount = 0,
        .checkStructureOutputSize = sizeof(DataStruct),
    },
    
    [ExternalMethodType_SendData] =
    {
        .function = (IOUserClientMethodFunction) &CDCDriverClient::StaticHandleSendData,
        .checkCompletionExists = false,
        .checkScalarInputCount = 1,
        .checkStructureInputSize = 0,
        .checkScalarOutputCount = 0,
        .checkStructureOutputSize = 0,
    },
};

struct CDCDriverClient_IVars
{
    USBCDCInterface *interface = nullptr;

    OSAction *receivedDataCallbackAction = nullptr;
    IODispatchQueue *dispatchQueue = nullptr;
    
    IOBufferMemoryDescriptor *receivedDataTransferBuffer = nullptr;
    IOBufferMemoryDescriptor *transmitDataTransferBuffer = nullptr;

    uint8_t bufferSegmentIndex;
};

bool
CDCDriverClient::init()
{
    bool result = false;

    os_log(OS_LOG_DEFAULT, "[DriverClient] init");

    result = super::init();
    __Require(true == result, Exit, "super init");

    ivars = IONewZero(CDCDriverClient_IVars, 1);
    __Require_Action(NULL != ivars, Exit, result = false);

Exit:
    return result;
}

kern_return_t
IMPL(CDCDriverClient, Start)
{
    kern_return_t ret = kIOReturnSuccess;
    
    os_log(OS_LOG_DEFAULT, "[DriverClient] Start");
    
    ret = Start(provider, SUPERDISPATCH);
    __Require(kIOReturnSuccess == ret, Exit, "[DriverClient] super start failed");
    
    
    ret = IODispatchQueue::Create("com.medwand.cdc.driver.DriverClientDispatchQueue", 0, 0, &ivars->dispatchQueue);
    __Require(kIOReturnSuccess == ret, Exit, "[DriverClient] Creating dispatch queue failed");

    ret = RegisterService();
    if (ret != kIOReturnSuccess) {
        os_log(OS_LOG_DEFAULT, "[DriverClient] Failed to register service with error: 0x%08x.", ret);
        goto Exit;
    }

Exit:
    if (ret != kIOReturnSuccess) {
        os_log(OS_LOG_DEFAULT, "[DriverClient] DriverClient failed to start: %08x", ret);
    }
    return ret;
}

kern_return_t IMPL(CDCDriverClient, Stop)
{
    kern_return_t ret = kIOReturnSuccess;

    os_log(OS_LOG_DEFAULT, "[DriverClient] Stop");

    ret = Stop(provider, SUPERDISPATCH);

    if (ret != kIOReturnSuccess) {
        os_log(OS_LOG_DEFAULT, "[DriverClient] Error in super Stop: 0x%08x", ret);
    }

    return ret;
}

void
CDCDriverClient::free()
{
    os_log(OS_LOG_DEFAULT, "[DriverClient] free");
    
    OSSafeReleaseNULL(ivars->receivedDataTransferBuffer);
    OSSafeReleaseNULL(ivars->transmitDataTransferBuffer);
    OSSafeReleaseNULL(ivars->receivedDataCallbackAction);

    super::free();
}

void CDCDriverClient::dataWasReceived(IOBufferMemoryDescriptor *bufferDescriptor, uint64_t actualByteCount)
{
    if (ivars->receivedDataTransferBuffer == nullptr ||
        ivars->receivedDataCallbackAction == nullptr ||
        actualByteCount == 0) {
        return;
    }
    
    uint64_t bufferSegmentStartIndex = ivars->bufferSegmentIndex * 64;
    uint64_t asyncData[2] = { bufferSegmentStartIndex, actualByteCount };
    auto inputData = CDCDriverUtilities::GetRawIOBuffer(bufferDescriptor);
    auto outputData = CDCDriverUtilities::GetRawIOBuffer(ivars->receivedDataTransferBuffer);
    memcpy((uint8_t *)outputData.bytes + bufferSegmentStartIndex, inputData.bytes, inputData.length);
    ivars->bufferSegmentIndex = ((ivars->bufferSegmentIndex + 1) % (outputData.length / 64));
    AsyncCompletion(ivars->receivedDataCallbackAction, kIOReturnSuccess, asyncData, 2);
}

kern_return_t IMPL(CDCDriverClient, CopyClientMemoryForType) //(uint64_t type, uint64_t *options, IOMemoryDescriptor **memory)
{
    kern_return_t result = kIOReturnSuccess;
    switch (type) {
        case MappedMemoryType_ReceiveDataBuffer: {
            if (ivars->receivedDataTransferBuffer != nullptr) { // Unmapping
                *memory = ivars->receivedDataTransferBuffer;
                break;
            }
            
            IOBufferMemoryDescriptor *buffer = nullptr;
            result = IOBufferMemoryDescriptor::Create(kIOMemoryDirectionOut, kReceiveDataTransferBufferSize, 0, &buffer);
            if (buffer == nullptr) {
                result = result ?: kIOReturnNoMemory;
                break;
            }
            *memory = buffer; // returned with refcount 1
            buffer->retain(); // Will get released by caller
            ivars->receivedDataTransferBuffer = buffer;
        }
            break;
        case MappedMemoryType_TransmitDataBuffer: {
            if (ivars->transmitDataTransferBuffer != nullptr) { // Unmapping
                *memory = ivars->transmitDataTransferBuffer;
                break;
            }
            
            IOBufferMemoryDescriptor *buffer = nullptr;
            result = IOBufferMemoryDescriptor::Create(kIOMemoryDirectionIn, kTransmitDataTransferBufferSize, 0, &buffer);
            if (buffer == nullptr) {
                result = result ?: kIOReturnNoMemory;
                break;
            }
            *memory = buffer; // returned with refcount 1
            buffer->retain(); // Will get released by caller
            ivars->transmitDataTransferBuffer = buffer;
        }
            break;
        default:
            result = CopyClientMemoryForType(type, options, memory, SUPERDISPATCH);
            break;
    }
    return result;
}

USBCDCInterface *CDCDriverClient::getInterface()
{
    return ivars->interface;
}

void CDCDriverClient::setInterface(USBCDCInterface *interface) 
{
    ivars->interface = interface;
}

// MARK: ExternalMethod Handler
// This method is called when an application calls IOConnectCall...Method.
// All of the passed inputs and outputs are accessible through the "arguments" variable.
// Never trust any of the data that has been passed in, such as sizes, as these can be used as attack vectors on your code.
// For example, an incorrect size may allow for a buffer overflow attack on the dext.
kern_return_t CDCDriverClient::ExternalMethod(uint64_t selector,
                                              IOUserClientMethodArguments* arguments,
                                              const IOUserClientMethodDispatch* dispatch,
                                              OSObject* target,
                                              void* reference)
{
    if (selector >= NumberOfExternalMethods) {
        return kIOReturnBadMessageID;
    }
    
    dispatch = &externalMethodChecks[selector];
    if (!target) {
        target = this;
    }
    
    return super::ExternalMethod(selector, arguments, dispatch, target, reference);
}

//MARK: Static External Handlers

kern_return_t CDCDriverClient::StaticRegisterReceivedDataCallback(OSObject* target, void* reference, IOUserClientMethodArguments* arguments)
{
    if (target == nullptr) {
        return kIOReturnError;
    }

    return ((CDCDriverClient*)target)->RegisterReceivedDataCallback(reference, arguments);
}

kern_return_t CDCDriverClient::StaticHandleSendData(OSObject* target, void* reference, IOUserClientMethodArguments* arguments)
{
    if (target == nullptr) {
        return kIOReturnError;
    }

    return ((CDCDriverClient*)target)->HandleSendData(reference, arguments);
}

// MARK: Instance External Handlers

kern_return_t CDCDriverClient::RegisterReceivedDataCallback(void* reference, IOUserClientMethodArguments* arguments)
{
    os_log(OS_LOG_DEFAULT, "[DriverClient] Got new async callback");

    DataStruct* input = nullptr;
    DataStruct output = {};

    /// - Tag: RegisterAsyncCallback_StoreCompletion
    if (arguments->completion == nullptr) {
        os_log(OS_LOG_DEFAULT, "[DriverClient] Got a null completion.");
        return kIOReturnBadArgument;
    }

    // Save the completion for later.
    // If not saved, then it might be freed before the asychronous return.
    ivars->receivedDataCallbackAction = arguments->completion;
    ivars->receivedDataCallbackAction->retain();

    input = (DataStruct*)arguments->structureInput->getBytesNoCopy();

    // Retain action memory for later work.

    output.foo = input->foo + 1;
    output.bar = input->bar + 10;

    arguments->structureOutput = OSData::withBytes(&output, sizeof(DataStruct));

    return kIOReturnSuccess;
}

kern_return_t CDCDriverClient::HandleSendData(void* reference, IOUserClientMethodArguments* arguments)
{
    // This function was checked by IOUserClientMethodDispatch, so it doesn't need to validate the arguments.

    if (ivars->transmitDataTransferBuffer == nullptr) {
        return kIOReturnNotOpen;
    }

    os_log(OS_LOG_DEFAULT, "[DriverClient] Handle send data");
    
    uint64_t numBytesToSend = arguments->scalarInput[0];
    if (numBytesToSend > kTransmitDataTransferBufferSize) { numBytesToSend = kTransmitDataTransferBufferSize; }

    if (numBytesToSend <= 0) {
        return kIOReturnBadArgument;
    }

    return ivars->interface->sendData(ivars->transmitDataTransferBuffer, (uint32_t)numBytesToSend);
}
