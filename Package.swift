// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "minimal-mx-master",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MXGestureBar", targets: ["MXGestureBar"])
    ],
    targets: [
        .target(name: "MXGestureCore"),
        .executableTarget(
            name: "MXGestureBar",
            dependencies: ["MXGestureCore"]
        ),
        .testTarget(
            name: "MXGestureCoreTests",
            dependencies: ["MXGestureCore"]
        )
    ]
)
