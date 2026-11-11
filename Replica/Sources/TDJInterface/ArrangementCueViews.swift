import SwiftUI
import TDJCore

extension ReplicaModel {
    func arrangementCueTimeline(deck: DeckID) -> ArrangementCueTimeline? {
        guard pendingNativeSelection[deck] == nil, let track = track(deck),
            let arrangement = arrangements[track.id]
        else { return nil }
        let state = playbackSnapshot?[deck]
        return arrangement.cueTimeline(
            frame: state?.sourceFrame ?? 0, continuingFrame: state?.continuingFrame,
            fileEnd: Double(track.analysis.frameCount), sampleRate: track.analysis.sampleRate,
            timing: state?.timing ?? timing(deck),
            reliableGrid: track.preparation.gridIsManual || track.preparation.gridLocked
                || track.analysis.tempoConfidence >= 0.6,
            rate: (state?.performanceRate ?? 1) * (state?.speed ?? 1),
            loopEnd: state?.loopEnabled == true ? state?.loopEnd : nil, slip: state?.fluxEnabled ?? false)
    }
}

extension ArrangementCueKind {
    var symbol: String {
        switch self {
        case .section: "waveform"
        case .build: "arrow.up.right"
        case .drop: "diamond.fill"
        case .breakdown: "arrow.down.right"
        case .vocal: "mic.fill"
        case .mixIn: "arrow.right.to.line"
        case .mixOut: "arrow.right"
        case .drumsEnd: "drum"
        case .musicEnd: "flag.checkered"
        }
    }
    var cueColour: Color {
        switch self {
        case .build: Color(arrangementHex: 0xE9CC70)
        case .drop: Color(arrangementHex: 0xF6AF69)
        case .breakdown: Color(arrangementHex: 0xB69BE8)
        case .vocal: PerformancePalette.cyan
        case .drumsEnd, .musicEnd: .orange
        default: PerformancePalette.secondaryText
        }
    }
}

/**
 * Keeps the next musical change readable without a scrolling sentence or extra control.
 */
struct ArrangementCueBadge: View {
    let cue: ArrangementCue
    var showsBeatMarks = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: cue.heldByLoop ? "repeat" : cue.kind.symbol)
                .foregroundStyle(cue.kind.cueColour.opacity(cue.emphasis))
            Text(cue.label).lineLimit(1)
            if showsBeatMarks, let remaining = cue.remainingBeatMarks, !reduceMotion {
                if cue.estimated { Text("≈").foregroundStyle(.secondary) }
                HStack(spacing: 2) {
                    ForEach(0..<4) { index in
                        Circle().fill(cue.kind.cueColour.opacity(index < remaining ? 0.8 : 0.15))
                            .frame(width: 3, height: 3)
                    }
                }.accessibilityHidden(true)
            } else {
                Text(cue.distance).monospacedDigit().fixedSize()
            }
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel("\(cue.estimated ? "Estimated " : "")\(cue.label). \(cue.distance)")
    }
}

/**
 * Uses the existing time row for a quiet ending cue. Transport state remains explicit.
 */
@MainActor struct ArrangementEndingCue: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    var body: some View {
        if let timeline = model.arrangementCueTimeline(deck: deck) {
            Group {
                if timeline.reverse {
                    Label("Reverse", systemImage: "backward.fill")
                } else if timeline.tail || timeline.ended {
                    Label(timeline.tail ? "Tail" : "Ended", systemImage: "flag.checkered")
                } else {
                    HStack(spacing: 4) {
                        if timeline.slip { Image(systemName: "arrow.uturn.forward").accessibilityLabel("Slip") }
                        ArrangementCueBadge(cue: timeline.ending, showsBeatMarks: false)
                    }
                }
            }.font(.system(size: 10, weight: .medium, design: .monospaced)).lineLimit(1)
        }
    }
}

/**
 * Shares the waveform axis and redraws only with its existing playback updates.
 */
@MainActor struct PerformanceArrangementOverlay: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let track: Track
    let center: Double
    let span: Double
    var overview: Bool
    var body: some View {
        Canvas { context, size in
            guard span > 0, size.width > 0, size.height >= 12,
                let arrangement = model.arrangements[track.id],
                let timeline = model.arrangementCueTimeline(deck: deck)
            else { return }
            let left = center - span / 2
            func x(_ frame: Double) -> Double { (frame - left) / span * size.width }
            for section in arrangement.sections where section.end > left && section.start < left + span {
                let start = max(0, x(section.start))
                let end = min(size.width, x(section.end))
                let colour = Color(arrangementHex: section.colourHex)
                let rail = CGRect(x: start, y: 0, width: max(0, end - start), height: overview ? 3 : 2)
                context.fill(Path(rail), with: .color(colour.opacity(overview ? 0.65 : 0.4)))
            }
            func ribbon(_ cue: ArrangementCue, y: Double, height: Double) {
                guard let end = cue.end, end > left, cue.frame < left + span else { return }
                let start = max(0, x(cue.frame))
                let finish = min(size.width, x(end))
                guard finish > start else { return }
                let rect = CGRect(x: start, y: y, width: finish - start, height: height)
                context.fill(Path(rect), with: .color(cue.kind.cueColour.opacity(cue.estimated ? 0.1 : 0.2)))
                var line = Path()
                line.move(to: .init(x: start, y: y + height / 2))
                line.addLine(to: .init(x: finish, y: y + height / 2))
                context.stroke(
                    line, with: .color(cue.kind.cueColour.opacity(0.6)),
                    style: StrokeStyle(lineWidth: 1, dash: cue.estimated ? [3, 3] : []))
            }
            if let region = timeline.region {
                ribbon(region, y: size.height - 8, height: 6)
                if !overview, size.width >= 32 {
                    context.draw(
                        Text(Image(systemName: region.kind.symbol)).font(.system(size: 10))
                            .foregroundColor(region.kind.cueColour),
                        at: .init(x: min(size.width - 10, max(10, x(region.frame) + 8)), y: size.height - 16))
                }
            }
            guard let next = timeline.next else { return }
            let px = x(next.frame)
            guard px >= 2, px <= size.width - 2 else { return }
            ribbon(next, y: size.height - 8, height: 6)
            let colour = next.kind.cueColour.opacity(next.emphasis)
            var boundary = Path()
            let top = overview || size.height < 40 ? 3.0 : 20.0
            boundary.move(to: .init(x: px, y: top))
            boundary.addLine(to: .init(x: px, y: min(top + 8, size.height - 3)))
            if size.height >= 40 {
                boundary.move(to: .init(x: px, y: size.height - 14))
                boundary.addLine(to: .init(x: px, y: size.height - 9))
            }
            context.stroke(
                boundary, with: .color(colour),
                style: StrokeStyle(lineWidth: 1, dash: next.estimated || next.heldByLoop ? [3, 4] : []))
            guard !overview, size.width >= 32, size.height >= 64 else { return }
            let symbol = Text(Image(systemName: next.kind.symbol)).font(.system(size: 11)).foregroundColor(colour)
            context.draw(symbol, at: .init(x: min(size.width - 10, max(10, px)), y: 11))
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
