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
    : .package(url: "https://github.com/1amageek/LogicDesign.git", revision: "cc39c974bf14624e6ce29fd8722620385fde0762")

let timingEngineDependency: Package.Dependency = FileManager.default.fileExists(
    atPath: workspaceRoot.appendingPathComponent("TimingEngine/Package.swift").path
)
    ? .package(path: "../TimingEngine")
    : .package(url: "https://github.com/1amageek/TimingEngine.git", revision: "9189b6dba804191d664eeae334fc429fa74ba421")

let toolQualificationDependency: Package.Dependency = FileManager.default.fileExists(
    atPath: workspaceRoot.appendingPathComponent("ToolQualification/Package.swift").path
)
    ? .package(path: "../ToolQualification")
    : .package(url: "https://github.com/1amageek/ToolQualification.git", revision: "81305bc9e603e0fbd6a9bda9084e13d3f59814f0")

let logicEngineDependency: Package.Dependency = FileManager.default.fileExists(
    atPath: workspaceRoot.appendingPathComponent("LogicEngine/Package.swift").path
)
    ? .package(path: "../LogicEngine")
    : .package(url: "https://github.com/1amageek/LogicEngine.git", revision: "68635cf5ea11c8c710ab0aa6efb26aae867d4b97")

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
