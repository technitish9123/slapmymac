// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SlapMyMac",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "CHIDAccelerometer",
            path: "Sources/CHIDAccelerometer",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("Security")
            ]
        ),

        .executableTarget(
            name: "SlapMyMac",
            dependencies: ["CHIDAccelerometer"],
            path: "Sources/SlapMyMac",
            exclude: [
                "Resources/Info.plist"
            ],
            resources: [
                .copy("Resources/Sounds")
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
