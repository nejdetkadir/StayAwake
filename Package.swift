// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StayAwake",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "StayAwake",
            linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("IOKit")]
        ),
        .testTarget(
            name: "StayAwakeTests",
            dependencies: ["StayAwake"]
        ),
    ]
)
