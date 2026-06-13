// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "menubar-temp",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "menubar-temp",
            linkerSettings: [
                .linkedFramework("IOKit"),
            ]
        ),
    ]
)
