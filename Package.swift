// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GuduCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "GuduCore", targets: ["GuduCore"])],
    targets: [
        .target(name: "GuduCore"),
        .testTarget(name: "GuduCoreTests", dependencies: ["GuduCore"])
    ]
)
