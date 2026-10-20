# MedWand SDK — External Distribution

This repository is what gets handed to a third-party organization integrating MedWand hardware support into their own iPadOS application.
> **Before you do anything else:** your app's own target must have **C++ and Objective-C Interoperability** enabled (Xcode → your target → Build Settings → search "interoperability" → set to "C++/Objective-C"). This is not optional and not something this package can set for you — skipping it produces a `was built with C++ interoperability enabled` compiler error that has nothing obviously to do with this setting. See step 2 below.
## Getting started

### 1. Add the package

Add this repository as a local Swift Package dependency (or wherever you've copied it) and add the `MedWandSDK` product to your app target. Nothing else needs adding — `swift-nio` resolves automatically as a transitive dependency; you don't add it yourself and you never `import` it.

### 2. Enable C++/Objective-C interoperability on your app target

Xcode → your app target → **Build Settings** → search "interoperability" → **C++ and Objective-C Interoperability** → set to **C++/Objective-C**.

**Why this is required, in one paragraph:** `MedWandSDK` internally uses a component built with C++ interoperability for license verification and system extensions created using DriverKit. Swift's compiler requires any target that even transitively needs to resolve that component's internal representation to also enable C++ interop — and that requirement reaches all the way to your app's own target, not just ours.

### 3. `import MedWandSDK`

That's it for the SDK side — `MedWandLicense`, `CDCDriverInterface`, and `CDCDriverInterface_Private` are internal implementation details of `MedWandSDK` and are never imported directly; you won't see those names in your own code.

### 4. Set up `CDCDriver-Template`

The DriverKit system extension ships as source, not a compiled binary — you rebuild, re-sign, and embed it yourself under your own Apple Developer team and bundle identifier. Follow `CDCDriver-Template/MEDWAND-TEMPLATE-README.md` for the exact checklist (bundle ID, team, provisioning, entitlements, and the one prominent trap it documents: editing `Configuration/Common.xcconfig` alone does *not* change the effective bundle ID or team for this target — see that README for why).

### 5. Request DriverKit entitlements from Apple, under your own team

`com.apple.developer.driverkit` and the USB transport vendor-ID capability need Apple approval on your own Apple Developer account — this has been reported to take 3+ weeks, so start it well before you need to ship. Detailed in `CDCDriver-Template/MEDWAND-TEMPLATE-README.md`.

### 6. Look at `SampleSwiftUIApp/` for a complete, working example

It links `MedWandSDK` and embeds a `CDCDriver` reconfigured exactly as described above — a real app doing everything this README describes, not just a snippet. You supply the driver: see the note under *Contents* about creating `CDCDriver/` from the template.

## Contents

- `Package.swift` + `Sources/MedWandSDKGlue/` + `Frameworks/*.xcframework` — the compiled MedWandSDK distribution. Internally it's `MedWandSDK.xcframework` plus three small stub frameworks (`MedWandLicense`, `CDCDriverInterface`, `CDCDriverInterface_Private`) needed only for the compiler to resolve `MedWandSDK`'s internal representation, re-exported through one glue target so none of those names are ever visible to consumer source. `swift-nio` is a normal external dependency, not bundled.
- `CDCDriver-Template/` — a reconfigurable template of the DriverKit system extension project. See its own `MEDWAND-TEMPLATE-README.md` for the exact reconfiguration checklist. It ships as source rather than a compiled `.dext` because Apple's system-extension code-signing model requires the extension's bundle identifier to be nested under, and signed by the same team as, the app that embeds it.
- `SampleSwiftUIApp/` — a worked example: a sample iPadOS app that links `MedWandSDK` and embeds a driver reconfigured from `CDCDriver-Template`, the way a real integration does. **The driver itself is not included.** The app's project references `../CDCDriver/CDCDriver.xcodeproj`, so before opening it, create `CDCDriver/` at the root of this repository from `CDCDriver-Template/` (copy `CDCDriver-Template/CDCDriver` to `CDCDriver`, with its `Configuration/`, and follow the template's checklist for your own team and bundle identifier; the template's bundle identifier is the placeholder `com.example.YourApp.CDCDriver`, and the driver's must be nested under the app's, so either set it to `com.medwand.SampleSwiftUIApp.CDCDriver` under the Sample app's `com.medwand.SampleSwiftUIApp`, or change both to your own). Until then the app's driver reference is unresolved, and Xcode builds the app anyway, without a driver extension, so the app cannot reach the MedWand. The app also needs `SampleSwiftUIApp/SampleSwiftUIApp/License.swift`, which is not published: copy `License.swift.example` to `License.swift` and put in your own MedWand-issued license and its public key (the file is gitignored; never commit it). The app's development team is left empty too: choose your own in Signing & Capabilities for the app target.
- `THIRD-PARTY-NOTICES.md` — license attribution for swift-nio (Apache 2.0), whose compiled code is statically linked inside `MedWandSDK.xcframework`.
