//
//  DriverClientCommunicationTypes.h
//  CDC Driver Testbed
//
//  Created by Andrew Madsen on 01/16/24.
//  Copyright © 2024 Medwand, Inc. All rights reserved.
//

#import <stdint.h>

#ifndef DriverClientCommunicationTypes_h
#define DriverClientCommunicationTypes_h

typedef enum
{
    ExternalMethodType_RegisterReceivedDataCallback,
    ExternalMethodType_SendData,
    NumberOfExternalMethods // Has to be last
} ExternalMethodType;

typedef enum {
    CallbackMessageTypeReceivedData = 1,
    NumberOfCallbackMessageTypes // Has to be last
} CallbackMessageType;

typedef enum
{
    MappedMemoryType_ReceiveDataBuffer = 1,
    MappedMemoryType_TransmitDataBuffer,
    NumberOfMappedMemoryTypes // Has to be last
} MappedMemoryType;

typedef struct {
    uint64_t foo;
    uint64_t bar;
} DataStruct;

struct RawIOBuffer
{
    void* bytes;
    size_t length;
};

#endif /* DriverClientCommunicationTypes_h */
