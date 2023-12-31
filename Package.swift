// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Clustering",
    platforms: [
        .macOS("11.3")
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Clustering",
            targets: ["Clustering"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/alexandertar/LASwift", .exactItem("0.2.6")),
        .package(url: "https://github.com/Quick/Nimble.git", .upToNextMajor(from: "9.0.0")),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/dehesa/CodableCSV.git", from: "0.6.7")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .binaryTarget(name: "onnxruntime", path: "onnxruntime.xcframework"),
        .binaryTarget(name: "sentencepiece", path: "sentencepiece.xcframework"),
        .target(
            name: "CClustering",
            dependencies: ["onnxruntime", "sentencepiece"]
        ),
        .target(
            name: "Clustering",
            dependencies: ["LASwift", "CClustering"],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "ClusteringTests",
            dependencies: ["Clustering", "Nimble", "onnxruntime", "sentencepiece"]
        )
    ],
    cxxLanguageStandard: CXXLanguageStandard.cxx14
)

#if swift(>=5.6) && os(macOS)
package.targets.append(contentsOf: [
    .executableTarget(
        name: "clustering-cli",
        dependencies: [
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            "Clustering", "LASwift", "CodableCSV"
        ],
        path: "clustering-cli"
    ),
])
#endif
