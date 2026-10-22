// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "QRGeneral",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "QRGeneral",
            targets: ["QRGeneral"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "QRGeneral",
            dependencies: [],
            path: "Sources/App"
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["QRGeneral"],
            path: "Tests/AppTests"
        )
    ]
)
