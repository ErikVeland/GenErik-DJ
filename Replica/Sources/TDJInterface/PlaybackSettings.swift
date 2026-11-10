import SwiftUI
import TDJCore

#if os(iOS)
    import UIKit
#endif

struct SettingsGroup<Content: View>: View {
    let title: String
    private let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline).foregroundStyle(PerformancePalette.text)
            content
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(PerformancePalette.frame.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
            .tint(PerformancePalette.cyan)
    }
}

struct PlaybackSettings: View {
    @Bindable var model: ReplicaModel
    @AppStorage(BrowserSettings.onlyLoadToOffAirDecksKey) private var protectPlayingDecks = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsGroup("Loading tracks") {
                Toggle("Protect playing decks", isOn: $protectPlayingDecks)
                Text("Prevents loading another track onto a playing deck.").font(.caption).foregroundStyle(.secondary)
                Toggle("Keylock on load", isOn: $model.primaryKeylockEnabled)
                Text("Keeps pitch steady when tempo changes. Applies to the next track loaded on A or B.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Freeze on load", isOn: preference(\.freezeOnLoad))
            }
            SettingsGroup("Loop defaults") {
                Picker("Fallback loop length", selection: preference(\.defaultLoopBeats)) {
                    ForEach(PerformancePreparation.loopSizes, id: \.self) { beats in
                        Text("\(PerformancePreparation.loopSizeLabel(beats)) beats").tag(beats)
                    }
                }
                Text("Used until you choose a loop length for that deck. Change live loops in the utility drawer.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            SettingsGroup("Timing · all decks") { QuantizeSettings(model: model) }
            SettingsGroup("Stop behaviour · all decks") { VinylStopSettings() }
            SettingsGroup("At track end · all decks") { RecoverySettingsView(model: model) }
        }
    }
    private func preference<Value>(_ key: WritableKeyPath<PerformancePreparation, Value>) -> Binding<Value> {
        Binding(
            get: { model.performance[keyPath: key] },
            set: {
                model.performance[keyPath: key] = $0
                model.savePerformance()
            })
    }
}

struct QuantizeSettings: View {
    @Bindable var model: ReplicaModel
    var body: some View {
        Picker(
            "Quantise to",
            selection: Binding(
                get: { model.performance.quantize },
                set: {
                    model.performance.quantize = $0
                    model.savePerformance()
                })
        ) {
            Text("¼ beat").tag(0.25)
            Text("½ beat").tag(0.5)
            Text("1 beat").tag(1.0)
            Text("1 bar").tag(4.0)
        }
        Toggle(
            "Quantise slicer",
            isOn: Binding(
                get: { model.performance.slicerQuantize },
                set: {
                    model.performance.slicerQuantize = $0
                    model.savePerformance()
                }))
    }
}

struct VinylStopSettings: View {
    @AppStorage(DeckToolSettings.vinylStop) private var enabled = false
    @AppStorage(DeckToolSettings.vinylStopDuration) private var duration = 1.0
    var body: some View {
        Toggle("Vinyl stop", isOn: $enabled)
        if enabled {
            HStack {
                Text("Stop time")
                Slider(value: $duration, in: 0.2...5, step: 0.1).accessibilityLabel("Vinyl stop time")
                Text(String(format: "%.1f s", duration)).monospacedDigit()
            }
        }
    }
}

struct LayoutSettings: View {
    @AppStorage(DeckToolSettings.sectionWaveformColours) private var colours = true
    @AppStorage(DeckToolSettings.beatJump) private var beatJump = false
    @AppStorage(DeckToolSettings.tempoFader) private var tempo = false
    @AppStorage(DeckToolSettings.cueButton) private var cue = false
    @AppStorage(DeckToolSettings.headphoneButton) private var headphones = false
    @AppStorage(DeckToolSettings.largePanelHandles) private var handles = false
    @AppStorage(BrowserSettings.superSlicerKey) private var slicer = true
    @AppStorage(BrowserSettings.notificationCenterKey) private var notifications = true
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsGroup("Show on the decks") {
                Toggle("Beat Jump", isOn: $beatJump)
                Toggle("Tempo fader", isOn: $tempo)
                Toggle("Cue button", isOn: $cue)
                Toggle("Headphone cue button", isOn: $headphones)
                Toggle("SuperSlicer", isOn: $slicer)
            }
            SettingsGroup("Waveforms") { Toggle("Section colours", isOn: $colours) }
            SettingsGroup("Touch & visibility") {
                Toggle("Large resize handles", isOn: $handles)
                Text("Larger, labelled grips for moving the pane dividers.").font(.caption).foregroundStyle(.secondary)
                Toggle("Notification centre", isOn: $notifications)
            }
        }
    }
}

struct DeckUtilitySettings: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Deck \(deck.rawValue.uppercased()) · Utility").font(.title3.bold())
                if let track = model.track(deck) {
                    Text(track.title).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
                SettingsGroup("This deck") {
                    Picker(
                        "Loop length",
                        selection: Binding(
                            get: { model.performance.loopBeats(for: deck) },
                            set: {
                                model.setLoopSize($0, deck: deck)
                            })
                    ) {
                        ForEach(PerformancePreparation.loopSizes, id: \.self) { beats in
                            Text("\(PerformancePreparation.loopSizeLabel(beats)) beats").tag(beats)
                        }
                    }
                    Toggle(
                        "Keylock",
                        isOn: Binding(
                            get: { model.playbackSnapshot?[deck].keylock ?? false },
                            set: { value in
                                if value != (model.playbackSnapshot?[deck].keylock ?? false) {
                                    model.toggleKeylock(deck: deck)
                                }
                            })
                    ).disabled(model.track(deck) == nil)
                    Toggle(
                        "Headphone cue",
                        isOn: Binding(
                            get: { model.controlDisplay[deck].mixer.cue },
                            set: {
                                model.setMixer(.cue, value: $0 ? 1 : 0, deck: deck)
                            }))
                }
                SettingsGroup("Timing · all decks") { QuantizeSettings(model: model) }
                SettingsGroup("Vinyl stop · all decks") { VinylStopSettings() }
                SettingsGroup("At track end · all decks") { RecoverySettingsView(model: model) }
                if let track = model.track(deck), DeckID.primary.contains(deck) {
                    SettingsGroup("Replay marker · this track") {
                        Button("Use playhead as last drop") { model.setRecoveryDropFromPlayhead(deck: deck) }
                        if model.performance.recovery.dropFrames[track.id] != nil {
                            Button("Use detected drop") { model.clearRecoveryDrop(deck: deck) }
                        }
                    }
                }
                Text("Control visibility and loading defaults are in Settings.").font(.caption).foregroundStyle(
                    .secondary)
                Button("Gesture guide") { model.helpVisible = true }
            }.padding(16)
        }.frame(width: 360).frame(maxHeight: 580).background(PerformancePalette.panel)
            .foregroundStyle(PerformancePalette.text).buttonStyle(.bordered).tint(PerformancePalette.cyan)
    }
}

/// Controls the original app did not have. Each is off by default, so the deck stays as it was.
enum DeckToolSettings {
    static let sectionWaveformColours = "waveform.sectionColours"
    static let largePanelHandles = "interface.largePanelHandles"
    static let beatJump = "deckTools.beatJump"
    static let tempoFader = "deckTools.tempoFader"
    static let cueButton = "deckTools.cueButton"
    static let headphoneButton = "deckTools.headphoneButton"
    static let vinylStop = "deckTools.vinylStop"
    static let vinylStopDuration = "deckTools.vinylStopDuration"
}

enum FourDeckTrial {
    static let preferenceKey = "playback.fourDeckTrial"
    static var isAvailable: Bool {
        #if os(iOS)
            UIDevice.current.userInterfaceIdiom == .pad
                && Bundle.main.object(forInfoDictionaryKey: "GenErikFourDeckTrial") as? String == "YES"
        #else
            false
        #endif
    }
}
