// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Mole",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MoleCore", targets: ["MoleCore"]),
        .library(name: "MoleEngine", targets: ["MoleEngine"]),
        .library(name: "MoleUI", targets: ["MoleUI"]),
        .library(name: "MoleHelper", targets: ["MoleHelper"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MoleCore",
            dependencies: []
        ),
        .testTarget(
            name: "MoleCoreTests",
            dependencies: ["MoleCore"]
        ),
        .target(
            name: "MoleEngine",
            dependencies: ["MoleCore"]
        ),
        .target(
            name: "MoleUI",
            dependencies: ["MoleCore", "MoleEngine"]
        ),
        .target(
            name: "MoleHelper",
            dependencies: ["MoleCore"]
        )
    ]
)
