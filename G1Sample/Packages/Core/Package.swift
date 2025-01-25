// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Core",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "Core",
            targets: ["CoreSwift"]
        ),
    ],
    targets: [
        .target(
            name: "CoreObjC",
            dependencies: [],
            path: "Sources/CoreObjC",
            publicHeadersPath: "include" // Specify where public headers are located
        ),
        .target(
            name: "CoreSwift",
            dependencies: ["CoreObjC"],
            path: "Sources/CoreSwift"
        )
    ]
)
