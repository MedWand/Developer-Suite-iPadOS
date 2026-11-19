# CDCDriver — DriverKit Template

This is the DriverKit system extension that talks to MedWand hardware over USB at the driver level. It ships as source, not a compiled binary, because Apple's code-signing model requires a system extension's bundle identifier to be nested under, and signed by the same team as, the app that embeds it — a compiled `.dext` built under MedWand's own team cannot simply be dropped into your app. You need to rebuild, re-sign, and embed this yourself.

**Version pairing:** this template is paired with a specific `MedWandSDK` release via the wire-format contract in `MedWandSDK/Sources/CDCDriverWireFormat/` (see below). This copy was extracted for `MedWandSDK` release `0.0.0-3`, and the project's version (`MARKETING_VERSION` 0.0.0, `CURRENT_PROJECT_VERSION` 3) carries the same numbers. Check that the wire-format files match before combining it with a different `MedWandSDK` release.

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

### 1. Your app's bundle identifier and your team (required)

Open `Configuration/Driver.xcconfig`, in this template next to the `CDCDriver/` folder, and edit the two lines at the top:

```
APP_BUNDLE_IDENTIFIER = com.example.YourApp
DEVELOPMENT_TEAM = YOURTEAMID
```

- **`APP_BUNDLE_IDENTIFIER`**: the bundle identifier of the app that will embed the driver. The driver's own identifier is built from it as `<APP_BUNDLE_IDENTIFIER>.CDCDriver`. It has to be nested under your app's identifier (an Apple system-extension requirement, not a MedWand convention); if it is not, embedding fails with "Embedded binary's bundle identifier is not prefixed with the parent app's bundle identifier". The built `.dext` is named after it too.
- **`DEVELOPMENT_TEAM`**: your own Apple Developer team identifier (the ten-character ID shown in your Apple Developer account). Until you set it, the build stops with "Signing for CDCDriver requires a development team".

**Finding your team ID.** It is the ten-character identifier of your Apple Developer team (letters and digits), not the team's name and not your Apple ID. Use whichever of these is handiest:

1. **Apple Developer website:** sign in at [developer.apple.com/account](https://developer.apple.com/account) and open **Membership details**. The **Team ID** is listed there. If you belong to several teams, choose the one you will use for your app and for the DriverKit entitlements in §2 before you read it.
2. **Xcode:** in your **app** project (not the driver project), select the app target ▸ **Signing & Capabilities** and choose your **Team**. Then open the target's **Build Settings** tab and search for `DEVELOPMENT_TEAM`: the value is your team ID.
3. **Terminal, from a signing certificate on this Mac:**
   ```
   security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject
   ```
   The team ID is the **`OU=`** value in the output. (`UID=` is a different identifier, so do not use that one.) If you have several certificates, replace `Apple Development` with the full name of the one you want, as shown in Keychain Access.

Everything else follows from those two lines: the driver's bundle identifier and product name, the entitlements file for each configuration, and Automatic signing (`PROVISIONING_PROFILE_SPECIFIER` is empty; set a profile name there only if you sign manually).

**Set these values in the xcconfig, not in Xcode's Signing & Capabilities or Build Settings tabs.** A value set in Xcode is stored on the target and takes priority over the file, which hides your edit. If a value you set in `Driver.xcconfig` does not take effect, open the target's **Build Settings** tab, choose **Levels** in the column selector, and look for a value on the target level.

The static product-name strings in the Xcode project navigator (the `Products` group entry, and the scheme's `BuildableName`) are cosmetic: Xcode resolves the real build product from `PRODUCT_NAME` at build time regardless of what those display strings say, so there is no need to hunt them down and edit them by hand.

### 2. Apple entitlements you'll need approved, under your own team

- `com.apple.developer.driverkit` and `com.apple.developer.driverkit.transport.usb` (vendor ID capability) — request via Apple Developer portal → your App ID → Additional Capabilities → "DriverKit USB Transport - Vendor ID". Apple's approval turnaround has been reported at 3+ weeks; start this early.
- Once approved, add the capability to your App ID and regenerate your provisioning profile.

### 3. Entitlements content — only relevant if you also ship a macOS host app

`CDCDriver/CDCDriver.entitlements` and `CDCDriver/CDCDriver Release.entitlements` (the **macOS**-only entitlements — used automatically when building for `sdk=macosx*`) contain:

```xml
<key>com.apple.developer.driverkit.userclient-access</key>
<array>
    <string>com.example.YourApp</string>
</array>
```

If you're shipping a macOS companion app, change the placeholder `com.example.YourApp` to your own app's bundle identifier — this is the allowlist of client bundle IDs permitted to open a user client to the driver on macOS.

**The iPadOS entitlements files (`CDCDriver iPadOS.entitlements`, `CDCDriver iPadOS Release.entitlements`) have no equivalent key and need no change here** — iPadOS uses a different model: your *app* (not the driver) requests the "Communicates With Drivers" capability in Xcode's Signing & Capabilities pane. If you're iPadOS-only, this section doesn't apply to you at all.

### 4. Optional branding (not required, no functional effect)

- `INFOPLIST_KEY_CFBundleDisplayName` (currently "MedWand USB Driver") — shown to end users in Settings → Privacy & Security → System Extensions.
- `IOUserServerName` (currently `com.medwand.CDCDriver`, in both `CDCDriver-Info.plist` and `CDCDriver/Info.plist`) — an internal identifier for the driver's user-space server process. Not required to change; it does not affect the service-name limitation described below.

`CFBundleIdentifier` inside the `IOKitPersonalities` dictionaries in both `Info.plist` files is already parameterized as `$(PRODUCT_BUNDLE_IDENTIFIER)` — it follows the `APP_BUNDLE_IDENTIFIER` you set in §1 automatically; no manual edit needed.

## Known limitation: one template-built driver per device

Every driver built from this template publishes the same IOKit service name, `MedwandCDCDriver` (set in `CDCDriver.cpp`, which you must not modify), and the same `IOUserServerName`. If two apps from different Apple Developer teams, each embedding its own copy of this driver, are installed on one iPad, both drivers match the MedWand hardware and only one of them is launched. The app whose driver was not launched finds the other team's service, and opening it fails with `kIOReturnNotPermitted` (`0xE00002E2`), because DriverKit refuses a user client from a different team.

Until this is addressed in a future release: keep only one app that embeds a driver built from this template on a given device, or, when you see that error, delete the other app and restart the iPad. Changing `IOUserServerName` (§4) does not change which service the SDK looks for.

## Directory layout

```
CDCDriver-Template/
├── CDCDriver/                              CDCDriver.xcodeproj and its target source
├── Configuration/                          Driver.xcconfig holds the two lines you edit (§1)
└── MedWandSDK/Sources/CDCDriverWireFormat/ Version-matched wire-format contract
```

The `MedWandSDK/Sources/...` nesting looks unusual for a standalone template — it's kept intentionally to match the internal repo layout the Xcode project's relative file references already point at (`../MedWandSDK/Sources/CDCDriverWireFormat`), so nothing in `project.pbxproj` needed hand-editing. **Do not rename these folders** or the project will fail to find its files.

## Adding the driver to your app

The template is a complete Xcode project (`CDCDriver.xcodeproj`) that builds the driver extension (a `.dext`). Your app needs to build it, embed it, and have the capability to talk to it. These steps assume you already did §1 above (bundle identifier and team) and that `<YourApp>` is the root folder of your app's repository.

### 1. Copy the template into your repository

Copy the whole `CDCDriver-Template` folder, as one unit, next to your app's project. For example:

```
cp -R /path/to/CDCDriver-Template <YourApp>/MedWandDriver
```

The folder's own name does not matter, so rename `CDCDriver-Template` to whatever suits you (the examples here use `MedWandDriver`). **Keep the three folders inside it together and unrenamed:** `CDCDriver/`, `Configuration/` and `MedWandSDK/`. The driver project refers to the other two by relative path (see *Directory layout*), so splitting them up, or copying them next to a `Configuration/` or `MedWandSDK/` folder that is already in your repository, breaks the project.

You end up with `<YourApp>/MedWandDriver/CDCDriver/CDCDriver.xcodeproj`.

### 2. Add the driver project to your app project

1. Open your app project in Xcode. If `CDCDriver.xcodeproj` is open on its own, close it first.
2. Choose **File ▸ Add Files to "<YourApp>"…** and select `MedWandDriver/CDCDriver/CDCDriver.xcodeproj`.
3. Uncheck **Copy items if needed** (the project must stay where it is, because of its relative paths) and tick no targets, then choose **Add**.

The driver project now appears, nested, in your project navigator.

### 3. Make your app build the driver first

Select your app target ▸ **Build Phases** ▸ **Dependencies** ▸ **+**, and choose the `CDCDriver` target from the nested project.

### 4. Embed the driver in your app

1. Select your app target ▸ **Build Phases** ▸ **+** ▸ **New Copy Files Phase**, and name it "Embed System Extensions".
2. Set its **Destination** to **System Extensions** and leave the subpath empty.
3. Choose **+**, expand the nested `CDCDriver` project ▸ **Products**, and add the `.dext`. Leave **Code Sign On Copy** off: the driver signs itself when it is built, under the team you set in §1.

### 5. Give your app the capability to talk to the driver

Select your app target ▸ **Signing & Capabilities** ▸ **+ Capability** ▸ **Communicates With Drivers**.

### 6. Build and check

Build for a physical iPad (the driver does not run in the Simulator). In the built app (right-click the product ▸ **Show in Finder**, then **Show Package Contents**) there should be a `SystemExtensions` folder containing your `.dext`. After you install the app, the system asks you to approve the extension on the iPad, as the `SampleSwiftUIApp` in this repository does.

`SampleSwiftUIApp` is set up this way, if you want to compare: its project references the driver project, depends on the `CDCDriver` target, and embeds the `.dext` in a "Embed System Extensions" phase.

## Using the driver from your app

Your app contains no DriverKit or IOKit code and does not import `CDCDriverInterface`. `MedWandSDK` finds the running driver, opens it, and talks to it for you. Your app creates two objects and calls the controller's methods in a fixed order. The code below is abridged from `SampleSwiftUIApp/SampleSwiftUIApp/AppViewModel.swift`; read that file for the full version.

### Before you run it

All of these must be true, or the SDK will not find the driver:

1. The `.dext` is embedded in your app (*Adding the driver to your app* above) and the app was installed on a physical iPad from a build signed under your team, with the entitlements from §2 approved.
2. The driver is enabled in the iPad's **Settings** app. It is listed under its display name (`MedWand USB Driver` unless you changed it in §4); you do this once per installation.
3. The MedWand is plugged into the iPad's USB-C port (directly or through a hub).
4. Your app has the **Communicates With Drivers** capability.
5. You have a MedWand-issued license and its public key. `SampleSwiftUIApp` keeps them in `License.swift`, copied from `License.swift.example`.

### Step 1: create the controller once per launch, and keep it

`MWiPadOSSerialPortProvider` watches for the driver and the MedWand. Its initializer is `async`, so the controller cannot exist before it. The controller keeps a reference to the provider, so you only need to keep the controller.

**Keep the controller in a stored property of an object that lives as long as your app uses the MedWand. Do not create it in a local variable of a function that returns.** A controller that is released stops watching the driver, and its `deinit` cannot close the connection to the MedWand (it can only cancel tasks), so the connection can be left open and a later connect can fail. `SampleSwiftUIApp` does it like this:

```swift
import MedWandSDK

@MainActor
final class MedWandModel {
    let controller: MedWandController          // lives as long as this object does

    private init(controller: MedWandController) { self.controller = controller }

    static func create() async -> MedWandModel {
        let provider = await MWiPadOSSerialPortProvider()
        return MedWandModel(controller: MedWandController(serialPortProvider: provider))
    }
}
```

Create it once (for example in a `.task` on your root view) and keep the result in your app's state. Steps 2 to 4 below call `controller` on that object.

### Step 2: assign the callbacks you need, before you connect

The SDK reports events through closures on the controller. An event raised while a closure is `nil` is dropped, with no replay, so assign them first.

```swift
controller.onDeviceStateChanged = { state in /* .notConnected, .connected, .initialized, .error, … */ }
controller.onDeviceError        = { error in /* error.code and error.message */ }
controller.onLicenseError       = { state in /* .invalid, .expiring, … */ }
controller.onReadingReceived    = { reading in /* reading.sensorType says whose it is */ }
```

**Keep callbacks short.** The SDK calls each callback on a thread of Swift's cooperative thread pool. That pool has about one thread per CPU core and is shared by every `await` in your app. A callback that blocks (it waits on a semaphore or a lock, sleeps, or does synchronous file or network work) holds one of those threads until it returns, and if enough callbacks are blocked, every task in your app stalls, not only the MedWand's. Do the minimum in the callback: store the value, or hand it to your own task or queue, and do long work elsewhere. A slow callback also delays the later values of the same callback, because each callback receives its values one at a time, in order.

### Step 3: validate the license, connect, initialize, configure

Do these in order, and check the result of each before going on. `construct` reports problems on `onLicenseError` and does not throw. `connect` and `initialize` throw `MedWandDeviceError` with the code `.licenseInvalid` if the license is not valid; every other failure is reported on `onDeviceError` and shows as the state the next check sees.

```swift
await controller.construct(license: mwSDKLicense, publicKey: mwSDKPublicKey)
guard await controller.isLicenseValid else { /* show "license is not valid" */ return }

try await controller.connect()      // finds the driver's service, opens it, reads the device's identity
guard await controller.isConnected else { /* show "MedWand not found" */ return }

try await controller.initialize()
guard await controller.isInitialized else { /* show "did not initialize" */ return }

await controller.configure(ecgLayer: ECGLayerHandle(layer: ecgLayer))   // creates the modules your license allows
```

Pass `configure()` no argument if you do not use the ECG.

### Step 4: use a sensor

Start a sensor, receive its readings on `onReadingReceived`, and stop it. Only one sensor runs at a time.

```swift
let started: Bool = await controller.startThermometer()   // false if it could not start; see onDeviceError
// readings arrive on controller.onReadingReceived
try await controller.stopSensor()
```

`SampleSwiftUIApp/SampleSwiftUIApp/ViewModels/SimpleSensorViewModel.swift` is the smallest complete example of start, readings and stop.

### When you are done

Call `await controller.shutdown()` before you release the controller, for example when your app moves to the background or the object that owns it goes away. It stops the background tasks, closes the connection to the MedWand and clears the callbacks. (`disconnect()` ends the connection but leaves the controller usable. `shutdown()` is final: create a new controller to start again.)

### If the MedWand is unplugged

`onDeviceStateChanged` reports `.notConnected` while you were connected. The SDK does not reconnect by itself: reset your UI and, when the MedWand is plugged in again, run step 3 again. The Sample's `handleDeviceLost()` does this.

### If it does not connect

| What you see | Likely cause |
|---|---|
| `connect()` finishes with `isConnected == false`, and `onDeviceError` reports `.deviceNotFound` ("MedWand device not found.") | The driver is not running or the MedWand is not seen. Check each item in *Before you run it*. `provider.isMedWandPluggedIn` is `true` when the driver has matched the MedWand: if it stays `false` with the MedWand plugged in, the driver is not loaded. |
| `onDeviceError` reports `.serialPortOpenError` with the message `kIOReturnNotPermitted` | Your app lacks the **Communicates With Drivers** capability, or another app on the same iPad carries a driver built from this template under a different team (see *Known limitation*). |
| `onDeviceError` reports `.serialPortOpenError` with "MedWand opened, but did not return firmware and device id information." | The port opened but the MedWand did not answer. Unplug it, plug it in again, and retry. |
| `connect()` or `initialize()` throws `.licenseInvalid`, or `onLicenseError` reports `.invalid` | The license or public key is missing, malformed, or does not match, or the license has expired (an expired license is reported as `.invalid`). |

`SampleSwiftUIApp` also needs `License.swift` and a driver project before it builds as intended; see its notes in the top-level README.

## Setup checklist

1. Edit the two lines in `Configuration/Driver.xcconfig` (§1 above): your app's bundle identifier and your team.
2. Request and wait for the DriverKit entitlements in §2, under your own Apple Developer team.
3. If shipping macOS too, update the entitlement in §3.
4. Add the template to your app and embed the driver in it: see *Adding the driver to your app* above.
5. Add the "Communicates With Drivers" capability to your app's own target (Signing & Capabilities → search "communicates with drivers").
6. Link `MedWandSDK` (see the top-level repo README) and follow *Using the driver from your app* above. You write no DriverKit code in your app, and you do not import `CDCDriverInterface`: `MedWandSDK` finds and opens the driver for you.
