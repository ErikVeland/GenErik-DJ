import Foundation

/// Automatic sections use free slots once. Manual cues and deliberate deletions remain authoritative.
public enum SectionCueAllocator {
    public static func allocate(sections: [ArrangementSection], existing: [Int: PerformanceCue],
                                alreadyPrepared: Bool) -> [Int: PerformanceCue] {
        let sections=sections.filter { $0.start.isFinite && $0.start >= 0 && $0.end > $0.start &&
            ($0.role != .unknown || $0.behaviour != .sustaining) }.sorted { $0.start < $1.start }
        var slots=existing
        for slot in slots.keys.sorted() {
            guard var cue=slots[slot], cue.sectionName != nil,
                  let section=sections.first(where:{ abs($0.start-cue.frame) < 1 }) else { continue }
            cue.sectionName=section.label
            cue.sectionColour=section.colourHex
            slots[slot]=cue
        }
        guard !alreadyPrepared else { return slots }
        for section in sections {
            guard !slots.values.contains(where:{ abs($0.frame-section.start) < 1 }) else { continue }
            guard let slot=(0..<8).first(where:{ slots[$0] == nil }) else { break }
            slots[slot] = .init(frame:section.start,sectionName:section.label,sectionColour:section.colourHex)
        }
        return slots
    }
}
