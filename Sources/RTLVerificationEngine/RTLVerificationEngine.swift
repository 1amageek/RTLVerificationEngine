import CDCAnalysis
import FormalEquivalence
import Foundation
import RDCAnalysis
import RTLLint
import RTLVerificationCore

public struct RTLVerificationEngine: RTLVerificationExecuting {
    public var lintEngine: any RTLLintExecuting
    public var cdcAnalyzer: any CDCAnalyzing
    public var rdcAnalyzer: any RDCAnalyzing
    public var equivalenceChecker: any FormalEquivalenceChecking

    public init(
        lintEngine: any RTLLintExecuting,
        cdcAnalyzer: any CDCAnalyzing,
        rdcAnalyzer: any RDCAnalyzing,
        equivalenceChecker: any FormalEquivalenceChecking
    ) {
        self.lintEngine = lintEngine
        self.cdcAnalyzer = cdcAnalyzer
        self.rdcAnalyzer = rdcAnalyzer
        self.equivalenceChecker = equivalenceChecker
    }

    public init(environment: RTLVerificationEnvironment) {
        self.init(
            lintEngine: NativeRTLLintEngine(environment: environment),
            cdcAnalyzer: NativeCDCAnalyzer(environment: environment),
            rdcAnalyzer: NativeRDCAnalyzer(environment: environment),
            equivalenceChecker: NativeFormalEquivalenceChecker(environment: environment)
        )
    }

    public func execute(
        _ request: RTLVerificationRequest
    ) async throws -> RTLVerificationResult {
        switch request.analysis {
        case .lint:
            return try await lintEngine.execute(request)
        case .cdc:
            return try await cdcAnalyzer.execute(request)
        case .rdc:
            return try await rdcAnalyzer.execute(request)
        case .formalEquivalence:
            return try await equivalenceChecker.execute(request)
        }
    }
}
