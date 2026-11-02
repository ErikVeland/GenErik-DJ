import TDJCore

/// Accepted fader targets can precede both audio snapshots and screen updates.
@MainActor final class MixerFaderInputValues {
    private struct Values {
        var volume:Double?,low:Double?,mid:Double?,high:Double?
        func value(_ parameter:MixerParameter) -> Double? {
            switch parameter {
            case .volume: volume
            case .low: low
            case .mid: mid
            case .high: high
            default: nil
            }
        }
        mutating func accept(_ parameter:MixerParameter,value:Double) {
            switch parameter {
            case .volume: volume=value
            case .low: low=value
            case .mid: mid=value
            case .high: high=value
            default: break
            }
        }
    }
    private var a=Values(),b=Values()
    func accept(_ parameter:MixerParameter,value:Double,deck:DeckID) {
        let upper:Double
        switch parameter {
        case .volume: upper=1
        case .low,.mid,.high: upper=2
        default: return
        }
        guard value.isFinite,(0...upper).contains(value) else { return }
        if deck == .a { a.accept(parameter,value:value) } else { b.accept(parameter,value:value) }
    }
    func value(_ parameter:MixerParameter,deck:DeckID) -> Double? {
        (deck == .a ? a:b).value(parameter)
    }
}

extension ReplicaModel {
    func mixerFaderValue(_ parameter:MixerParameter,deck:DeckID) -> Double? {
        if let value=mixerFaderInputs.value(parameter,deck:deck) { return value }
        let display=controlDisplay[deck].mixer
        switch parameter {
        case .volume: return display.volume
        case .low: return display.low
        case .mid: return display.mid
        case .high: return display.high
        default: return nil
        }
    }
}
