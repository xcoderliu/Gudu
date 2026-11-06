// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RippleCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "RippleCore", targets: ["RippleCore"])],
    targets: [
        .target(name: "RippleCore"),
        .testTarget(name: "RippleCoreTests", dependencies: ["RippleCore"])
    ]
)
