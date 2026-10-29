// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Hisaab",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HisaabCore", targets: ["HisaabCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "HisaabCore",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")],
            path: "src/core"
        ),
        .testTarget(
            name: "HisaabCoreTests",
            dependencies: ["HisaabCore"],
            path: "tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
