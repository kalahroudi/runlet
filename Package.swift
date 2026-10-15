// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RunLet",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "RunLet", targets: ["RunLet"])],
    targets: [
        .target(name: "RunLetCore"),
        .executableTarget(name: "RunLet", dependencies: ["RunLetCore"]),
        .testTarget(name: "RunLetCoreTests", dependencies: ["RunLetCore"]),
    ]
)
