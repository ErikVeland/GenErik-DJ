import Foundation

public enum PerformanceCueKind: String, Codable, Sendable { case cue, loop, grid }

public struct PerformanceCue: Codable, Equatable, Sendable {
    public var frame: Double
    public var loopEnd: Double?
    public var kind: PerformanceCueKind?
    public var category: PerformanceCueKind { kind ?? (loopEnd == nil ? .cue : .loop) }
    public init(frame: Double, loopEnd: Double? = nil, kind: PerformanceCueKind? = nil) {
        self.frame=frame; self.loopEnd=loopEnd; self.kind=kind
    }
}

/// Independent performance state with separately retained imported-cue history.
public struct PerformancePreparation: Codable, Sendable {
    public var cues: [String: [Int: PerformanceCue]] = [:]
    public static let quantizeSizes: [Double] = [0.25,0.5,1,4]
    public var quantize: Double = 0.5
    public var slicerQuantize = true
    public var freezeOnLoad = false
    private var waveformScratchAudioValue: Bool?
    public var waveformScratchAudio: Bool {
        get { waveformScratchAudioValue ?? true }
        set { waveformScratchAudioValue = newValue }
    }
    private var recoveryValue: RecoverySettings?
    public var recovery: RecoverySettings {
        get { recoveryValue ?? .init() }
        set { recoveryValue = newValue }
    }
    public var defaultLoopBeats: Double = 4
    public var deckLoopBeats: [String: Double]? = nil
    /// 1/32 to 32 beats, in powers of two.
    public static let loopSizes: [Double] = [0.03125,0.0625,0.125,0.25,0.5,1,2,4,8,16,32]
    /// The next size up (+1) or down (-1), stopping at either end.
    public static func steppedLoopSize(from beats: Double, direction: Int) -> Double {
        let index = loopSizes.firstIndex(of: beats) ?? loopSizes.firstIndex(of: 4)!
        return loopSizes[min(loopSizes.count - 1, max(0, index + direction.signum()))]
    }
    public static func loopSizeLabel(_ beats: Double) -> String {
        beats >= 1 ? "\(Int(beats))" : "1/\(Int((1 / beats).rounded()))"
    }
    public func loopBeats(for deck: DeckID) -> Double { deckLoopBeats?[deck.rawValue] ?? defaultLoopBeats }
    public mutating func setLoopBeats(_ beats: Double, for deck: DeckID) {
        guard Self.loopSizes.contains(beats) else { return }
        if deckLoopBeats == nil { deckLoopBeats=[:] }
        deckLoopBeats?[deck.rawValue]=beats
    }
    public var traktorCueHistory: [String: TraktorPreparationImportHistory]? = nil
    public var gridCueTracks: Set<String>? = []
    @discardableResult public mutating func installTraktorCues(for track: Track) throws -> Bool {
        guard let original = track.traktorPreparation else { return false }
        let existing = cues[track.id] ?? [:]
        let history = traktorCueHistory?[track.id] ?? .init(protectedEmptySlots:
            cues[track.id] == nil ? [] : Set(0..<8).subtracting(existing.keys))
        let plan = try TraktorPreparationMergePlan(reference: original.normalized, track: track,
            existingCues: existing, history: history)
        let changed = cues[track.id] != plan.cues || traktorCueHistory?[track.id] != plan.history
            || gridCueTracks?.contains(track.id) != true
        cues[track.id] = plan.cues
        if traktorCueHistory == nil { traktorCueHistory = [:] }
        traktorCueHistory?[track.id] = plan.history
        if gridCueTracks == nil { gridCueTracks = [] }
        gridCueTracks?.insert(track.id)
        return changed
    }
    public init() {}
    /// First-free allocation is a development policy. Existing cues and deliberate deletions survive reload.
    @discardableResult public mutating func synchronizeGridCue(trackID: String,frame: Double) -> Bool {
        guard frame.isFinite,frame>=0 else { return false }
        var slots=cues[trackID] ?? [:]
        if let slot=slots.keys.sorted().first(where:{ slots[$0]?.category == .grid }) {
            guard slots[slot]?.frame != frame else { return false }
            slots[slot] = .init(frame:frame,kind:.grid); cues[trackID]=slots
            return true
        }
        var initialized=gridCueTracks ?? Set(cues.keys)
        guard !initialized.contains(trackID) else { return false }
        initialized.insert(trackID); gridCueTracks=initialized
        if let slot=(0..<8).first(where:{ slots[$0] == nil }) {
            slots[slot] = .init(frame:frame,kind:.grid); cues[trackID]=slots
        }
        return true
    }
    public static func load(from url: URL) throws -> Self {
        guard FileManager.default.fileExists(atPath:url.path) else { return .init() }
        var value=try JSONDecoder().decode(Self.self,from:Data(contentsOf:url))
        // Earlier development builds exposed unsupported menu values. Preserve their cues,
        // but restore the documented half-beat default for those settings.
        if [0,2,8].contains(value.quantize) { value.quantize=0.5 }
        if value.gridCueTracks == nil { value.gridCueTracks=Set(value.cues.keys) }
        try value.validate(); return value
    }
    public func save(to url: URL) throws {
        try validate()
        try JSONEncoder().encode(self).write(to:url,options:.atomic)
    }
    private func validate() throws {
        try recovery.validate()
        guard traktorCueHistory?.values.allSatisfy({ history in
                  history.previouslyImportedSlots.allSatisfy { (0..<8).contains($0) }
                      && history.protectedEmptySlots.allSatisfy { (0..<8).contains($0) }
              }) ?? true,
              Self.quantizeSizes.contains(quantize),
              Self.loopSizes.contains(defaultLoopBeats),
              (deckLoopBeats?.allSatisfy { DeckID(rawValue:$0.key) != nil && Self.loopSizes.contains($0.value) } ?? true),
              cues.values.allSatisfy({ slots in slots.allSatisfy { slot,cue in
                  (0..<8).contains(slot) && cue.frame.isFinite && cue.frame>=0 &&
                  (cue.loopEnd.map { $0.isFinite && $0>cue.frame } ?? true) &&
                  (cue.category == .loop ? cue.loopEnd != nil : cue.loopEnd == nil)
              } }) else { throw TransportError.invalid }
    }
}
