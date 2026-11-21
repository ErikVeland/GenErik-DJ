import SwiftUI
import TDJCore

enum LibraryDeckBeat {
    static func pulse(phase: PlaybackPhase, sourceFrame: Double, timing: BeatTiming?) -> Double {
        guard phase == .playing, sourceFrame.isFinite, let timing else { return 0 }
        let beat = timing.beat(atFrame: sourceFrame)
        guard beat.isFinite else { return 0 }
        let decay = max(0, 1 - (beat - floor(beat)) / 0.36)
        return decay * decay
    }
}

/// Only the playing badge observes the moving renderer snapshot. The library does not tick with it.
@MainActor struct LibraryDeckBadge: View {
    let model: ReplicaModel
    let deck: DeckID
    var showsPlayback = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let playing = showsPlayback && model.controlDisplay[deck].phase == .playing
        let strength: Double = if playing, !reduceMotion, let state = model.playbackSnapshot?[deck] {
            LibraryDeckBeat.pulse(phase: state.phase, sourceFrame: state.sourceFrame, timing: state.timing)
        } else { 0 }
        let shape = RoundedRectangle(cornerRadius: 4)
        Text(deck.rawValue.uppercased())
            .font(.caption.bold())
            .foregroundStyle(playing ? PerformancePalette.cyan : PerformancePalette.secondaryText)
            .frame(width: 22, height: 22)
            .background(shape.fill(PerformancePalette.cyan.opacity(playing ? 0.14 + strength * 0.25 : 0)))
            .overlay {
                if playing {
                    shape.strokeBorder(PerformancePalette.cyan.opacity(0.52 + strength * 0.48))
                }
            }
            .allowsHitTesting(false)
            .accessibilityLabel(Text("Deck \(deck.rawValue.uppercased())"))
            .accessibilityValue(playing ? "Playing" : "Not playing")
            .accessibilityHidden(!showsPlayback)
    }
}
