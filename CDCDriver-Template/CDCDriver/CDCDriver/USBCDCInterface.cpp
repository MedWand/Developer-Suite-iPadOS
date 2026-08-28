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

//
//  USBCDCInterface.cpp
//  Driver
//
//  Created by Andrew Madsen on 01/29/24.
//  Copyright © 2024 Medwand, Inc. All rights reserved.
//

#include "USBCDCInterface.hpp"
#include <DriverKit/DriverKit.h>
#include "Utilities.hpp"
#include "CDCDriver.h"

enum class RequestCode: uint8_t {
    SetLineCoding = 0x20,
    GetLineCoding = 0x21,
    SetControlLineState = 0x22,
};

#define kRequestTypeGet 0xA1
#define kRequestTypeSet 0x21

USBCDCInterface::USBCDCInterface(CDCDriver *driver,
                                 IOUSBHostDevice *device,
                                 const IOUSBConfigurationDescriptor *configDesc)
:
driver(driver),
controlPipe{nullptr},
controlDataBuffer{nullptr},
controlInterface{nullptr},
dataInterface{nullptr}
{
    // We should find two interfaces, the CDC class communication interface, and the CDC class data interface
    // The communication interface should have a single interrupt IN endpoint
    // The data interface should have both bulk IN and bulk OUT endpoints
    const IOUSBInterfaceDescriptor *controlInterfaceDesc = NULL;
    const IOUSBInterfaceDescriptor *dataInterfaceDesc = NULL;
    
    const IOUSBDescriptorHeader *curHeader = NULL;
    while ((curHeader = IOUSBGetNextDescriptor(configDesc, curHeader))) {
        switch (curHeader->bDescriptorType) {
            case kIOUSBDescriptorTypeInterface: {
                auto interfaceDesc = (const IOUSBInterfaceDescriptor *)curHeader;
                if (interfaceDesc->bInterfaceClass == 0x02) { // Control interface
                    controlInterfaceDesc = interfaceDesc;
                } else if (interfaceDesc->bInterfaceClass == 0x0A) { // Data interface
                    dataInterfaceDesc = interfaceDesc;
                }
            }
                break;
            default:
//                os_log(OS_LOG_DEFAULT, "some other type: %{public}i", curHeader->bDescriptorType);
                break;
        }
    }
    
    if (controlInterfaceDesc == nullptr || dataInterfaceDesc == nullptr) {
        return;
    }
    if (controlInterfaceDesc->bNumEndpoints != 1) {
        return;
    }
    if (dataInterfaceDesc->bNumEndpoints != 2) {
        return;
    }
    
    // Found interfaces, now get endpoints
    
    // Get control endpoint, which should have a single interrupt in endpoint
    const IOUSBEndpointDescriptor *controlEndpoint = NULL;
    const IOUSBEndpointDescriptor *endpoint = NULL;
    while ((endpoint = IOUSBGetNextEndpointDescriptor(configDesc, controlInterfaceDesc, (IOUSBDescriptorHeader *)endpoint))) {
        if (endpoint->bDescriptorType != kIOUSBDescriptorTypeEndpoint) {
            return;
        }
        if ((endpoint->bEndpointAddress & kIOUSBEndpointDescriptorDirection) != kIOUSBEndpointDescriptorDirectionIn) {
            continue;
        }
        if ((endpoint->bmAttributes & kIOUSBEndpointDescriptorTransferType) != kIOUSBEndpointDescriptorTransferTypeInterrupt) {
            continue;
        }
        controlEndpoint = endpoint;
        break;
    }
    
    if (controlEndpoint == NULL) {
        return;
    }
    
    // Get data endpoints, which should be two bulk transfer endpoints, one out, one in
    const IOUSBEndpointDescriptor *readEndpoint = NULL;
    const IOUSBEndpointDescriptor *writeEndpoint = NULL;
    endpoint = NULL;
    while ((endpoint = IOUSBGetNextEndpointDescriptor(configDesc, dataInterfaceDesc, (IOUSBDescriptorHeader *)endpoint))) {
        if (endpoint->bDescriptorType != kIOUSBDescriptorTypeEndpoint) {
            return;
        }
        
        if ((endpoint->bmAttributes & kIOUSBEndpointDescriptorTransferType) != kIOUSBEndpointDescriptorTransferTypeBulk) {
            continue;
        }
        if ((endpoint->bEndpointAddress & kIOUSBEndpointDescriptorDirection) == kIOUSBEndpointDescriptorDirectionIn) {
            readEndpoint = endpoint;
            continue;
        }
        if ((endpoint->bEndpointAddress & kIOUSBEndpointDescriptorDirection) == kIOUSBEndpointDescriptorDirectionOut) {
            writeEndpoint = endpoint;
            continue;
        }
    }
    
    if (readEndpoint == NULL || writeEndpoint == NULL) {
        return;
    }
    
    this->device = device;
    this->configurationDescription = configDesc;
    
    this->controlInterfaceDesc = controlInterfaceDesc;
    this->controlEndpoint = controlEndpoint;
    
    this->dataInterfaceDesc = dataInterfaceDesc;
    this->readEndpoint = readEndpoint;
    this->writeEndpoint = writeEndpoint;
}

USBCDCInterface::~USBCDCInterface()
{
    OSObjectSafeReleaseNULL(driver);
    OSObjectSafeReleaseNULL(controlInterface);
    OSObjectSafeReleaseNULL(dataInterface);
    OSObjectSafeReleaseNULL(controlPipe);
    OSObjectSafeReleaseNULL(controlDataBuffer);
    
    OSObjectSafeReleaseNULL(readPipe);
    OSObjectSafeReleaseNULL(writePipe);
    OSObjectSafeReleaseNULL(readDataBuffer);
    OSObjectSafeReleaseNULL(writeDataBuffer);
    OSObjectSafeReleaseNULL(readAction);
}

kern_return_t USBCDCInterface::configure_device()
{
    if (!is_valid()) { return false; }
    auto result = device->SetConfiguration(configurationDescription->bConfigurationValue, false);
    return result;
}

kern_return_t USBCDCInterface::fetchInterfaces()
{
    uintptr_t interfaceIterator;
    auto result = device->CreateInterfaceIterator(&interfaceIterator);
    if (result != kIOReturnSuccess) {
        os_log(OS_LOG_DEFAULT, "Error getting interface iterator: %i", result);
        return result;
    }
    IOUSBHostInterface *eachInterface = nullptr;
    do {
        device->CopyInterface(interfaceIterator, &eachInterface);
        if (eachInterface == nullptr) {
            OSSafeReleaseNULL(eachInterface);
            break;
        }
        auto configDesc = eachInterface->CopyConfigurationDescriptor();
        auto interfaceDesc = eachInterface->GetInterfaceDescriptor(configDesc);
                
        if (interfaceDesc->bInterfaceNumber == controlInterfaceDesc->bInterfaceNumber) {
            OSObjectRetain(eachInterface);
            controlInterface = eachInterface;
        }
        if (interfaceDesc->bInterfaceNumber == dataInterfaceDesc->bInterfaceNumber) {
            OSObjectRetain(eachInterface);
            dataInterface = eachInterface;
        }
        OSObjectRelease(eachInterface);
        IOUSBHostFreeDescriptor(configDesc);
    } while (true);
    device->DestroyInterfaceIterator(interfaceIterator);
    
    if (controlInterface == nullptr || dataInterface == nullptr) {
        return kIOReturnError;
    }

    return kIOReturnSuccess;
}

kern_return_t USBCDCInterface::openControlEndpoint()
{
    if (!is_valid()) {
        return kIOReturnInvalid;
    }
    
    auto pipeAddress = controlEndpoint->bEndpointAddress;
    IOUSBHostPipe *pipe = nullptr;
    kern_return_t result = controlInterface->CopyPipe(pipeAddress, &pipe);
    if (result != kIOReturnSuccess) {
        return result;
    }
    this->controlPipe = pipe;
    
    IOBufferMemoryDescriptor *controlDataBuffer = nullptr;
    result = controlInterface->CreateIOBuffer(kIOMemoryDirectionInOut, 128, &controlDataBuffer);
    if (result != kIOReturnSuccess) {
        return result;
    }
    this->controlDataBuffer = controlDataBuffer;
    
    return kIOReturnSuccess;
}

kern_return_t USBCDCInterface::openDataEndpoints()
{
    if (!is_valid()) {
        return kIOReturnInvalid;
    }
    
    // Open data interface
    auto result = dataInterface->Open(driver, 0, NULL);
    if (result != kIOReturnSuccess) {
        return result;
    }
    
    // Get write pipe
    auto writePipeAddress = writeEndpoint->bEndpointAddress;
    IOUSBHostPipe *writePipe = nullptr;
    result = dataInterface->CopyPipe(writePipeAddress, &writePipe);
    if (result != kIOReturnSuccess) {
        return result;
    }
    this->writePipe = writePipe;
    
    // Create write data buffer
    IOBufferMemoryDescriptor *writeDataBuffer = nullptr;
    result = dataInterface->CreateIOBuffer(kIOMemoryDirectionInOut, kTransmitDataTransferBufferSize, &writeDataBuffer);
    if (result != kIOReturnSuccess) {
        return result;
    }
    this->writeDataBuffer = writeDataBuffer;
    
    // Get read pipe
    auto readPipeAddress = readEndpoint->bEndpointAddress;
    IOUSBHostPipe *readPipe = nullptr;
    result = dataInterface->CopyPipe(readPipeAddress, &readPipe);
    if (result != kIOReturnSuccess) {
        return result;
    }
    this->readPipe = readPipe;
    
    // Create read data buffer
    IOBufferMemoryDescriptor *readDataBuffer = nullptr;
    result = dataInterface->CreateIOBuffer(kIOMemoryDirectionIn, kReceivedDataSegmentSize, &readDataBuffer);
    if (result != kIOReturnSuccess) {
        return result;
    }
    this->readDataBuffer = readDataBuffer;
    
    // Register for async IO on read pipe
    OSAction *readAction = nullptr;
    result = OSAction::Create(driver,
                              CDCDriver_ReadComplete_ID,
                              IOUSBHostPipe_CompleteAsyncIO_ID,
                              0,
                              &readAction);
    if (result != kIOReturnSuccess) {
        return result;
    }
    this->readAction = readAction;
    result = pollForData(); // Start reading
    if (result != kIOReturnSuccess) {
        return result;
    }
    
    return result;
}

kern_return_t USBCDCInterface::sendData(IOBufferMemoryDescriptor *buffer, uint32_t numBytesToSend)
{
    kern_return_t result = kIOReturnSuccess;
    
    if (numBytesToSend > kTransmitDataTransferBufferSize) {
        return kIOReturnOverrun;
    }
    
    auto inputData = CDCDriverUtilities::GetRawIOBuffer(buffer);
    inputData.length = numBytesToSend;
    
    os_log(OS_LOG_DEFAULT, "[USBCDCInterface] sendData() %i bytes", (int)inputData.length);

    auto writeData = CDCDriverUtilities::GetRawIOBuffer(writeDataBuffer);
    memcpy(writeData.bytes, inputData.bytes, numBytesToSend);
    writeDataBuffer->SetLength(numBytesToSend);
    
    uint32_t bytesTransferred = 0;
    result = writePipe->IO(writeDataBuffer, numBytesToSend, &bytesTransferred, 100);
    
    return result;
}

IOBufferMemoryDescriptor *USBCDCInterface::GetReadBuffer(IOReturn status,
                                                       uint32_t actualByteCount,
                                                       uint64_t completionTimestamp)
{
    return readDataBuffer;
}

kern_return_t USBCDCInterface::pollForData()
{
    auto result = readPipe->AsyncIO(readDataBuffer, kReceivedDataSegmentSize, readAction, 100);
    return result;
}

kern_return_t USBCDCInterface::close()
{
    kern_return_t result = kIOReturnSuccess;

    os_log(OS_LOG_DEFAULT, "[USBCDCInterface] close");

//    if (controlInterface != nullptr) {
//        result = controlInterface->Close(device, 0);
//    }
    
    if (dataInterface != nullptr) {
        result = dataInterface->Close(driver, 0);
    }
    
    return result;
}

#pragma mark - Private

kern_return_t USBCDCInterface::updateLineCodingState()
{
    if (!is_valid()) {
        return kIOReturnInvalid;
    }
    if (controlPipe == nullptr || controlDataBuffer == nullptr) {
        return kIOReturnNotOpen;
    }
    
    uint8_t data[7] = {
        0, 0, 0, 0, // Four bytes for the baud rate, will be filled in later.
        0, // Stop bits. 0 means "1 stop bit"
        0, // Parity. 0 means "no parity"
        8, // Number of data bits
    };
    data[0] = (baudRate) & 0xff;
    data[1] = (baudRate >> 8) & 0xff;
    data[2] = (baudRate >> 16) & 0xff;
    data[3] = (baudRate >> 24) & 0xff;
    
    auto ioBuffer = CDCDriverUtilities::GetRawIOBuffer(controlDataBuffer);
    memcpy(ioBuffer.bytes, data, 7);
    uint16_t bytesTransferred = 0;
    auto result = device->DeviceRequest(device,
                                        kRequestTypeSet,
                                        static_cast<int8_t>(RequestCode::SetLineCoding),
                                        0,
                                        controlInterfaceDesc->bInterfaceNumber,
                                        7,
                                        controlDataBuffer,
                                        &bytesTransferred,
                                        100);
    return result;
}

kern_return_t USBCDCInterface::updateControlLinesState()
{
    if (!is_valid()) {
        return kIOReturnInvalid;
    }
    if (controlPipe == nullptr || controlDataBuffer == nullptr) {
        return kIOReturnNotOpen;
    }

    uint8_t data = dtrHigh ? 0x1 : 0x0;

    auto ioBuffer = CDCDriverUtilities::GetRawIOBuffer(controlDataBuffer);
    memcpy(ioBuffer.bytes, &data, 1);
    uint16_t bytesTransferred = 0;
    auto result = device->DeviceRequest(device,
                                        kRequestTypeSet,
                                        static_cast<int8_t>(RequestCode::SetControlLineState),
                                        data,
                                        controlInterfaceDesc->bInterfaceNumber,
                                        0,
                                        NULL,
                                        &bytesTransferred,
                                        2000);
    return result;
}

bool USBCDCInterface::is_valid()
{
    if (controlInterfaceDesc == nullptr) { return false; }
    if (controlEndpoint == nullptr) { return false; }
    if (dataInterfaceDesc == nullptr) { return false; }
    if (readEndpoint == nullptr) { return false; }
    if (writeEndpoint == nullptr) { return false; }
    return true;
}

#pragma mark - Property Accessors

int USBCDCInterface::getBaudRate()
{
    return baudRate;
}

kern_return_t USBCDCInterface::setBaudRate(uint32_t value)
{
    baudRate = value;
    return updateLineCodingState();
}

bool USBCDCInterface::getDTRHigh()
{
    return dtrHigh;
}

kern_return_t USBCDCInterface::setDTRHigh(bool value)
{
    dtrHigh = value;
    return updateControlLinesState();
}
