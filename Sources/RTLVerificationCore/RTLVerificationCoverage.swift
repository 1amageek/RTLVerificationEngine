import Foundation

public struct RTLVerificationCoverage: Sendable, Hashable, Codable {
    public var language: String
    public var totalConstructs: Int
    public var analyzedConstructs: Int
    public var unsupportedConstructs: [String]
    public var clockDomains: [String]
    public var resetDomains: [String]
    public var resetReleaseDomains: [String]
    public var proofScope: String
    public var limitations: [String]
    public var sourceArtifacts: [RTLVerificationSourceArtifact]
    public var constraintModes: [String]
    public var constrainedClockDomains: [String]
    public var constraintExceptionCount: Int
    public var constraintExceptionKinds: [String]
    public var asynchronousClockGroups: [[[String]]]

    public init(
        language: String = "SystemVerilog subset",
        totalConstructs: Int = 0,
        analyzedConstructs: Int = 0,
        unsupportedConstructs: [String] = [],
        clockDomains: [String] = [],
        resetDomains: [String] = [],
        resetReleaseDomains: [String] = [],
        proofScope: String = "none",
        limitations: [String] = [],
        sourceArtifacts: [RTLVerificationSourceArtifact] = [],
        constraintModes: [String] = [],
        constrainedClockDomains: [String] = [],
        constraintExceptionCount: Int = 0,
        constraintExceptionKinds: [String] = [],
        asynchronousClockGroups: [[[String]]] = []
    ) {
        self.language = language
        self.totalConstructs = max(0, totalConstructs)
        self.analyzedConstructs = max(0, analyzedConstructs)
        self.unsupportedConstructs = unsupportedConstructs
        self.clockDomains = clockDomains
        self.resetDomains = resetDomains
        self.resetReleaseDomains = resetReleaseDomains.sorted()
        self.proofScope = proofScope
        self.limitations = limitations
        self.sourceArtifacts = sourceArtifacts
        self.constraintModes = constraintModes
        self.constrainedClockDomains = constrainedClockDomains
        self.constraintExceptionCount = max(0, constraintExceptionCount)
        self.constraintExceptionKinds = Array(Set(constraintExceptionKinds)).sorted()
        self.asynchronousClockGroups = asynchronousClockGroups
            .map { groupSet in
                groupSet.map { Array(Set($0)).sorted() }
                    .filter { !$0.isEmpty }
                    .sorted { $0.joined(separator: "|") < $1.joined(separator: "|") }
            }
            .filter { $0.count > 1 }
            .sorted { lhs, rhs in
                lhs.flatMap { $0 }.joined(separator: "|") < rhs.flatMap { $0 }.joined(separator: "|")
            }
    }

    private enum CodingKeys: String, CodingKey {
        case language
        case totalConstructs
        case analyzedConstructs
        case unsupportedConstructs
        case clockDomains
        case resetDomains
        case resetReleaseDomains
        case proofScope
        case limitations
        case sourceArtifacts
        case constraintModes
        case constrainedClockDomains
        case constraintExceptionCount
        case constraintExceptionKinds
        case asynchronousClockGroups
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            language: try container.decode(String.self, forKey: .language),
            totalConstructs: try container.decode(Int.self, forKey: .totalConstructs),
            analyzedConstructs: try container.decode(Int.self, forKey: .analyzedConstructs),
            unsupportedConstructs: try container.decode([String].self, forKey: .unsupportedConstructs),
            clockDomains: try container.decode([String].self, forKey: .clockDomains),
            resetDomains: try container.decode([String].self, forKey: .resetDomains),
            resetReleaseDomains: try container.decode(
                [String].self,
                forKey: .resetReleaseDomains
            ),
            proofScope: try container.decode(String.self, forKey: .proofScope),
            limitations: try container.decode([String].self, forKey: .limitations),
            sourceArtifacts: try container.decode(
                [RTLVerificationSourceArtifact].self,
                forKey: .sourceArtifacts
            ),
            constraintModes: try container.decode([String].self, forKey: .constraintModes),
            constrainedClockDomains: try container.decode(
                [String].self,
                forKey: .constrainedClockDomains
            ),
            constraintExceptionCount: try container.decode(
                Int.self,
                forKey: .constraintExceptionCount
            ),
            constraintExceptionKinds: try container.decode(
                [String].self,
                forKey: .constraintExceptionKinds
            ),
            asynchronousClockGroups: try container.decode(
                [[[String]]].self,
                forKey: .asynchronousClockGroups
            )
        )
    }

    public var analyzedFraction: Double {
        guard totalConstructs > 0 else { return 0 }
        return Double(analyzedConstructs) / Double(totalConstructs)
    }
}
