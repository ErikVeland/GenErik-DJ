import Foundation

public struct MixerPreferences: Codable, Equatable, Sendable {
    public var filterResonanceA = 0.0
    public var filterResonanceB = 0.0
    public var syncA: Bool?
    public var syncB: Bool?
    public var syncC: Bool?
    public var syncD: Bool?
    public var primaryKeylock: Bool?
    public init() {}
    private func validate() throws {
        guard [filterResonanceA, filterResonanceB].allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
            throw CoreError.invalidWorkspace("Invalid saved filter resonance.")
        }
    }
    public static func load(from url: URL) throws -> Self {
        guard FileManager.default.fileExists(atPath: url.path) else { return .init() }
        let value = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        try value.validate()
        return value
    }
    public func save(to url: URL) throws {
        try validate()
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}
