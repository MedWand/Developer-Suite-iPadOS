# MedWand SDK — External Distribution

This repository is what gets handed to a third-party organization integrating MedWand hardware support into their own iPadOS application.
> **Before you do anything else:** your app's own target must have **C++ and Objective-C Interoperability** enabled (Xcode → your target → Build Settings → search "interoperability" → set to "C++/Objective-C"). This is not optional and not something this package can set for you — skipping it produces a `was built with C++ interoperability enabled` compiler error that has nothing obviously to do with this setting. See step 2 below.
## Requirements

| | |
|---|---|
| **Xcode and Swift** | **Xcode 27.2 (Swift 6.4.2)**, the compiler this release was built with. See *Why the exact Xcode version* below. |
| **Deployment target** | iPadOS 18 or later. |
| **Run destination** | A physical iPad (arm64). The frameworks have no Simulator slice, so a Simulator destination fails with "no library for this platform was found". The SDK needs a real iPad and a MedWand in any case. |
| **Target build setting** | C++ and Objective-C Interoperability set to C++/Objective-C (step 2 below). |
| **Package product** | `MedWandSDK` must be added to your app target under **Frameworks, Libraries, and Embedded Content**. Adding the package to the project is not enough. |

### Why the exact Xcode version

`MedWandSDK` ships as a compiled framework without a Swift module interface (Swift's library-evolution mode, which would remove this limit, is not available to this package). A compiled Swift module can only be imported by the Swift compiler version that built it. With a different Xcode you will see an error such as *Unable to resolve Swift module dependency to a compatible module: 'MedWandSDK'* on the package's own `Glue.swift`, even though your own `import` line looks fine.

To check your compiler, run `xcrun swiftc --version` in Terminal. It should report `swiftlang-6.4.2.1.9` for this release. Each release is rebuilt against the current Xcode, so use the row for the release you add:

| Release | Version tag | Framework build | Swift compiler |
|---|---|---|---|
| Beta 3 | `0.0.0-3` | 0.0.0 (3) | 6.4.2 (Xcode 27.2) |

### Adding the package by URL: the version rule

Version tags have the form `<version>-<build number>`. A beta's tag is `0.0.0-` followed by its build number, which is the beta's own number: Beta 3 is `0.0.0-3`. A release's tag is the release version, a hyphen and its build number, for example `3.0.2-1`; the build number starts again at 1 for each release version.

When you add the package by its Git URL, Xcode asks for a **Dependency Rule**:

- Use the **Exact Version** rule with the tag from the table, for example `0.0.0-3`, or **Up to Next Major Version** starting from `0.0.0-1`, which picks the newest beta.
- **Start a range from a tag that has the hyphen and number, such as `0.0.0-1`, never from plain `0.0.0`** (and, for a release, from `3.0.2-1`, never from `3.0.2`). The hyphen marks a pre-release in Swift package versions, and a range that starts at a plain number skips every pre-release. Xcode then reports *no versions of 'developer-suite-ipados' match the requirement*.
- **Type the tag exactly.** A tag that does not exist, such as `0.0.0-30`, matches nothing and gives the same message.
- Earlier tags named `beta1` and `beta2` (without a version number) also exist. They are not version numbers, so Xcode's version rules ignore them. Use the `0.0.0-N` tags.
- Adding the repository from a folder on your disk (**Add Local…**) shows the package as unversioned. That is normal for a local package, and it uses whatever is in that folder.

## Getting started

### 1. Add the package

Add this repository as a Swift Package dependency, by its URL (see *Requirements* for the version rule) or as a local package from a folder you've copied it to, and add the `MedWandSDK` product to your app target. Nothing else needs adding: the package has no external dependencies.

### 2. Enable C++/Objective-C interoperability on your app target

Xcode → your app target → **Build Settings** → search "interoperability" → **C++ and Objective-C Interoperability** → set to **C++/Objective-C**.

**Why this is required, in one paragraph:** `MedWandSDK` internally uses a component built with C++ interoperability for license verification and system extensions created using DriverKit. Swift's compiler requires any target that even transitively needs to resolve that component's internal representation to also enable C++ interop — and that requirement reaches all the way to your app's own target, not just ours.

### 3. `import MedWandSDK`

That's it for the SDK side — `MedWandLicense`, `CDCDriverInterface`, and `CDCDriverInterface_Private` are internal implementation details of `MedWandSDK` and are never imported directly; you won't see those names in your own code.

### 4. Set up `CDCDriver-Template`

The DriverKit system extension ships as source, not a compiled binary — you rebuild, re-sign, and embed it yourself under your own Apple Developer team and bundle identifier. Follow `CDCDriver-Template/MEDWAND-TEMPLATE-README.md` for the exact checklist. The bundle identifier and team are set by two lines in `Configuration/Driver.xcconfig`.

### 5. Request DriverKit entitlements from Apple, under your own team

`com.apple.developer.driverkit` and the USB transport vendor-ID capability need Apple approval on your own Apple Developer account — this has been reported to take 3+ weeks, so start it well before you need to ship. Detailed in `CDCDriver-Template/MEDWAND-TEMPLATE-README.md`.

### 6. Look at `SampleSwiftUIApp/` for a complete, working example

It links `MedWandSDK` and embeds a `CDCDriver` reconfigured exactly as described above — a real app doing everything this README describes, not just a snippet. You supply the driver: see the note under *Contents* about creating `CDCDriver/` from the template.

## Contents

- `Package.swift` + `Sources/MedWandSDKGlue/` + `Frameworks/*.xcframework` — the compiled MedWandSDK distribution. Internally it's `MedWandSDK.xcframework` plus three small stub frameworks (`MedWandLicense`, `CDCDriverInterface`, `CDCDriverInterface_Private`) needed only for the compiler to resolve `MedWandSDK`'s internal representation, re-exported through one glue target so none of those names are ever visible to consumer source.
- `CDCDriver-Template/` — a reconfigurable template of the DriverKit system extension project. See its own `MEDWAND-TEMPLATE-README.md` for the exact reconfiguration checklist. It ships as source rather than a compiled `.dext` because Apple's system-extension code-signing model requires the extension's bundle identifier to be nested under, and signed by the same team as, the app that embeds it.
- `SampleSwiftUIApp/` — a worked example: a sample iPadOS app that links `MedWandSDK` and embeds a driver reconfigured from `CDCDriver-Template`, the way a real integration does. **The driver itself is not included.** The app's project references `../CDCDriver/CDCDriver.xcodeproj`, so before opening it, create `CDCDriver/` at the root of this repository from `CDCDriver-Template/` (copy `CDCDriver-Template/CDCDriver` to `CDCDriver`; it uses this repository's `Configuration/` folder next to it. Then edit the two lines in `Configuration/Driver.xcconfig`: set `DEVELOPMENT_TEAM` to your own team, and leave `APP_BUNDLE_IDENTIFIER` set to the Sample app's `com.medwand.SampleSwiftUIApp` (the driver's identifier becomes `com.medwand.SampleSwiftUIApp.CDCDriver`, nested under the app's), or change it and the Sample app's bundle identifier to your own). Until then the app's driver reference is unresolved, and Xcode builds the app anyway, without a driver extension, so the app cannot reach the MedWand. The app also needs `SampleSwiftUIApp/SampleSwiftUIApp/License.swift`, which is not published: copy `License.swift.example` to `License.swift` and put in your own MedWand-issued license and its public key (the file is gitignored; never commit it). The app's development team is left empty too: choose your own in Signing & Capabilities for the app target.
