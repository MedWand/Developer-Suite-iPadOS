# CDCDriver — DriverKit Template

This is the DriverKit system extension that talks to MedWand hardware over USB at the driver level. It ships as source, not a compiled binary, because Apple's code-signing model requires a system extension's bundle identifier to be nested under, and signed by the same team as, the app that embeds it — a compiled `.dext` built under MedWand's own team cannot simply be dropped into your app. You need to rebuild, re-sign, and embed this yourself.

**Version pairing:** this template is paired with a specific `MedWandSDK` release via the wire-format contract in `MedWandSDK/Sources/CDCDriverWireFormat/` (see below). Check the version note that shipped alongside this template before combining it with a different `MedWandSDK` release.

## Do not modify

These files implement the actual driver — the USB CDC protocol handling and the wire-format contract shared with `MedWandSDK`. They carry a "DO NOT MODIFY" banner at the top of each file as a reminder, but the full list is here too:

- `CDCDriver/CDCDriver.cpp`, `CDCDriver/CDCDriver.iig`
- `CDCDriver/CDCDriverClient.cpp`, `CDCDriver/CDCDriverClient.iig`
- `CDCDriver/USBCDCInterface.cpp`, `CDCDriver/USBCDCInterface.hpp`
- `CDCDriver/Utilities.cpp`, `CDCDriver/Utilities.hpp`
- `MedWandSDK/Sources/CDCDriverWireFormat/` (the entire folder) — this is a version-matched copy of the same wire-format contract compiled into `MedWandSDK`'s `CDCDriverInterface`. Changing it here without a matching `MedWandSDK` change will break communication between your app and the driver.

Also do not change these specific fields, wherever they appear (`CDCDriver-Info.plist`, `CDCDriver/Info.plist`, both `CDCDriver iPadOS*.entitlements` files) — they identify the physical MedWand USB hardware, not your app:

- `idVendor` (`2922`) and `idProduct` (`60`)
- `bConfigurationValue`, `bInterfaceNumber`
- `IOUserClass` / `UserClientProperties.IOUserClass` (`CDCDriver` / `CDCDriverClient` — these name the actual C++ classes above)

## What you need to change

### 1. Bundle identifier, team, and provisioning (required)

**Important:** `Configuration/Common.xcconfig` defines `DEVELOPMENT_TEAM` and `ORGANIZATION_IDENTIFIER`, but for this target those values are *overridden* by settings written directly on the target in `CDCDriver.xcodeproj` — editing the xcconfig alone will not change what actually gets signed. Make these changes in Xcode itself (Signing & Capabilities tab, and Build Settings tab, for **both** Debug and Release configurations):

- **`PRODUCT_BUNDLE_IDENTIFIER`** — currently `com.medwand.FunctionalTest.CDCDriver`. Change to `<your-app's-bundle-id>.CDCDriver` (it must be nested under your own app's bundle identifier — this is an Apple system-extension requirement, not a MedWand convention).
- **`PRODUCT_NAME`** — currently matches the bundle identifier string; update it alongside the bundle ID for consistency (cosmetic — Xcode names the built `.dext` from this, but won't fail to build if you skip it).
- **`DEVELOPMENT_TEAM`** — currently `4UU7YF3L7J` (MedWand's team). Change to your own Apple Developer team ID, in both the Debug config and the Release config's `DEVELOPMENT_TEAM[sdk=driverkit*]` variant.
- **`PROVISIONING_PROFILE_SPECIFIER[sdk=driverkit*]`** (Release only) — currently references a MedWand-only profile name. Either point it at your own provisioning profile, or switch Release to Automatic signing (Debug already uses Automatic — this is the simpler option if you don't need a specific manual profile).

The static product-name strings in the Xcode project navigator (the `Products` group entry, and the scheme's `BuildableName`) are cosmetic — Xcode resolves the real build product from `PRODUCT_NAME` at build time regardless of what those display strings say, so there's no need to hunt them down and edit them by hand.

### 2. Apple entitlements you'll need approved, under your own team

- `com.apple.developer.driverkit` and `com.apple.developer.driverkit.transport.usb` (vendor ID capability) — request via Apple Developer portal → your App ID → Additional Capabilities → "DriverKit USB Transport - Vendor ID". Apple's approval turnaround has been reported at 3+ weeks; start this early.
- Once approved, add the capability to your App ID and regenerate your provisioning profile.

### 3. Entitlements content — only relevant if you also ship a macOS host app

`CDCDriver/CDCDriver.entitlements` and `CDCDriver/CDCDriver Release.entitlements` (the **macOS**-only entitlements — used automatically when building for `sdk=macosx*`) contain:

```xml
<key>com.apple.developer.driverkit.userclient-access</key>
<array>
    <string>com.medwand.FunctionalTest</string>
</array>
```

If you're shipping a macOS companion app, change `com.medwand.FunctionalTest` to your own app's bundle identifier — this is the allowlist of client bundle IDs permitted to open a user client to the driver on macOS.

**The iPadOS entitlements files (`CDCDriver iPadOS.entitlements`, `CDCDriver iPadOS Release.entitlements`) have no equivalent key and need no change here** — iPadOS uses a different model: your *app* (not the driver) requests the "Communicates With Drivers" capability in Xcode's Signing & Capabilities pane. If you're iPadOS-only, this section doesn't apply to you at all.

### 4. Optional branding (not required, no functional effect)

- `INFOPLIST_KEY_CFBundleDisplayName` (currently "MedWand USB Driver") — shown to end users in Settings → Privacy & Security → System Extensions.
- `IOUserServerName` (currently `com.medwand.CDCDriver`, in both `CDCDriver-Info.plist` and `CDCDriver/Info.plist`) — an internal identifier for the driver's user-space server process. Not required to change, but using your own reverse-DNS string avoids any (unlikely) collision if a user's device also runs an actual MedWand app.

`CFBundleIdentifier` inside the `IOKitPersonalities` dictionaries in both `Info.plist` files is already parameterized as `$(PRODUCT_BUNDLE_IDENTIFIER)` — it follows your bundle identifier change from §1 automatically; no manual edit needed.

## Directory layout

```
CDCDriver-Template/
├── CDCDriver/                              CDCDriver.xcodeproj and its target source
├── Configuration/                          Shared xcconfig files the project references
└── MedWandSDK/Sources/CDCDriverWireFormat/ Version-matched wire-format contract
```

The `MedWandSDK/Sources/...` nesting looks unusual for a standalone template — it's kept intentionally to match the internal repo layout the Xcode project's relative file references already point at (`../MedWandSDK/Sources/CDCDriverWireFormat`), so nothing in `project.pbxproj` needed hand-editing. **Do not rename these folders** or the project will fail to find its files.

## Setup checklist

1. Make the changes in §1 above (bundle ID, team, provisioning) for both Debug and Release.
2. Request and wait for the DriverKit entitlements in §2, under your own Apple Developer team.
3. If shipping macOS too, update the entitlement in §3.
4. Build `CDCDriver.xcodeproj`, embed the resulting `.dext` in your own app's target (a copy-files build phase into `SystemExtensions`, matching how `FunctionalTest` embeds this same driver internally).
5. Add the "Communicates With Drivers" capability to your app's own target (Signing & Capabilities → search "communicates with drivers").
6. Link `MedWandSDK` (see the top-level repo README) and use `CDCDriverInterface`'s client API to open the user client — you do not write any DriverKit code in your app itself.
