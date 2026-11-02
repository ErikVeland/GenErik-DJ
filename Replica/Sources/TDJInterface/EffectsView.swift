import SwiftUI
import TDJCore

struct EffectControl: Codable, Sendable {
    var kind=0
    var x=0.5
    var y=0.5
    var enabled=false
    var locked=false
    var delaySync: Bool? = nil
}
struct EffectsView: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    @State private var gesture = EffectPadContactState()
    @Environment(\.deckPanelPresented) private var panelPresented
    private static let names=PerformanceEffect.allCases.map(\.name)
    private var selectedSlot: Int { gesture.activeSlot ?? min(2,max(0,model.selectedEffectSlots[deck,default:0])) }
    var body: some View {
        VStack(spacing:0) {
            HStack(spacing:1) {
                ForEach(0..<3,id:\.self) { slot in
                        EffectSelector(names:Self.names,selected:model.effectDisplay[deck,slot].kind,isActive:selectedSlot == slot,
                                       accessibilityName:"Deck \(deck.rawValue.uppercased()) effect \(slot+1)",
                                       activate:{ model.selectedEffectSlots[deck]=slot }) { kind in
                            var changed=effect(slot); changed.kind=kind
                            model.selectedEffectSlots[deck]=slot
                            model.setEffect(changed,slot:slot,deck:deck,persist:true)
                        }.font(.caption)
                        .foregroundStyle(selectedSlot == slot ? Color.orange : Color(white:0.7))
                        .background(selectedSlot == slot ? Color.white.opacity(0.12) : .clear)
                        .zIndex(selectedSlot == slot ? 2 : 1)
                }
            }.zIndex(2)
            EffectDelayControl(model:model,deck:deck,slot:selectedSlot)
            TransposeKeyControls(model:model,deck:deck,slot:selectedSlot)
            EffectPad(model:model,deck:deck,slot:selectedSlot) { event in
                let selected=selectedSlot
                guard let update=gesture.handle(event,selectedSlot:selected) else { return }
                model.effectTouch(event,slot:update.slot,deck:deck,updateX:update.updateX,selectSlot:false)
            }.padding(6)
        }.frame(maxWidth:520,maxHeight:.infinity)
            .background(Color.black.opacity(0.7))
            .onChange(of:panelPresented) { _,presented in if !presented { cancelContact() } }
            .onDisappear { cancelContact() }
    }
    private func cancelContact() {
        if let slot=gesture.cancel() {
            model.effectTouch(.init(phase:.cancelled,points:[],ending:[]),slot:slot,deck:deck,updateX:false,selectSlot:false)
        }
    }
    private func effect(_ slot: Int) -> EffectControl { model.effects[deck]?[slot] ?? .init() }
}
@MainActor
private struct TransposeKeyControls: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let slot: Int

    private var otherDeck: DeckID { deck == .a ? .b : .a }
    private var effect: EffectControl { model.effects[deck]?[slot] ?? .init() }
    private var matchOffset: Int? {
        guard let source=model.track(deck)?.key, let target=model.track(otherDeck)?.key else { return nil }
        return KeyShift.matchOffset(from:source,to:target)
    }

    var body: some View {
        Group {
            if effect.kind == PerformanceEffect.transposeStretch.rawValue {
                VStack(alignment:.leading,spacing:4) {
                    HStack(spacing:10) {
                        Button("−1 st") { step(-1) }
                        Text(KeyShift.semitones(for:effect.x).map { String(format:"%+.1f st",$0) } ?? "—")
                            .font(.caption.monospacedDigit())
                        Button("+1 st") { step(1) }
                        Spacer(minLength:4)
                        Button("Match \(otherDeck.rawValue.uppercased())") {
                            if let matchOffset { setSemitones(Double(matchOffset),fullyWet:true) }
                        }
                        .disabled(matchOffset == nil)
                    }.font(.caption)
                    if let source=model.track(deck)?.key, let target=model.track(otherDeck)?.key,
                       source.mode != target.mode {
                        Text("Key Match requires the same major or minor mode.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func step(_ amount: Int) {
        guard let current=KeyShift.semitones(for:effect.x),
              let position=KeyShift.position(for:min(12,max(-60,Double(current.rounded())+Double(amount)))) else { return }
        setPosition(position)
    }

    private func setSemitones(_ semitones: Double, fullyWet: Bool) {
        guard let position=KeyShift.position(for:semitones) else { return }
        var changed=effect
        changed.x=position
        changed.enabled=true
        if fullyWet { changed.y=1 }
        model.setEffect(changed,slot:slot,deck:deck,persist:true)
    }

    private func setPosition(_ position: Double) {
        var changed=effect
        changed.x=position
        model.setEffect(changed,slot:slot,deck:deck,persist:true)
    }
}

@MainActor
private struct EffectDelayControl: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let slot: Int
    @Environment(\.deckPanelPresented) private var panelPresented
    @State private var cache=MixerPaneDisplayCache(EffectDelayDisplayValue())
    var body: some View {
        let display=model.effectDisplay[deck,slot]
        // Keep geometry current while hidden. Observe only the displayed delay values.
        let kind=display.kind
        let value=cache.value(active:panelPresented) { EffectDelayDisplayValue(display) }
        Group {
            if kind == PerformanceEffect.delay.rawValue {
                HStack {
                    Button((value.delaySync ?? true) ? "SYNC" : "FREE") {
                        guard panelPresented else { return }
                        model.toggleEffectDelaySync(slot:slot,deck:deck)
                    }
                    .foregroundStyle((value.delaySync ?? true) ? Color.orange : Color.gray)
                    if value.delaySync ?? true {
                        let beats=0.25 * pow(2,Double(value.beatStep))
                        Text("\(beats.formatted()) BEAT")
                    } else {
                        Text("\(value.milliseconds) MS")
                    }
                }.font(.caption.monospacedDigit())
            }
        }.onChange(of:panelPresented,initial:true) { _,presented in
            if !presented { cache.freeze(EffectDelayDisplayValue(display)) }
        }
    }
}

@MainActor
private struct EffectPadLabel: View {
    let display: EffectSlotDisplay
    var body: some View {
        Text(display.padLabel).font(.caption2.monospacedDigit()).foregroundStyle(.white.opacity(0.75))
            .padding(6).allowsHitTesting(false).accessibilityHidden(true)
    }
}

@MainActor
private struct EffectPad: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let slot: Int
    let touch: (SurfaceEvent) -> Void
    var body: some View {
            GeometryReader { geometry in
                ZStack {
                    Color.black.opacity(0.5)
                    EffectPadGrid(size:geometry.size).equatable()
                    EffectPadMarker(display:model.effectDisplay[deck,slot],size:geometry.size)
                    TouchSurface(action:touch)
                        .accessibilityLabel("Deck \(deck.rawValue.uppercased()) effect \(slot+1) XY pad")
                }.clipped().padding(.trailing,24)
                .overlay(alignment:.trailing) {
                    EffectPadLock(display:model.effectDisplay[deck,slot],slot:slot,toggle:toggleLock)
                }
                .overlay(alignment:.topLeading) {
                    EffectPadLabel(display:model.effectDisplay[deck,slot])
                }
            }
    }
    private func toggleLock() {
        var changed=model.effects[deck]?[slot] ?? .init()
        changed.locked.toggle()
        if !changed.locked { changed.enabled=false }
        model.selectedEffectSlots[deck]=slot
        model.setEffect(changed,slot:slot,deck:deck,persist:true)
    }
}

private struct EffectPadGrid: View, Equatable {
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
private struct EffectPadMarker: View {
    let display: EffectSlotDisplay
    let size: CGSize
    @Environment(\.deckPanelPresented) private var panelPresented
    @State private var cache=MixerPaneDisplayCache(EffectPadDisplayValue())
    var body: some View {
        let value=cache.value(active:panelPresented) { EffectPadDisplayValue(display) }
        let colour=value.enabled ? Color.orange : Color.gray
        Circle().stroke(colour.opacity(0.7),lineWidth:1).frame(width:28,height:28)
            .overlay { Circle().fill(colour).frame(width:10,height:10) }
            .position(x:value.x*max(1,size.width-24),y:(1-value.y)*size.height)
            .onChange(of:panelPresented,initial:true) { _,presented in
                if !presented { cache.freeze(EffectPadDisplayValue(display)) }
            }
    }
}

@MainActor
private struct EffectPadLock: View {
    let display: EffectSlotDisplay
    let slot: Int
    let toggle: () -> Void
    @Environment(\.deckPanelPresented) private var panelPresented
    @State private var cache=MixerPaneDisplayCache(false)
    var body: some View {
        let locked=cache.value(active:panelPresented) { display.locked }
        Button(action:toggle) { Image(systemName:locked ? "lock.fill" : "lock.open") }
            .frame(width:24,height:44).foregroundStyle(locked ? Color.orange : Color(white:0.65))
            .accessibilityLabel("Lock effect \(slot+1)")
            .onChange(of:panelPresented,initial:true) { _,presented in
                if !presented { cache.freeze(display.locked) }
            }
    }
}
extension ReplicaModel {
    func effectTouch(_ event: SurfaceEvent, slot: Int, deck: DeckID, updateX: Bool = true, selectSlot: Bool = true) {
        if selectSlot && (event.phase == .began || event.phase == .moved) { selectedEffectSlots[deck]=slot }
        var changed=effects[deck]?[slot] ?? .init()
        let released=event.phase == .ended && event.remaining.isEmpty
        if event.phase == .cancelled || released {
            if event.phase == .cancelled || !changed.locked { changed.enabled=false }
        } else if let point=event.remaining.first {
            if updateX { changed.x=min(1,max(0,point.x)) }
            changed.y=min(1,max(0,1-point.y)); changed.enabled=true
        }
        setEffect(changed,slot:slot,deck:deck,persist:released || event.phase == .cancelled)
    }
    @discardableResult
    func toggleEffectDelaySync(slot: Int, deck: DeckID) -> Bool {
        var current=effects[deck]?[slot] ?? .init()
        guard current.kind == PerformanceEffect.delay.rawValue else { return false }
        current.delaySync = !(current.delaySync ?? true)
        return setEffect(current,slot:slot,deck:deck,persist:true)
    }
    func setHardwareEffectX(_ x: Double,deck: DeckID) {
        let slot=selectedEffectSlots[deck,default:0]
        var effect=effects[deck]?[slot] ?? .init()
        effect.x=min(1,max(0,x)); setEffect(effect,slot:slot,deck:deck)
    }
    func toggleHardwareEffect(deck: DeckID) {
        let slot=selectedEffectSlots[deck,default:0]
        var effect=effects[deck]?[slot] ?? .init()
        effect.enabled.toggle(); setEffect(effect,slot:slot,deck:deck,persist:true)
    }
    @discardableResult
    func setEffect(_ value: EffectControl, slot: Int, deck: DeckID, persist: Bool = false) -> Bool {
        do {
            try playback.setEffect(value.kind,slot:slot,x:value.x,y:value.y,enabled:value.enabled,deck:deck,synced:value.delaySync ?? true)
            effects[deck,default:[:]][slot]=value
            if persist { saveEffects() }
            return true
        } catch { status=error.localizedDescription; return false }
    }
    func saveEffects() {
        let url=store.root.appendingPathComponent("effects.json")
        effectsPersistence.enqueue(effects,write:{ try JSONEncoder().encode($0).write(to:url,options:.atomic) },
                                   reportError:{ [weak self] in self?.status=$0 })
    }
    func loadEffects() throws {
        let url=store.root.appendingPathComponent("effects.json")
        guard FileManager.default.fileExists(atPath:url.path) else { return }
        let stored=try JSONDecoder().decode([DeckID:[Int:EffectControl]].self,from:Data(contentsOf:url))
        for (deck,slots) in stored { for (slot,original) in slots {
            guard (0..<3).contains(slot),(0..<PerformanceEffect.supportedCount).contains(original.kind),original.x.isFinite,original.y.isFinite,
                  (0...1).contains(original.x),(0...1).contains(original.y) else { throw TransportError.invalid }
            var value=original; value.enabled=false; value.locked=false; setEffect(value,slot:slot,deck:deck)
        } }
    }
}

/// Tap to choose, or hold the selector and drag downward through the choices.
private struct EffectSelector: View {
    let names: [String]
    let selected: Int
    let isActive: Bool
    let accessibilityName: String
    let activate: () -> Void
    let choose: (Int) -> Void
    @State private var gesture=EffectSelectorGestureSession()
    @Environment(\.deckPanelPresented) private var panelPresented
    @State private var contactGeneration=0
    var body: some View {
        Text(names[selected]).lineLimit(1).minimumScaleFactor(0.65).frame(maxWidth:.infinity).frame(height:28)
            .accessibilityLabel("\(accessibilityName): \(names[selected])")
            .background(.white.opacity(0.08))
            .overlay {
                TouchSurface { event in
                    let activeAtStart=isActive
                    if event.phase == .began && !gesture.isTracking { contactGeneration &+= 1; activate() }
                    if let selection=gesture.handle(event,at:ProcessInfo.processInfo.systemUptime,count:names.count,tapOpensMenu:activeAtStart) {
                        choose(selection)
                    }
                }
            }
            .onChange(of:isActive) { _,active in if !active { gesture.dismiss() } }
            .onChange(of:panelPresented) { _,presented in if !presented { gesture.dismiss() } }
            .overlay(alignment:.top) {
                if gesture.opened {
                    ScrollView(.vertical) { VStack(spacing:0) {
                        ForEach(names.indices,id:\.self) { index in
                            Button(names[index]) { choose(index); gesture.opened=false }
                                .accessibilityLabel("\(accessibilityName): \(names[index])")
                                .frame(maxWidth:.infinity).frame(height:28)
                                .background(index == selected ? Color.blue : Color(white:0.15))
                        }
                    } }.frame(height:Double(min(6,names.count))*28).id(contactGeneration).offset(y:28)
                }
            }
    }
}
