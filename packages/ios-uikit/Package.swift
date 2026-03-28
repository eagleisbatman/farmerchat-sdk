// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FarmerChatUIKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "FarmerChatUIKit",
            targets: ["FarmerChatUIKit"]
        ),
    ],
    targets: [
        .target(
            name: "FarmerChatUIKit",
            path: "Sources/FarmerChatUIKit"
        ),
        .testTarget(
            name: "FarmerChatUIKitTests",
            dependencies: ["FarmerChatUIKit"],
            path: "Tests/FarmerChatUIKitTests"
        ),
    ]
)
