import Foundation
import CircuiteFoundation
import XcircuitePackage

public protocol RTLVerificationExecuting: Engine
where Request == RTLVerificationRequest,
      Output == XcircuiteEngineResultEnvelope<RTLVerificationPayload> {
}
