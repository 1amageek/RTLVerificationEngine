// swift-tools-version: 6.3
import PackageDescription

let circuiteFoundationDependency: Package.Dependency = .package(
    url: "https://github.com/1amageek/CircuiteFoundation.git",
    exact: "26.812.0"
)

let logicDesignDependency: Package.Dependency = .package(
    url: "https://github.com/1amageek/LogicDesign.git",
    exact: "26.812.0"
)

let timingEngineDependency: Package.Dependency = .package(
    url: "https://github.com/1amageek/TimingEngine.git",
    revision: "40de45cc2280384fd963acb1c2a5b12511be97da"
)

let toolQualificationDependency: Package.Dependency = .package(
    url: "https://github.com/1amageek/ToolQualification.git",
    exact: "26.812.0"
)

let logicEngineDependency: Package.Dependency = .package(
    url: "https://github.com/1amageek/LogicEngine.git",
    revision: "5f1bec56b2fb01a74d5a39dfcfadc10a226a581c"
)

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
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationFileSystem", package: "CircuiteFoundation"),
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
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "ToolQualification", package: "ToolQualification"),
                .product(name: "LogicEngineCore", package: "LogicEngine"),
                .product(name: "LogicLowering", package: "LogicEngine"),
                .product(name: "PowerIntent", package: "LogicDesign"),
            ],
            resources: [.copy("Fixtures")]
        ),
    ]
)
