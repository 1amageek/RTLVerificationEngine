// swift-tools-version: 6.3
import PackageDescription
import Foundation

let workspaceRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()

let circuiteFoundationDependency: Package.Dependency = FileManager.default.fileExists(
    atPath: workspaceRoot.appendingPathComponent("CircuiteFoundation/Package.swift").path
)
    ? .package(path: "../CircuiteFoundation")
    : .package(url: "https://github.com/1amageek/CircuiteFoundation.git", revision: "2ec6ee13a89ac6885be3c26b41a9ee0ef89948ac")

let logicDesignDependency: Package.Dependency = FileManager.default.fileExists(
    atPath: workspaceRoot.appendingPathComponent("LogicDesign/Package.swift").path
)
    ? .package(path: "../LogicDesign")
    : .package(url: "https://github.com/1amageek/LogicDesign.git", revision: "8e0c8c2c63152aa45bf12d943fa034bb1aba0f1e")

let timingEngineDependency: Package.Dependency = FileManager.default.fileExists(
    atPath: workspaceRoot.appendingPathComponent("TimingEngine/Package.swift").path
)
    ? .package(path: "../TimingEngine")
    : .package(url: "https://github.com/1amageek/TimingEngine.git", revision: "5b2f711d355af8a204819c6ed33f98ef722e379c")

let toolQualificationDependency: Package.Dependency = FileManager.default.fileExists(
    atPath: workspaceRoot.appendingPathComponent("ToolQualification/Package.swift").path
)
    ? .package(path: "../ToolQualification")
    : .package(url: "https://github.com/1amageek/ToolQualification.git", revision: "32b031b5322f1ccb0ef78466faab0f895d47c4fd")

let logicEngineDependency: Package.Dependency = FileManager.default.fileExists(
    atPath: workspaceRoot.appendingPathComponent("LogicEngine/Package.swift").path
)
    ? .package(path: "../LogicEngine")
    : .package(url: "https://github.com/1amageek/LogicEngine.git", revision: "5cccdb82e7272b407642aae0708966d62ceffba4")

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
        circuiteFoundationDependency,
        logicDesignDependency,
        timingEngineDependency,
        toolQualificationDependency,
        logicEngineDependency,
    ],
    targets: [
        .target(
            name: "RTLVerificationCore",
            dependencies: [
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "LogicIR", package: "LogicDesign"),
                .product(name: "SystemVerilogFrontend", package: "LogicDesign"),
                .product(name: "TimingCore", package: "TimingEngine")
            ]
        ),
        .target(
            name: "RTLLint",
            dependencies: ["RTLVerificationCore"]
        ),
        .target(
            name: "CDCAnalysis",
            dependencies: ["RTLVerificationCore"]
        ),
        .target(
            name: "RDCAnalysis",
            dependencies: ["RTLVerificationCore"]
        ),
        .target(
            name: "FormalEquivalence",
            dependencies: [
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
            dependencies: ["RTLVerificationEngine", "RTLVerificationCore", .product(name: "LogicIR", package: "LogicDesign")]
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
                .product(name: "ToolQualification", package: "ToolQualification"),
                .product(name: "LogicEngineCore", package: "LogicEngine"),
                .product(name: "LogicLowering", package: "LogicEngine"),
            ],
            resources: [.copy("Fixtures")]
        ),
    ]
)
