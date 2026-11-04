import SwiftUI
import TDJCore

/// Up arrow, loop size, down arrow. Sizes run from 1/32 to 32 beats.
struct LoopSizeStepper: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    var body: some View {
        VStack(spacing: 0) {
            Button {
                model.stepLoopSize(direction: 1, deck: deck)
            } label: {
                Image(systemName: "chevron.up").frame(maxWidth: .infinity, maxHeight: .infinity)
            }.accessibilityLabel("Longer loop on deck \(deck.rawValue.uppercased())")
            Text(PerformancePreparation.loopSizeLabel(model.performance.loopBeats(for: deck))).font(
                .system(size: 22, weight: .medium).monospacedDigit()
            ).frame(maxWidth: .infinity).accessibilityLabel("Loop size")
            Button {
                model.stepLoopSize(direction: -1, deck: deck)
            } label: {
                Image(systemName: "chevron.down").frame(maxWidth: .infinity, maxHeight: .infinity)
            }.accessibilityLabel("Shorter loop on deck \(deck.rawValue.uppercased())")
        }.font(.system(size: 15, weight: .semibold)).foregroundStyle(PerformancePalette.text).bevelPanel(
            cornerRadius: 3)
    }
}

/// Vertical tempo fader with a ± percent readout. Up is faster.
struct DeckTempoFader: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    /// Fader travel, in percent each way.
    var range = 8.0
    var body: some View {
        let percent = model.deckTempoPercent(deck: deck)
        VStack(spacing: 6) {
            Text(String(format: "%+.1f%%", percent)).font(.system(size: 15, weight: .medium).monospacedDigit())
                .foregroundStyle(PerformancePalette.text)
            GeometryReader { geometry in
                let height = max(1, geometry.size.height - 24)
                let position = (1 - (min(range, max(-range, percent)) + range) / (2 * range)) * height
                ZStack(alignment: .top) {
                    Capsule().fill(PerformancePalette.sunken).frame(width: 8).frame(maxHeight: .infinity)
                    Rectangle().fill(Color.white.opacity(0.25)).frame(width: 30, height: 1).offset(y: height / 2 + 12)
                    RoundedRectangle(cornerRadius: 3).fill(
                        LinearGradient(
                            colors: [PerformancePalette.raised, PerformancePalette.frame], startPoint: .top,
                            endPoint: .bottom)
                    ).overlay(Rectangle().fill(Color(white: 0.85)).frame(height: 3).padding(.horizontal, 6)).frame(
                        width: 44, height: 24
                    ).offset(y: position)
                }.frame(maxWidth: .infinity).contentShape(Rectangle()).gesture(
                    DragGesture(minimumDistance: 0).onChanged { value in
                        let fraction = min(1, max(0, (value.location.y - 12) / height))
                        model.setDeckTempo(percent: (0.5 - Double(fraction)) * 2 * range, deck: deck)
                    }
                ).onTapGesture(count: 2) { model.setDeckTempo(percent: 0, deck: deck) }
            }
        }.padding(.vertical, 8).frame(width: 64).bevelPanel(cornerRadius: 4, sunken: true).accessibilityElement()
            .accessibilityLabel("Tempo fader for deck \(deck.rawValue.uppercased())").accessibilityValue(
                String(format: "%+.1f percent", percent)
            ).accessibilityAdjustableAction { direction in
                model.setDeckTempo(percent: percent + (direction == .increment ? 0.1 : -0.1), deck: deck)
            }
    }
}

/// Eight hotcue pads: + on an empty slot sets a cue at the playhead, a set slot recalls it.
/// The red X switches the pads to delete.
struct HotcuePadRow: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    var body: some View {
        let deleting = model.hotcueDeleting.contains(deck)
        HStack(spacing: 6) {
            ForEach(0..<8, id: \.self) { slot in
                let cue = model.track(deck).flatMap { model.performance.cues[$0.id]?[slot] }
                Button {
                    model.cue(slot: slot, deck: deck, delete: deleting)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 3).fill(
                            cue?.sectionColour.map { Color(arrangementHex: $0) }
                                ?? (cue == nil
                                    ? PerformancePalette.raised
                                    : cue?.category == .loop
                                        ? PerformancePalette.syncGreen.opacity(0.75)
                                        : PerformancePalette.cyan.opacity(0.85)))
                        if cue == nil {
                            Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundStyle(
                                PerformancePalette.text)
                        } else {
                            VStack(spacing: 1) {
                                Text("\(slot + 1)").font(.system(size: 15, weight: .bold))
                                if let name = cue?.sectionName {
                                    Text(name).font(.system(size: 8, weight: .bold)).lineLimit(1).minimumScaleFactor(
                                        0.7)
                                }
                            }.foregroundStyle(Color.black.opacity(0.85))
                        }
                    }
                }.accessibilityLabel(
                    "\(deleting ? "Delete" : cue == nil ? "Set" : "Recall") hotcue \(slot + 1) \(cue?.sectionName ?? "") on deck \(deck.rawValue.uppercased())"
                )
            }
            Button {
                if model.hotcueDeleting.remove(deck) == nil { model.hotcueDeleting.insert(deck) }
            } label: {
                Image(systemName: "xmark").font(.system(size: 18, weight: .heavy)).foregroundStyle(
                    PerformancePalette.red
                ).frame(maxWidth: .infinity, maxHeight: .infinity).background(
                    RoundedRectangle(cornerRadius: 3).fill(
                        deleting ? PerformancePalette.red.opacity(0.25) : PerformancePalette.raised))
            }.accessibilityLabel("Delete hotcues on deck \(deck.rawValue.uppercased())")
        }.padding(.horizontal, 8).padding(.vertical, 4).frame(height: 56)
    }
}
