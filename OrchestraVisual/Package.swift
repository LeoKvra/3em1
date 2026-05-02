// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OrchestraVisual",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "OrchestraVisual", targets: ["OrchestraVisual"]),
    ],
    targets: [
        .executableTarget(
            name: "OrchestraVisual",
            path: "Sources/OrchestraVisual",
            resources: [.copy("Resources/SampleMedia")]
        ),
    ]
)
