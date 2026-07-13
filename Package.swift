// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "RTLVerificationEngine",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "RTLVerificationCore", targets: ["RTLVerificationCore"]),
        .library(name: "RTLLint", targets: ["RTLLint"]),
        .library(name: "CDCAnalysis", targets: ["CDCAnalysis"]),
        .library(name: "RDCAnalysis", targets: ["RDCAnalysis"]),
        .library(name: "FormalEquivalence", targets: ["FormalEquivalence"]),
        .library(name: "RTLVerificationEngine", targets: ["RTLVerificationEngine"]),
        .executable(name: "rtl-verify", targets: ["RTLVerificationCLI"]),
    ],
    dependencies: [
        .package(path: "../XcircuitePackage"),
        .package(path: "../LogicDesign"),
        .package(path: "../TimingEngine"),
        .package(path: "../ToolQualification"),
        .package(path: "../LogicEngine"),
    ],
    targets: [
        .target(
            name: "RTLVerificationCore",
            dependencies: [
                .product(name: "XcircuitePackage", package: "XcircuitePackage"),
                .product(name: "LogicIR", package: "LogicDesign"),
                .product(name: "SystemVerilogFrontend", package: "LogicDesign"),
                .product(name: "TimingCore", package: "TimingEngine")
            ]
        ),
        .target(
            name: "RTLLint",
            dependencies: [.product(name: "XcircuitePackage", package: "XcircuitePackage"), "RTLVerificationCore"]
        ),
        .target(
            name: "CDCAnalysis",
            dependencies: [.product(name: "XcircuitePackage", package: "XcircuitePackage"), "RTLVerificationCore"]
        ),
        .target(
            name: "RDCAnalysis",
            dependencies: [.product(name: "XcircuitePackage", package: "XcircuitePackage"), "RTLVerificationCore"]
        ),
        .target(
            name: "FormalEquivalence",
            dependencies: [
                .product(name: "XcircuitePackage", package: "XcircuitePackage"),
                "RTLVerificationCore",
                .product(name: "LogicEngineCore", package: "LogicEngine"),
                .product(name: "LogicLowering", package: "LogicEngine"),
                .product(name: "LogicIR", package: "LogicDesign"),
            ]
        ),
        .target(
            name: "RTLVerificationEngine",
            dependencies: ["RTLVerificationCore", "RTLLint", "CDCAnalysis", "RDCAnalysis", "FormalEquivalence", .product(name: "ToolQualification", package: "ToolQualification")]
        ),
        .executableTarget(
            name: "RTLVerificationCLI",
            dependencies: ["RTLVerificationEngine", "RTLVerificationCore", .product(name: "XcircuitePackage", package: "XcircuitePackage"), .product(name: "LogicIR", package: "LogicDesign")]
        ),
        .testTarget(
            name: "RTLVerificationEngineTests",
            dependencies: [
                "RTLVerificationCore",
                "RTLLint",
                "CDCAnalysis",
                "RDCAnalysis",
                "FormalEquivalence",
                "RTLVerificationEngine",
                .product(name: "LogicEngineCore", package: "LogicEngine"),
                .product(name: "LogicLowering", package: "LogicEngine"),
            ],
            resources: [.copy("Fixtures")]
        ),
    ]
)
