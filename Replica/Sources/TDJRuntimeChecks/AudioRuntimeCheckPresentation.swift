import TDJInterface

/// Optional presentation of this diagnostic's synthetic performance model.
public struct AudioRuntimeCheckPresentation: Sendable {
    public let modelReady: @MainActor @Sendable (ReplicaModel?) -> Void
    public init(modelReady: @escaping @MainActor @Sendable (ReplicaModel?) -> Void) {
        self.modelReady=modelReady
    }
}
