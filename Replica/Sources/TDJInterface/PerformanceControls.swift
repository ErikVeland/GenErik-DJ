import SwiftUI
import TDJCore

struct PerformanceControls: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    @State private var settings=false
    @Environment(\.deckPanelPresented) private var presented
    var compact = false
    var body: some View {
        Group {
            if compact {
                HStack(spacing: 6) {
                    fluxButton.frame(minWidth: 50)
                    freezeButton.frame(minWidth: 54)
                    cuesButton.frame(minWidth: 44)
                    loopControls.frame(width: 144)
                    settingsButton.frame(minWidth: 44)
                    if canReturn { returnButton.frame(minWidth: 44) }
                }
            } else {
                VStack(spacing: 8) {
                    HStack(spacing: 8) { fluxButton; settingsButton }
                    HStack(spacing: 8) { freezeButton; cuesButton }
                    loopControls
                    if canReturn { returnButton }
                }
            }
        }
        .font(.system(size: 16, weight: .semibold))
        .buttonStyle(PerformanceToolButtonStyle(fillsHeight: !compact))
        .disabled(model.preparingTrack.contains(deck) || model.controlDisplay[deck].phase == .queued)
        .onChange(of:presented) { _, visible in if !visible { settings=false } }
    }
    private var canReturn: Bool {
        model.previewing.contains(deck) && !model.frozen.contains(deck) && !model.editing.contains(deck)
    }
    private var fluxButton: some View {
            Button("FLUX") { model.perform(.flux,deck:deck,enabled:model.controlDisplay[deck].fluxEnabled != true) }
                .foregroundStyle(model.controlDisplay[deck].fluxEnabled == true ? Color.orange : Color.gray)
                .accessibilityLabel("Flux on deck \(deck.rawValue.uppercased())")
    }
    private var settingsButton: some View {
            Button { settings.toggle() } label: { Image(systemName:"gearshape") }
                .popover(isPresented:$settings) {
                    VStack(alignment:.leading) {
                        PlaybackSettings(model:model)
                        Button("Gesture guide") { settings=false; model.helpVisible=true }
                    }.padding().frame(width:300).onDisappear { model.savePerformance() }
                }
    }
    private var freezeButton: some View {
            Button { model.toggleFreeze(deck:deck) } label: {
                VStack(spacing: 3) {
                    Image(systemName: "snowflake")
                    Text("FREEZE").font(.system(size: 11, weight: .semibold))
                }
            }
                .foregroundStyle(model.frozen.contains(deck) ? Color.cyan : Color.gray)
    }
    private var cuesButton: some View {
            Button { model.toggleHotcuePads(deck:deck) } label: {
                VStack(spacing: 3) {
                    Image(systemName: "flag.fill")
                    Text("CUES").font(.system(size: 11, weight: .semibold))
                }
            }
                .foregroundStyle(model.hotcuePadsVisible.contains(deck) ? Color.cyan : Color.gray)
                .accessibilityLabel("Hotcues for deck \(deck.rawValue.uppercased())")
    }
    private var loopControls: some View {
        HStack(spacing: 6) {
            Button { setLoopSize(direction:-1) } label: { Image(systemName:"minus") }
                .frame(width: 44)
                .accessibilityLabel("Halve loop length on deck \(deck.rawValue.uppercased())")
            Menu {
                ForEach(PerformancePreparation.loopSizes,id:\.self) { beats in
                    Button("\(PerformancePreparation.loopSizeLabel(beats)) beats") { setLoopSize(beats) }
                }
            } label: {
                VStack(spacing: 2) {
                    Text("LOOP").font(.system(size: 12, weight: .semibold))
                    Text(PerformancePreparation.loopSizeLabel(model.performance.loopBeats(for: deck)))
                        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                }.frame(maxWidth: .infinity)
            }
                .accessibilityLabel("Loop length on deck \(deck.rawValue.uppercased())")
            Button { setLoopSize(direction:1) } label: { Image(systemName:"plus") }
                .frame(width: 44)
                .accessibilityLabel("Double loop length on deck \(deck.rawValue.uppercased())")
        }
    }
    private var returnButton: some View {
            Button { model.returnToPlayhead(deck:deck) } label: { Image(systemName:"arrow.uturn.backward") }
                .accessibilityLabel("Return to playhead on deck \(deck.rawValue.uppercased())")
    }
    private func setLoopSize(direction: Int) { model.stepLoopSize(direction:direction,deck:deck) }
    private func setLoopSize(_ beats: Double) { model.setLoopSize(beats,deck:deck) }
}

struct PerformanceToolButtonStyle: ButtonStyle {
    var fillsHeight = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity).frame(minHeight: 48, maxHeight: fillsHeight ? .infinity : nil)
            .contentShape(Rectangle())
            .bevelPanel(cornerRadius: 4, sunken: configuration.isPressed)
    }
}

struct SuperSlicerControls: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    var body: some View {
        VStack(spacing:0) {
            ForEach(SuperSlicerFamily.allCases) { family in
                Button { model.selectSuperSlicerFamily(family,deck:deck) } label: {
                    Image(systemName:family.symbol).font(.system(size:18,weight:.semibold))
                        .frame(width:44).frame(maxHeight:.infinity).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(model.superSlicerFamily(deck:deck) == family ? Color.green : Color.gray)
                .accessibilityLabel("\(family.title) on deck \(deck.rawValue.uppercased())")
                .accessibilityAddTraits(model.superSlicerFamily(deck:deck) == family ? [.isSelected] : [])
            }
        }.frame(width:44).background(.black.opacity(0.3))
            .disabled(model.preparingPlayback.contains(deck) || model.controlDisplay[deck].phase == .queued)
    }
}

@MainActor
struct OptionalHeadphoneButton: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    @AppStorage(DeckToolSettings.headphoneButton) private var visible = false
    var body: some View {
        if visible {
            Button { model.setMixer(.cue,value:model.controlDisplay[deck].mixer.cue ? 0:1,deck:deck) } label: {
                Image(systemName:"headphones")
                    .foregroundStyle(model.controlDisplay[deck].mixer.cue ? PerformancePalette.cyan:PerformancePalette.secondaryText)
            }.accessibilityLabel("Headphone cue for deck \(deck.rawValue.uppercased())")
        }
    }
}

@MainActor
struct TrackHeadphoneIndicator: View {
    @Bindable var model: ReplicaModel
    let trackID: String?
    private var active: Bool {
        guard let trackID else { return false }
        return DeckID.allCases.contains { model.loaded[$0] == trackID && model.controlDisplay[$0].mixer.cue }
    }
    var body: some View {
        if active {
            Image(systemName:"headphones").font(.system(size:18,weight:.bold))
                .foregroundStyle(PerformancePalette.cyan).padding(5)
                .background(.black.opacity(0.85),in:RoundedRectangle(cornerRadius:5))
                .accessibilityLabel("Headphone cue active")
                .allowsHitTesting(false)
        }
    }
}
