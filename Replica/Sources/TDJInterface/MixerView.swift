import SwiftUI
import TDJCore

enum MixerPanel: String, CaseIterable { case equalizer = "Equalizer", filter = "Filter" }

@MainActor
struct DeckMixerView: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    @Binding var panel: MixerPanel
    var width: CGFloat = 250
    @State private var input=MixerPaneInputSession()
    @Environment(\.deckPanelPresented) private var panelPresented
    @Environment(\.touchSurfaceInputGate) private var parentInput
    var body: some View {
        VStack(spacing:0) {
            HStack(spacing:1) {
                ForEach(MixerPanel.allCases,id:\.self) { item in
                    Button {
                        input.select(item) { panel=item }
                        input.synchronize(selection:panel,presented:panelPresented)
                    } label: {
                        Text(item.rawValue).font(.system(size:11))
                            .frame(maxWidth:.infinity).frame(height:28)
                            .foregroundStyle(panel == item ? PerformancePalette.cyan : Color(white:0.7))
                            .background(panel == item ? Color.white.opacity(0.12) : Color.black.opacity(0.2))
                    }.accessibilityLabel("Deck \(deck.rawValue.uppercased()) \(item.rawValue)")
                }
            }
            ZStack {
                RetainedEqualizerPane(model:model,deck:deck,active:panelPresented && panel == .equalizer)
                    .padding(6)
                    .environment(\.touchSurfaceInputGate,input.equalizer)
                    .opacity(panel == .equalizer ? 1:0)
                    .allowsHitTesting(panelPresented && panel == .equalizer)
                    .accessibilityHidden(!panelPresented || panel != .equalizer)
                    .transaction { $0.animation=nil }
                RetainedFilterPane(model:model,deck:deck,active:panelPresented && panel == .filter)
                    .padding(6)
                    .environment(\.touchSurfaceInputGate,input.filter)
                    .opacity(panel == .filter ? 1:0)
                    .allowsHitTesting(panelPresented && panel == .filter)
                    .accessibilityHidden(!panelPresented || panel != .filter)
                    .transaction { $0.animation=nil }
            }
        }.frame(width:width).frame(maxHeight:.infinity)
            .background(Color.black.opacity(0.7))
            .onAppear {
                input.bindParent(parentInput)
                input.synchronize(selection:panel,presented:panelPresented)
            }
            .onChange(of:panel) { _,selection in input.synchronize(selection:selection,presented:panelPresented) }
            .onChange(of:panelPresented) { _,presented in input.synchronize(selection:panel,presented:presented) }
            .onChange(of:parentInput.map(ObjectIdentifier.init)) { _,_ in input.bindParent(parentInput) }
            .onDisappear { input.unbind() }
    }
}

@MainActor
private struct RetainedEqualizerPane: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let active: Bool
    @State private var display=MixerPaneDisplayCache(MixerEqualizerDisplayValue())
    private func liveValue() -> MixerEqualizerDisplayValue { .init(model.controlDisplay[deck].mixer) }
    var body: some View {
        let value=display.value(active:active,read:liveValue)
        HStack(spacing:1) {
            control("Low",.low,value.low,range:0...2)
            control("Mid",.mid,value.mid,range:0...2)
            control("High",.high,value.high,range:0...2)
            control("Volume",.volume,value.volume,range:0...1)
        }.onChange(of:active,initial:true) { _,visible in if !visible { display.freeze(liveValue()) } }
    }
    private func control(_ name: String, _ parameter: MixerParameter, _ value: Double, range: ClosedRange<Double>) -> some View {
        VStack(spacing:4) {
            Text(name).font(.system(size:9)).foregroundStyle(Color(white:0.6)).padding(.top,5)
            TouchFader(value:value,range:range,reset:parameter == .volume ? nil : 1,axis:.vertical,
                       readValue:{ model.mixerFaderValue(parameter,deck:deck) ?? value }) { model.setMixer(parameter,value:$0,deck:deck) }
                .accessibilityLabel("Deck \(deck.rawValue.uppercased()) \(name)")
        }.background(Color.black.opacity(0.3))
    }
}

@MainActor
private struct RetainedFilterPane: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let active: Bool
    @State private var contact=FilterPadContactState()
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing:0) {
                ZStack {
                    Color.black.opacity(0.4)
                    RetainedFilterGrid(size:geometry.size).equatable()
                    RetainedFilterMarker(model:model,deck:deck,active:active,size:geometry.size)
                    TouchSurface { event in
                        let updateX=contact.update(event)
                        if event.phase == .cancelled { model.releaseFilter(deck:deck,cancelled:true) }
                        else if event.phase == .ended && event.remaining.isEmpty { model.releaseFilter(deck:deck) }
                        else if let point=event.remaining.first { model.filterTouch(x:point.x,y:point.y,deck:deck,updateX:updateX) }
                    }
                    .accessibilityLabel("Filter cutoff and resonance")
                }.clipped()
                RetainedFilterLock(model:model,deck:deck,active:active)
            }
        }.onChange(of:active) { _,visible in if !visible { cancelFilterContact() } }
        .onDisappear { cancelFilterContact() }
    }
    private func cancelFilterContact() {
        if contact.isTouching { model.releaseFilter(deck:deck,cancelled:true) }
        contact.reset()
    }
}

/// The filter grid depends only on pane size.
private struct RetainedFilterGrid: View, Equatable {
    let size: CGSize
    var body: some View {
        Path { path in
            for tick in 0...8 {
                let x=max(1,size.width-24)*Double(tick)/8
                let y=size.height*Double(tick)/8
                path.move(to:.init(x:x,y:0)); path.addLine(to:.init(x:x,y:size.height))
                path.move(to:.init(x:0,y:y)); path.addLine(to:.init(x:max(1,size.width-24),y:y))
            }
        }.stroke(.white.opacity(0.08),lineWidth:1)
    }
}

@MainActor
private struct RetainedFilterMarker: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let active: Bool
    let size: CGSize
    @State private var display=MixerPaneDisplayCache(MixerFilterDisplayValue())
    private func liveValue() -> MixerFilterDisplayValue { .init(model.controlDisplay[deck].mixer) }
    var body: some View {
        let value=display.value(active:active,read:liveValue)
        let colour=value.enabled ? PerformancePalette.cyan : Color.gray
        Circle().stroke(colour.opacity(0.7),lineWidth:1).frame(width:28,height:28)
            .overlay { Circle().fill(colour).frame(width:10,height:10) }
            .position(x:((value.x)+1)/2*max(1,size.width-24),y:(1-value.y)*size.height)
            .onChange(of:active,initial:true) { _,visible in if !visible { display.freeze(liveValue()) } }
    }
}

@MainActor
private struct RetainedFilterLock: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let active: Bool
    @State private var display=MixerPaneDisplayCache(false)
    private func liveValue() -> Bool { model.filterLocked.contains(deck) }
    var body: some View {
        let locked=display.value(active:active,read:liveValue)
        Button {
            guard active else { return }
            if model.filterLocked.contains(deck) { model.filterLocked.remove(deck); model.releaseFilter(deck:deck) }
            else { model.filterLocked.insert(deck) }
        } label: { Image(systemName:locked ? "lock.fill" : "lock.open") }
            .frame(width:24,height:44)
            .foregroundStyle(locked ? PerformancePalette.cyan : Color(white:0.65))
            .accessibilityLabel("Lock filter on deck \(deck.rawValue.uppercased())")
            .onChange(of:active,initial:true) { _,visible in if !visible { display.freeze(liveValue()) } }
    }
}

@MainActor
struct CrossfaderView: View {
    @Bindable var model: ReplicaModel
    var width: CGFloat = 36
    var showsDeckLabels = true
    var body: some View {
        VStack {
            if showsDeckLabels { Text("A").font(.caption.bold()) }
            GeometryReader { geometry in
                let inset: CGFloat = width>36 ? 10 : 8
                ZStack {
                    RoundedRectangle(cornerRadius:1).fill(.black.opacity(0.6)).frame(width:10)
                    RoundedRectangle(cornerRadius:2).fill(Color(white:0.35))
                        .frame(width:max(24,width-12),height:inset*2)
                        .overlay { Rectangle().fill(Color(white:0.7)).frame(height:6).padding(.horizontal,5) }
                        .position(x: geometry.size.width/2, y: inset+(geometry.size.height-inset*2)*(model.controlDisplay.crossfader))
                }.frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    model.setMixer(.crossfader, value: min(1,max(0,(value.location.y-inset)/max(1,geometry.size.height-inset*2))))
                })
                .accessibilityLabel("Crossfader")
                .accessibilityValue(String(format: "%.0f percent toward B", (model.controlDisplay.crossfader)*100))
                .accessibilityAdjustableAction { direction in
                    let current=model.controlDisplay.crossfader
                    model.setMixer(.crossfader, value: min(1,max(0,current+(direction == .increment ? 0.05 : -0.05))))
                }
            }
            if showsDeckLabels { Text("B").font(.caption.bold()) }
        }.padding(.vertical,12).frame(width:width).background(PerformancePalette.panel)
    }
}

@MainActor
struct AudioSettingsView: View {
    @Bindable var model: ReplicaModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Audio output").font(.headline)
            Picker("Routing", selection: Binding(get: { model.outputRoute }, set: { model.setOutputRoute($0) })) {
                Text("Stereo master").tag(AudioOutputRoute.stereoMaster)
                Text("Master 1–2 / Headphones 3–4").tag(AudioOutputRoute.masterAndHeadphones)
            }.disabled(model.isRecording || model.recordingFinishing)
            Text(model.outputRoute == .stereoMaster ? "Headphone cue is not routed in stereo mode." : "Requires an output device with four channels.")
                .font(.caption).foregroundStyle(.secondary)
            level("Master level", .master, model.playbackSnapshot?.masterGain ?? 0.5)
            level("Headphone level", .monitor, model.playbackSnapshot?.monitorGain ?? 0.5)
            level("Headphones: cue → master", .cueBlend, model.playbackSnapshot?.cueBlend ?? 0)
#if os(macOS)
            Divider()
            Button(model.z1Enabled ? "Disconnect Z1" : "Connect original Z1") { model.toggleZ1() }
            Text(model.z1Status).font(.caption).foregroundStyle(.secondary)
#endif
        }.padding(20).frame(width:340)
    }
    private func level(_ title: String, _ parameter: MixerParameter, _ value: Double) -> some View {
        VStack(alignment:.leading) {
            Text(title).font(.caption)
            Slider(value:Binding(get:{ value },set:{ model.setMixer(parameter,value:$0) }),in:0...1)
                .accessibilityLabel(title)
        }
    }
}
