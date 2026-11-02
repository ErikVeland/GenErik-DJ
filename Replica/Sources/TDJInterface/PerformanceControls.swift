import SwiftUI
import TDJCore

struct PerformanceControls: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    @State private var settings=false
    @AppStorage(BrowserSettings.fluxModeKey) private var fluxMode = true
    var body: some View {
        HStack(spacing:6) {
            Button("LOOP") { model.toggleLoop(deck:deck) }
                .foregroundStyle(model.controlDisplay[deck].loopEnabled == true ? Color.green : Color.gray)
            Button { setLoopSize(direction:-1) } label: { Image(systemName:"minus") }
                .accessibilityLabel("Halve loop length on deck \(deck.rawValue.uppercased())")
            Menu {
                ForEach(PerformancePreparation.loopSizes,id:\.self) { beats in
                    Button("\(PerformancePreparation.loopSizeLabel(beats)) beats") { setLoopSize(beats) }
                }
            } label: { Text("\(PerformancePreparation.loopSizeLabel(model.performance.loopBeats(for:deck))) BEAT") }
                .accessibilityLabel("Loop length on deck \(deck.rawValue.uppercased())")
            Button { setLoopSize(direction:1) } label: { Image(systemName:"plus") }
                .accessibilityLabel("Double loop length on deck \(deck.rawValue.uppercased())")
            Button { model.toggleFreeze(deck:deck) } label: { Image(systemName:"snowflake") }
                .foregroundStyle(model.frozen.contains(deck) ? Color.cyan : Color.gray)
            Button { model.toggleHotcuePads(deck:deck) } label: { Image(systemName:"flag.fill") }
                .foregroundStyle(model.hotcuePadsVisible.contains(deck) ? Color.cyan : Color.gray)
                .accessibilityLabel("Hotcues for deck \(deck.rawValue.uppercased())")
            if fluxMode {
                Button("FLUX") { model.perform(.flux,deck:deck,enabled:model.controlDisplay[deck].fluxEnabled != true) }
                    .foregroundStyle(model.controlDisplay[deck].fluxEnabled == true ? Color.orange : Color.gray)
            }
            Spacer(minLength:2)
            if model.previewing.contains(deck),!model.frozen.contains(deck),!model.editing.contains(deck) {
                Button { model.returnToPlayhead(deck:deck) } label: { Image(systemName:"arrow.uturn.backward") }
                    .accessibilityLabel("Return to playhead on deck \(deck.rawValue.uppercased())")
            }
            Button { settings.toggle() } label: { Image(systemName:"gearshape") }
                .popover(isPresented:$settings) {
                    VStack(alignment:.leading) {
                        PlaybackSettings(model:model)
                        Button("Gesture guide") { settings=false; model.helpVisible=true }
                    }.padding().frame(width:300).onDisappear { model.savePerformance() }
                }
        }.font(.system(size:11,weight:.semibold)).padding(.horizontal,12).frame(height:40)
            .disabled(model.preparingPlayback.contains(deck) || model.controlDisplay[deck].phase == .queued)
    }
    private func setLoopSize(direction: Int) { model.stepLoopSize(direction:direction,deck:deck) }
    private func setLoopSize(_ beats: Double) { model.setLoopSize(beats,deck:deck) }
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
