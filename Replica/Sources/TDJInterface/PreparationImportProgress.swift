import Foundation

public struct PreparationImportProgress: Equatable, Sendable {
    public var done: Int
    public var total: Int
    /// A quiet error. Import retries at the next launch or activation.
    public var message: String?
    /// "Importing prepared tracks" or "Analysing".
    public var title: String
    public var isLibraryAnalysis = false
    public init(
        done: Int, total: Int, message: String? = nil, title: String = "Importing prepared tracks",
        isLibraryAnalysis: Bool = false
    ) {
        self.done = done
        self.total = total
        self.message = message
        self.title = title
        self.isLibraryAnalysis = isLibraryAnalysis
    }
    public var text: String {
        if isLibraryAnalysis {
            if let message { return "\(title): \(message)" }
            if total == 0 { return title }
            return "\(title) \(done) of \(total)"
        }
        if let message { return "\(title) paused: \(message)" }
        return done >= total ? "\(title) finished" : "\(title) \(done) of \(total)"
    }
    public var fraction: Double { total > 0 ? min(1, Double(done) / Double(total)) : 0 }
}
