import Foundation
import PowerIntent

public struct RTLResetIntentLoader: Sendable {
    public var reader: any RTLArtifactReading

    public init(reader: any RTLArtifactReading) {
        self.reader = reader
    }

    public func load(
        request: RTLVerificationRequest
    ) throws -> (reset: RTLResetIntent, power: PowerIntentDesign)? {
        guard let resetReference = request.resetIntent,
              let powerReference = request.powerIntent else {
            if request.resetIntent != nil || request.powerIntent != nil {
                throw RTLVerificationExecutionError.invalidRequest(
                    "RDC reset intent and canonical power intent must be supplied together."
                )
            }
            return nil
        }
        guard powerReference.designDigest == request.design.designDigest else {
            throw RTLVerificationExecutionError.invalidArtifact(
                "Power-intent design digest does not match the RTL design digest."
            )
        }
        let reset: RTLResetIntent
        let power: PowerIntentDesign
        do {
            reset = try JSONDecoder().decode(
                RTLResetIntent.self,
                from: reader.read(resetReference.artifact)
            )
            power = try JSONDecoder().decode(
                PowerIntentDesign.self,
                from: reader.read(powerReference.artifact)
            )
        } catch let error as RTLVerificationExecutionError {
            throw error
        } catch {
            throw RTLVerificationExecutionError.invalidArtifact(
                "Reset or power intent could not be decoded: \(error.localizedDescription)"
            )
        }
        try reset.validate()
        let powerDomainIDs = power.domains.map(\.id)
        let powerDomainIDSet = Set(powerDomainIDs)
        let referencedPowerDomainIDs = Set(reset.domains.map(\.powerDomainID))
        let referencedPowerDomains = power.domains.filter {
            referencedPowerDomainIDs.contains($0.id)
        }
        let powerElements = referencedPowerDomains.flatMap(\.elements)
        guard Set(powerDomainIDs).count == powerDomainIDs.count,
              power.domains.allSatisfy({ !$0.id.isEmpty }),
              referencedPowerDomains.allSatisfy({ !$0.elements.isEmpty }),
              Set(powerElements).count == powerElements.count,
              reset.domains.allSatisfy({
                  powerDomainIDSet.contains($0.powerDomainID)
              }) else {
            throw RTLVerificationExecutionError.invalidArtifact(
                "Reset intent requires existing canonical power domains with non-empty, non-overlapping element scopes."
            )
        }
        try validateExceptions(reset.exceptions, request: request)
        return (reset, power)
    }

    private func validateExceptions(
        _ exceptions: [RTLResetIntent.Exception],
        request: RTLVerificationRequest
    ) throws {
        for exception in exceptions {
            switch exception.kind {
            case .staticDuringOperation:
                guard let assumptionID = exception.assumptionID,
                      request.assumptions.contains(where: {
                          $0.assumptionID == assumptionID
                              && !$0.statement.isEmpty
                              && !$0.rationale.isEmpty
                      }) else {
                    throw RTLVerificationExecutionError.invalidArtifact(
                        "Static reset exception \(exception.exceptionID) lacks its exact request assumption."
                    )
                }
            case .externallySynchronized:
                guard let artifactID = exception.evidenceArtifactID,
                      let artifact = request.executionInputArtifacts.first(where: {
                          $0.artifactID == artifactID
                              && $0.locator.role == .input
                              && $0.locator.kind == .evidence
                              && $0.locator.format == .json
                      }) else {
                    throw RTLVerificationExecutionError.invalidArtifact(
                        "External reset exception \(exception.exceptionID) lacks one JSON input evidence artifact."
                    )
                }
                let evidence: RTLResetSynchronizationEvidence
                do {
                    evidence = try JSONDecoder().decode(
                        RTLResetSynchronizationEvidence.self,
                        from: reader.read(artifact)
                    )
                } catch let error as RTLVerificationExecutionError {
                    throw error
                } catch {
                    throw RTLVerificationExecutionError.invalidArtifact(
                        "Reset synchronization evidence could not be decoded: \(error.localizedDescription)"
                    )
                }
                try evidence.validate(
                    resetSignal: exception.resetSignal,
                    clockSignal: exception.clockSignal
                )
            }
        }
    }
}
