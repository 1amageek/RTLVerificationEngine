import Foundation
import CircuiteFoundation

public protocol RTLVerificationExecuting: Engine
where Request == RTLVerificationRequest,
      Output == RTLVerificationResult {
}
