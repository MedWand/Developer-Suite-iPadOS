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
//  Utilities.hpp
//  CDCDriver
//
//  Created by Andrew Madsen on 01/29/24.
//  Copyright © 2024 Medwand, Inc. All rights reserved.
//

#ifndef Utilities_hpp
#define Utilities_hpp

#include <stddef.h>
#include "DriverClientCommunicationTypes.h"

class IOBufferMemoryDescriptor;

#define kReceiveDataTransferBufferSize 4096
#define kTransmitDataTransferBufferSize 256
#define kReceivedDataSegmentSize 256

#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)

#define __Require(assertion, exceptionLabel, tag)                       \
do                                                                      \
{                                                                       \
if ( __builtin_expect(!(assertion), 0) )                                \
{                                                                       \
os_log(OS_LOG_DEFAULT, "%s %s", tag, TOSTRING(assertion));              \
goto exceptionLabel;                                                    \
}                                                                       \
} while ( 0 )

#define __Require_Action(assertion, exceptionLabel, action)             \
do                                                                      \
{                                                                       \
if ( __builtin_expect(!(assertion), 0) )                                \
{                                                                       \
{                                                                       \
action;                                                                 \
}                                                                       \
os_log(OS_LOG_DEFAULT, TOSTRING(assertion));                            \
goto exceptionLabel;                                                    \
}                                                                       \
} while ( 0 )

namespace CDCDriverUtilities {

RawIOBuffer GetRawIOBuffer(IOBufferMemoryDescriptor* buffer);
void PrintBufferContents(RawIOBuffer buffer);

}

#endif /* Utilities_hpp */
