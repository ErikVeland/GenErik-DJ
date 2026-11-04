import SwiftUI
import TDJCore

/// Playback choices visible in the saved S21/S30 reference screens.
struct PlaybackSettings: View {
    @Bindable var model: ReplicaModel
    var showsPlayback = true
    func extrasOnly() -> Self { var copy = self; copy.showsPlayback = false; return copy }
    @AppStorage(DeckToolSettings.sectionWaveformColours) private var sectionWaveformColours = true
    @AppStorage(DeckToolSettings.beatJump) private var beatJump = false
    @AppStorage(DeckToolSettings.tempoFader) private var tempoFader = false
    @AppStorage(DeckToolSettings.cueButton) private var cueButton = false
    @AppStorage(DeckToolSettings.headphoneButton) private var headphoneButton = false
    @AppStorage(DeckToolSettings.hotcuePads) private var hotcuePads = false
    @AppStorage(DeckToolSettings.vinylStop) private var vinylStop = false
    @AppStorage(DeckToolSettings.vinylStopDuration) private var vinylStopDuration = 1.0
    @AppStorage(DeckToolSettings.largePanelHandles) private var largePanelHandles = false
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            if showsPlayback {
            Picker("Quantize Size",selection:preference(\.quantize)) {
                Text("1/4 Beat").tag(0.25)
                Text("1/2 Beat").tag(0.5)
                Text("1 Beat").tag(1.0)
                Text("1 Bar").tag(4.0)
            }
            Toggle("Slicer Quantize",isOn:preference(\.slicerQuantize))
            Toggle("Freeze on Load",isOn:preference(\.freezeOnLoad))
            RecoverySettingsView(model: model)
            Divider()
            Text("Extra deck controls").font(.headline)
            }
            Toggle("Section colours in waveform", isOn: $sectionWaveformColours)
            Toggle("Beat jump",isOn:$beatJump)
            Toggle("Tempo fader",isOn:$tempoFader)
            Toggle("CUE button",isOn:$cueButton)
            Toggle("Headphone button",isOn:$headphoneButton)
            Toggle("Hotcue pads",isOn:$hotcuePads)
            Toggle("Vinyl stop",isOn:$vinylStop)
            if vinylStop {
                HStack {
                    Text("Stop duration")
                    Slider(value:$vinylStopDuration,in:0.2...5,step:0.1)
                    Text(String(format:"%.1f s",vinylStopDuration)).monospacedDigit()
                }
                Text("Tap Stop during playback to slow down. Tap Play to resume at the saved speed.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            Text("Accessibility").font(.headline)
            Toggle("Large panel handles", isOn: $largePanelHandles)
            Text("Show larger, labelled grips for panel resizing.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func preference<Value>(_ key: WritableKeyPath<PerformancePreparation,Value>) -> Binding<Value> {
        Binding(get:{ model.performance[keyPath:key] },set:{ value in
            model.performance[keyPath:key]=value
            model.savePerformance()
        })
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
    static let hotcuePads = "deckTools.hotcuePads"
    static let vinylStop = "deckTools.vinylStop"
    static let vinylStopDuration = "deckTools.vinylStopDuration"
}
