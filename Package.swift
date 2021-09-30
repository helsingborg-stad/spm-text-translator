// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TextTranslator",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13)],
    products: [
        .library(
            name: "TextTranslator",
            targets: ["TextTranslator"])
    ],
    dependencies: [

    ],
    targets: [
        .target(
            name: "TextTranslator",
            dependencies: []),
        .testTarget(
            name: "TextTranslatorTests",
            dependencies: ["TextTranslator"])
    ]
)
