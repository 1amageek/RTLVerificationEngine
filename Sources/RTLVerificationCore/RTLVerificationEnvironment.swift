import Foundation

public struct RTLVerificationEnvironment: Sendable {
    public var reader: any RTLArtifactReading
    public var writer: any RTLArtifactWriting
    public var parser: any RTLVerificationDesignParsing

    public init(
        reader: any RTLArtifactReading,
        writer: any RTLArtifactWriting = InMemoryRTLArtifactStore(),
        parser: any RTLVerificationDesignParsing = SystemVerilogRTLParser()
    ) {
        self.reader = reader
        self.writer = writer
        self.parser = parser
    }
}
