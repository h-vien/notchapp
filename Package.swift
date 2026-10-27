// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchChat",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NotchChat", targets: ["NotchChat"])
    ],
    targets: [
        .executableTarget(
            name: "NotchChat",
            path: "Sources/NotchChat"
        ),
        .testTarget(
            name: "NotchChatTests",
            dependencies: ["NotchChat"],
            path: "Tests/NotchChatTests"
        )
    ]
)

