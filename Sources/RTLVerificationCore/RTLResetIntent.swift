import Foundation

public struct RTLResetIntent: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public enum Polarity: String, Sendable, Hashable, Codable {
        case activeHigh
        case activeLow
    }

    public enum AssertionMode: String, Sendable, Hashable, Codable {
        case asynchronous
        case synchronous
    }

    public enum ExceptionKind: String, Sendable, Hashable, Codable {
        case staticDuringOperation
        case externallySynchronized
    }

    public struct Domain: Sendable, Hashable, Codable {
        public var resetSignal: String
        public var clockSignal: String
        public var powerDomainID: String
        public var polarity: Polarity
        public var assertionMode: AssertionMode
        public var minimumReleaseStages: Int

        public init(
            resetSignal: String,
            clockSignal: String,
            powerDomainID: String,
            polarity: Polarity,
            assertionMode: AssertionMode,
            minimumReleaseStages: Int
        ) {
            self.resetSignal = resetSignal
            self.clockSignal = clockSignal
            self.powerDomainID = powerDomainID
            self.polarity = polarity
            self.assertionMode = assertionMode
            self.minimumReleaseStages = minimumReleaseStages
        }
    }

    public struct Exception: Sendable, Hashable, Codable {
        public var exceptionID: String
        public var kind: ExceptionKind
        public var resetSignal: String
        public var clockSignal: String
        public var assumptionID: String?
        public var evidenceArtifactID: String?
        public var rationale: String

        public init(
            exceptionID: String,
            kind: ExceptionKind,
            resetSignal: String,
            clockSignal: String,
            assumptionID: String? = nil,
            evidenceArtifactID: String? = nil,
            rationale: String
        ) {
            self.exceptionID = exceptionID
            self.kind = kind
            self.resetSignal = resetSignal
            self.clockSignal = clockSignal
            self.assumptionID = assumptionID
            self.evidenceArtifactID = evidenceArtifactID
            self.rationale = rationale
        }
    }

    public var schemaVersion: Int
    public var domains: [Domain]
    public var exceptions: [Exception]

    public init(
        domains: [Domain],
        exceptions: [Exception] = [],
        schemaVersion: Int = Self.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.domains = domains
        self.exceptions = exceptions
    }

    public func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw RTLVerificationExecutionError.invalidArtifact(
                "Unsupported reset-intent schema version \(schemaVersion)."
            )
        }
        let domainKeys = domains.map { "\($0.resetSignal)@\($0.clockSignal)" }
        guard !domains.isEmpty,
              Set(domainKeys).count == domainKeys.count,
              domains.allSatisfy({
                  !$0.resetSignal.isEmpty
                      && !$0.clockSignal.isEmpty
                      && !$0.powerDomainID.isEmpty
                      && $0.minimumReleaseStages >= 2
              }) else {
            throw RTLVerificationExecutionError.invalidArtifact(
                "Reset intent requires unique reset/clock domains, power-domain identity, and at least two release stages."
            )
        }
        let exceptionIDs = exceptions.map(\.exceptionID)
        guard Set(exceptionIDs).count == exceptionIDs.count,
              exceptions.allSatisfy({
                  !$0.exceptionID.isEmpty
                      && !$0.resetSignal.isEmpty
                      && !$0.clockSignal.isEmpty
                      && !$0.rationale.isEmpty
              }) else {
            throw RTLVerificationExecutionError.invalidArtifact(
                "Reset-intent exceptions require unique IDs, exact reset/clock scope, and rationale."
            )
        }
        let domainKeySet = Set(domainKeys)
        for exception in exceptions {
            guard domainKeySet.contains(
                "\(exception.resetSignal)@\(exception.clockSignal)"
            ) else {
                throw RTLVerificationExecutionError.invalidArtifact(
                    "Reset-intent exception \(exception.exceptionID) does not reference a declared reset domain."
                )
            }
            switch exception.kind {
            case .staticDuringOperation:
                guard exception.assumptionID?.isEmpty == false,
                      exception.evidenceArtifactID == nil else {
                    throw RTLVerificationExecutionError.invalidArtifact(
                        "Static reset exceptions require one assumption ID and no evidence artifact."
                    )
                }
            case .externallySynchronized:
                guard exception.evidenceArtifactID?.isEmpty == false,
                      exception.assumptionID == nil else {
                    throw RTLVerificationExecutionError.invalidArtifact(
                        "Externally synchronized reset exceptions require one evidence artifact ID and no assumption."
                    )
                }
            }
        }
    }
}
