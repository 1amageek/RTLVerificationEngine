import Foundation
import TimingCore

public struct RTLVerificationConstraintContext: Sendable, Hashable, Codable {
    public var modeIDs: [String]
    public var clockNames: [String]
    public var clockSources: [String]
    public var exceptionCount: Int
    public var exceptionKinds: [String]
    public var asynchronousClockGroups: [[[String]]]
    public var sourceArtifact: RTLVerificationSourceArtifact?

    public init(
        modeIDs: [String] = [],
        clockNames: [String] = [],
        clockSources: [String] = [],
        exceptionCount: Int = 0,
        exceptionKinds: [String] = [],
        asynchronousClockGroups: [[[String]]] = [],
        sourceArtifact: RTLVerificationSourceArtifact? = nil
    ) {
        self.modeIDs = modeIDs.sorted()
        self.clockNames = clockNames.sorted()
        self.clockSources = clockSources.sorted()
        self.exceptionCount = max(0, exceptionCount)
        self.exceptionKinds = Array(Set(exceptionKinds)).sorted()
        self.asynchronousClockGroups = asynchronousClockGroups
            .map { groupSet in
                groupSet.map { Array(Set($0)).sorted() }
                    .filter { !$0.isEmpty }
                    .sorted { $0.joined(separator: "|") < $1.joined(separator: "|") }
            }
            .filter { $0.count > 1 }
            .sorted { lhs, rhs in
                let lhsKey = lhs.reduce(into: [String]()) { result, group in
                    result.append(contentsOf: group)
                }.joined(separator: "|")
                let rhsKey = rhs.reduce(into: [String]()) { result, group in
                    result.append(contentsOf: group)
                }.joined(separator: "|")
                return lhsKey < rhsKey
            }
        self.sourceArtifact = sourceArtifact
    }

    public func containsClock(_ name: String) -> Bool {
        clockNames.contains(name) || clockSources.contains(name)
    }

    public func areAsynchronous(_ lhs: String, _ rhs: String) -> Bool {
        asynchronousClockGroups.contains { groupSet in
            guard let lhsIndex = groupSet.firstIndex(where: { $0.contains(lhs) }),
                  let rhsIndex = groupSet.firstIndex(where: { $0.contains(rhs) }) else {
                return false
            }
            return lhsIndex != rhsIndex
        }
    }

    public static func combine(
        _ sets: [TimingConstraintSet],
        sourceArtifact: RTLVerificationSourceArtifact?
    ) -> RTLVerificationConstraintContext {
        RTLVerificationConstraintContext(
            modeIDs: sets.map(\.modeID),
            clockNames: sets.flatMap { $0.clocks.map(\.name) + $0.generatedClocks.map(\.name) },
            clockSources: sets.flatMap { $0.clocks.map(\.source) + $0.generatedClocks.map(\.source) },
            exceptionCount: sets.reduce(0) { $0 + $1.exceptions.count },
            exceptionKinds: sets.flatMap { $0.exceptions.map { $0.kind.rawValue } },
            asynchronousClockGroups: sets.reduce(into: [[[String]]]()) { result, set in
                for clockGroup in set.clockGroups where clockGroup.kind == .asynchronous {
                    result.append(clockGroup.groups)
                }
            },
            sourceArtifact: sourceArtifact
        )
    }
}
