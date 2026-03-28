// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FarmerChatSwiftUI",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "FarmerChatSwiftUI",
            targets: ["FarmerChatSwiftUI"]
        ),
    ],
    targets: [
        .target(
            name: "FarmerChatSwiftUI",
            path: "Sources/FarmerChatSwiftUI"
        ),
        .testTarget(
            name: "FarmerChatSwiftUITests",
            dependencies: ["FarmerChatSwiftUI"],
            path: "Tests/FarmerChatSwiftUITests"
        ),
    ]
)
