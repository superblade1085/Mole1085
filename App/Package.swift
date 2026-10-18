// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Mole",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MoleApp", targets: ["MoleApp"]),
        .executable(name: "MoleHelperDaemon", targets: ["MoleHelperDaemon"]),
        .library(name: "MoleCore", targets: ["MoleCore"]),
        .library(name: "MoleEngine", targets: ["MoleEngine"]),
        .library(name: "MoleUI", targets: ["MoleUI"]),
        .library(name: "MoleHelper", targets: ["MoleHelper"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MoleApp",
            dependencies: [
                "MoleCore",
                "MoleEngine",
                "MoleUI"
            ]
        ),
        .executableTarget(
            name: "MoleHelperDaemon",
            dependencies: [
                "MoleCore",
                "MoleHelper"
            ]
        ),
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
        .testTarget(
            name: "MoleEngineTests",
            dependencies: ["MoleEngine", "MoleCore"]
        ),
        .target(
            name: "MoleUI",
            dependencies: ["MoleCore", "MoleEngine"]
        ),
        .testTarget(
            name: "MoleUITests",
            dependencies: ["MoleUI", "MoleEngine", "MoleCore"]
        ),
        .target(
            name: "MoleHelper",
            dependencies: ["MoleCore"],
            resources: [
                .process("LaunchDaemons")
            ]
        ),
        .testTarget(
            name: "MoleHelperTests",
            dependencies: ["MoleHelper", "MoleCore"]
        )
    ]
)
