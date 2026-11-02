import Foundation

/// Audio longer than the mix threshold is treated as a DJ mix: only its opening minute is analysed
/// for tempo, grid and key, and no full waveform pass runs until a deck loads it.
public enum NativeAnalysisPlan: Equatable, Sendable {
    case full, firstMinute
    public static let mixThresholdSeconds=19.0*60
    public static let excerptSeconds=60.0
    public static func plan(duration: Double?) -> Self { isMix(duration:duration) ? .firstMinute : .full }
    public static func isMix(duration: Double?) -> Bool {
        guard let duration, duration.isFinite else { return false }
        return duration > mixThresholdSeconds
    }
}

/// A stored first-minute result for a Music library item. Saved so later passes skip the work.
public struct NativeAnalysisHint: Codable, Equatable, Sendable {
    public var bpm: Double?
    public var beatAnchorSeconds: Double?
    public var downbeatOffset: Int?
    public var key: MusicalKey?
    public var isMix: Bool
    public var analysedSeconds: Double
    public var configurationID: String
    public init(bpm: Double?, beatAnchorSeconds: Double?, downbeatOffset: Int?, key: MusicalKey?, isMix: Bool,
                analysedSeconds: Double, configurationID: String) {
        self.bpm=bpm;self.beatAnchorSeconds=beatAnchorSeconds;self.downbeatOffset=downbeatOffset;self.key=key
        self.isMix=isMix;self.analysedSeconds=analysedSeconds;self.configurationID=configurationID
    }
    public init(excerpt analysis: AudioAnalysis, isMix: Bool) {
        self.init(bpm:analysis.bpm,beatAnchorSeconds:analysis.beatAnchorFrame.map { $0/analysis.sampleRate },
                  downbeatOffset:analysis.detectedDownbeatOffset,key:analysis.key,isMix:isMix,
                  analysedSeconds:analysis.duration,configurationID:analysis.configurationID)
    }
}

/// Persistent first-minute results keyed by Music library source ID.
public struct NativeAnalysisHints: Codable, Equatable, Sendable {
    public var entries: [String:NativeAnalysisHint]=[:]
    public init(entries: [String:NativeAnalysisHint] = [:]) { self.entries=entries }
    public static func load(from url: URL) throws -> Self {
        guard FileManager.default.fileExists(atPath:url.path) else { return .init() }
        return try JSONDecoder().decode(Self.self,from:Data(contentsOf:url))
    }
    public func save(to url: URL) throws { try JSONEncoder().encode(self).write(to:url,options:.atomic) }
}

/// Tempo, key and mix flag the browser can show before a song is fully prepared.
public struct BrowserPreparationHint: Equatable, Sendable {
    public var bpm: Double?
    public var key: MusicalKey?
    public var isMix: Bool
    public init(bpm: Double?, key: MusicalKey?, isMix: Bool) { self.bpm=bpm;self.key=key;self.isMix=isMix }
}
