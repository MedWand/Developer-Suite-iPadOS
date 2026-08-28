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
//  USBCDCInterface.hpp
//  Driver
//
//  Created by Andrew Madsen on 01/29/24.
//

#ifndef USBCDCInterface_hpp
#define USBCDCInterface_hpp
#include <stdio.h>
#include <USBDriverKit/USBDriverKit.h>
#include <Utilities.hpp>

class CDCDriver;

struct USBCDCInterface {
public:
    USBCDCInterface(CDCDriver *driver,
                    IOUSBHostDevice *device,
                    const IOUSBConfigurationDescriptor *configDesc);
    ~USBCDCInterface();
    
    bool is_valid();
    
    kern_return_t configure_device();
    kern_return_t fetchInterfaces();
    
    kern_return_t openControlEndpoint();
    kern_return_t openDataEndpoints();
    
    kern_return_t sendData(IOBufferMemoryDescriptor *buffer, uint32_t numBytesToSend);
    
    IOBufferMemoryDescriptor *GetReadBuffer(IOReturn status,
                                          uint32_t actualByteCount,
                                          uint64_t completionTimestamp);
    
    kern_return_t pollForData();

    kern_return_t close();
    
    int getBaudRate();
    kern_return_t setBaudRate(uint32_t value);

    bool getDTRHigh();
    kern_return_t setDTRHigh(bool value);

    CDCDriver *driver;
    IOUSBHostDevice *device;
    const IOUSBConfigurationDescriptor *configurationDescription;
    
    IOUSBHostInterface *controlInterface;
    const IOUSBInterfaceDescriptor *controlInterfaceDesc;
    const IOUSBEndpointDescriptor *controlEndpoint;
    
    IOUSBHostInterface *dataInterface;
    const IOUSBInterfaceDescriptor *dataInterfaceDesc;
    const IOUSBEndpointDescriptor *readEndpoint;
    const IOUSBEndpointDescriptor *writeEndpoint;
    
    
private:
    IOUSBHostPipe *controlPipe;
    IOBufferMemoryDescriptor *controlDataBuffer;
    
    IOUSBHostPipe *readPipe;
    IOUSBHostPipe *writePipe;
    IOBufferMemoryDescriptor *readDataBuffer;
    IOBufferMemoryDescriptor *writeDataBuffer;
    OSAction *readAction;
    
    uint32_t baudRate;
    kern_return_t updateLineCodingState();

    bool dtrHigh;
    kern_return_t updateControlLinesState();
};

#endif /* USBCDCInterface_hpp */
