import Foundation
import Observation
import TDJCore

@MainActor @Observable
final class EffectSlotDisplay {
    private(set) var kind=0
    private(set) var x=0.5
    private(set) var y=0.5
    private(set) var enabled=false
    private(set) var locked=false
    private(set) var delaySync: Bool?
    private(set) var delayBeatStep=2
    private(set) var delayMilliseconds=224
    /// Effect name and grid division, for example "Gater · 1/4 beat". Changes only when the text does.
    private(set) var padLabel="Delay · 1 beat"

    func publish(_ value: EffectControl) {
        if kind != value.kind { kind=value.kind }
        if x != value.x { x=value.x }
        if y != value.y { y=value.y }
        if enabled != value.enabled { enabled=value.enabled }
        if locked != value.locked { locked=value.locked }
        if delaySync != value.delaySync { delaySync=value.delaySync }
        if value.kind == PerformanceEffect.delay.rawValue,value.x.isFinite,(0...1).contains(value.x) {
            if value.delaySync ?? true {
                let step=Int(round(value.x*4))
                if delayBeatStep != step { delayBeatStep=step }
            } else {
                let milliseconds=Int((25*pow(80,value.x)).rounded())
                if delayMilliseconds != milliseconds { delayMilliseconds=milliseconds }
            }
        }
        let label=Self.padLabel(value)
        if padLabel != label { padLabel=label }
    }
    static func padLabel(_ value: EffectControl) -> String {
        guard let effect=PerformanceEffect(rawValue:value.kind) else { return "" }
        if effect == .transposeStretch, let semitones=KeyShift.semitones(for:value.x) {
            return String(format:"Transpose Stretch · %+.1f st",semitones)
        }
        if effect == .delay,value.delaySync == false,value.x.isFinite {
            return "\(effect.name) · \(Int((25*pow(80,min(1,max(0,value.x)))).rounded())) ms"
        }
        guard let beats=effect.gridBeats(x:value.x) else { return effect.name }
        return "\(effect.name) · \(PerformanceEffect.beatLabel(beats))"
    }
}

@MainActor
final class EffectControlDisplay {
    private let a=(0..<3).map { _ in EffectSlotDisplay() }
    private let b=(0..<3).map { _ in EffectSlotDisplay() }

    subscript(_ deck: DeckID, _ slot: Int) -> EffectSlotDisplay {
        precondition((0..<3).contains(slot))
        return deck == .a ? a[slot]:b[slot]
    }
    func publish(_ values: [DeckID:[Int:EffectControl]]) {
        for slot in 0..<3 {
            a[slot].publish(values[.a]?[slot] ?? .init())
            b[slot].publish(values[.b]?[slot] ?? .init())
        }
    }
}

struct EffectPadDisplayValue: Equatable {
    let x: Double, y: Double
    let enabled: Bool
    init(x: Double = 0.5, y: Double = 0.5, enabled: Bool = false) {
        self.x=x;self.y=y;self.enabled=enabled
    }
    @MainActor init(_ display: EffectSlotDisplay) {
        self.init(x:display.x,y:display.y,enabled:display.enabled)
    }
}

struct EffectDelayDisplayValue: Equatable {
    let delaySync: Bool?
    let beatStep: Int
    let milliseconds: Int
    init(delaySync: Bool? = nil, beatStep: Int = 2, milliseconds: Int = 224) {
        self.delaySync=delaySync;self.beatStep=beatStep;self.milliseconds=milliseconds
    }
    @MainActor init(_ display: EffectSlotDisplay) {
        self.init(delaySync:display.delaySync,beatStep:display.delayBeatStep,milliseconds:display.delayMilliseconds)
    }
}

/// Coordinate tracking stays private. Only contact ownership affects the view.
@MainActor @Observable
final class EffectPadContactState {
    private(set) var activeSlot: Int?
    @ObservationIgnored private var session=EffectPadGestureSession()

    func handle(_ event: SurfaceEvent, selectedSlot: Int) -> EffectPadGestureSession.Update? {
        let update=session.handle(event,selectedSlot:selectedSlot)
        if activeSlot != session.activeSlot { activeSlot=session.activeSlot }
        return update
    }
    func cancel() -> Int? {
        let slot=session.cancel()
        if activeSlot != nil { activeSlot=nil }
        return slot
    }
}
