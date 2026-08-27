//
//  CDCDriverInterface-Private-Bridging.h
//  CDCDriverInterface
//
//  Created by Andrew R Madsen on 3/11/24.
//

#ifndef CDCDriverInterface_Private_Bridging_h
#define CDCDriverInterface_Private_Bridging_h

#import <CDCDriverInterface/DriverClientCommunicationTypes.h>
#import <IOKit/IOKitLib.h> // IOKit is not modular on iPadOS, so can't be imported directly in Swift; this is for compatibility with macOS.
#import <IOKit/IOKitKeys.h>
#import <CDCDriverInterface/ioreturn_strings.h> // Plain C (not Objective-C); shared with the CDCDriver dext target.

#endif /* CDCDriverInterface_Private_Bridging_h */
