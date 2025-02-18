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
    dependencies: [
        .package(url: "https://github.com/SVProgressHUD/SVProgressHUD", .upToNextMajor(from: "2.3.1"))
    ],
    targets: [
        .target(
            name: "CoreObjC",
            dependencies: [],
            path: "Sources/CoreObjC",
            publicHeadersPath: "include"
        ),
        .target(
            name: "CoreSwift",
            dependencies: ["CoreObjC", "SVProgressHUD"],
            path: "Sources/CoreSwift"
        )
    ]
)
