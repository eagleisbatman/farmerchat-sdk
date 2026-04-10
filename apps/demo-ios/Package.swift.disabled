// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FarmerChatDemo",
    platforms: [
        .iOS(.v16),
        .macOS(.v13), // Required by SPM dependency resolution
    ],
    dependencies: [
        .package(path: "../../packages/ios-swiftui"),
        .package(path: "../../packages/ios-uikit"),
    ],
    targets: [
        .executableTarget(
            name: "FarmerChatDemo",
            dependencies: [
                .product(name: "FarmerChatSwiftUI", package: "ios-swiftui"),
                .product(name: "FarmerChatUIKit", package: "ios-uikit"),
            ],
            path: "Sources"
        ),
    ]
)
