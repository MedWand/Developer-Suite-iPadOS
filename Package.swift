// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MedWandSDK",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "MedWandSDK", targets: ["MedWandSDKGlue"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0")
    ],
    targets: [
        .binaryTarget(name: "MedWandSDKBinary", path: "Frameworks/MedWandSDK.xcframework"),
        .binaryTarget(name: "MedWandLicenseBinary", path: "Frameworks/MedWandLicense.xcframework"),
        .binaryTarget(name: "CDCDriverInterfaceBinary", path: "Frameworks/CDCDriverInterface.xcframework"),
        .binaryTarget(name: "CDCDriverInterfacePrivateBinary", path: "Frameworks/CDCDriverInterface_Private.xcframework"),
        .target(
            name: "MedWandSDKGlue",
            dependencies: [
                "MedWandSDKBinary",
                "MedWandLicenseBinary",
                "CDCDriverInterfaceBinary",
                "CDCDriverInterfacePrivateBinary",
                .product(name: "NIOCore", package: "swift-nio")
            ],
            path: "Sources/MedWandSDKGlue",
            swiftSettings: [.interoperabilityMode(.Cxx)]
        )
    ]
)
