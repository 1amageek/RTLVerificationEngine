// swift-tools-version: 6.3
import PackageDescription
import Foundation

let workspaceRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let isLSIWorkspace = FileManager.default.fileExists(
    atPath: workspaceRoot.appendingPathComponent("docs/workspace-packages.json").path
)

let circuiteFoundationDependency: Package.Dependency = isLSIWorkspace && FileManager.default.fileExists(
    atPath: workspaceRoot.appendingPathComponent("CircuiteFoundation/Package.swift").path
)
    ? .package(path: "../CircuiteFoundation")
    : .package(url: "https://github.com/1amageek/CircuiteFoundation.git", revision: "dc792c88e189c822c9f83ea86cf139ee68560dca")

let logicDesignDependency: Package.Dependency = isLSIWorkspace && FileManager.default.fileExists(
    atPath: workspaceRoot.appendingPathComponent("LogicDesign/Package.swift").path
)
    ? .package(path: "../LogicDesign")
    : .package(url: "https://github.com/1amageek/LogicDesign.git", revision: "e8f8e1dace0445ddd816929c4ca0fe17cca12a7b")

let timingEngineDependency: Package.Dependency = isLSIWorkspace && FileManager.default.fileExists(
    atPath: workspaceRoot.appendingPathComponent("TimingEngine/Package.swift").path
)
    ? .package(path: "../TimingEngine")
    : .package(url: "https://github.com/1amageek/TimingEngine.git", revision: "7809651994017a932314b747b948ac14e32e779b")

let toolQualificationDependency: Package.Dependency = isLSIWorkspace && FileManager.default.fileExists(
    atPath: workspaceRoot.appendingPathComponent("ToolQualification/Package.swift").path
)
    ? .package(path: "../ToolQualification")
    : .package(url: "https://github.com/1amageek/ToolQualification.git", revision: "c489783a5673bc2dd0b94c438c2f53a65d9a2d8b")

let logicEngineDependency: Package.Dependency = isLSIWorkspace && FileManager.default.fileExists(
    atPath: workspaceRoot.appendingPathComponent("LogicEngine/Package.swift").path
)
    ? .package(path: "../LogicEngine")
    : .package(url: "https://github.com/1amageek/LogicEngine.git", revision: "f162f844b9e5f29da2307f3620a069cc37255fb6")

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
                .product(name: "PowerIntent", package: "LogicDesign"),
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
            dependencies: [
                "RTLVerificationEngine",
                "RTLVerificationCore",
                .product(name: "LogicIR", package: "LogicDesign"),
                .product(name: "PowerIntent", package: "LogicDesign"),
            ]
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
                .product(name: "PowerIntent", package: "LogicDesign"),
            ],
            resources: [.copy("Fixtures")]
        ),
    ]
)
