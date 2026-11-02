import CTDJTransport
import Foundation

public enum SourceControl: Sendable {
    case play(DeckID, UInt64)
    case brake(VinylBrakeAction, Double, DeckID, UInt64)
    case tempo(Double)
    case freeRate(Double, DeckID, UInt64)
    case sync(Bool, DeckID, UInt64)
    case restoreSync(DeckID, UInt64)
    case keylock(Bool, DeckID, UInt64)
    case grid(BeatGrid, DeckID, UInt64)
    case adaptiveMap(BeatGridMap?, DeckID, UInt64)
    case seek(Double, DeckID, UInt64)
    case cueRecall(DeckID, UInt64, frame: Double, loopEnd: Double?, quantum: Double)
    case performance(PerformanceAction, DeckID, UInt64, value: Double, end: Double, enabled: Bool, quantum: Double, touchRate: Double? = nil)

    var command: tdj_command {
        var result = tdj_command()
        func deck(_ deck: DeckID, _ generation: UInt64) {
            result.deck = deck == .a ? 0 : 1; result.generation = generation
        }
        switch self {
        case .brake(let action, let value, let id, let generation):
            result.kind=TDJ_BRAKE;deck(id,generation);result.flag=action.rawValue;result.value=value
        case .play(let id, let generation):
            result.kind = TDJ_PLAY; deck(id, generation)
        case .tempo(let bpm):
            result.kind = TDJ_TEMPO; result.value = bpm
        case .freeRate(let rate, let id, let generation):
            result.kind=TDJ_FREE_RATE;deck(id,generation);result.value=rate
        case .sync(let enabled, let id, let generation):
            result.kind = TDJ_SYNC; deck(id, generation); result.flag = enabled ? 1 : 0
        case .restoreSync(let id, let generation):
            result.kind=TDJ_SYNC_RESTORE; deck(id,generation)
        case .keylock(let enabled, let id, let generation):
            result.kind = TDJ_KEYLOCK; deck(id, generation); result.flag = enabled ? 1 : 0
        case .grid(let grid, let id, let generation):
            result.kind = TDJ_GRID; deck(id, generation)
            result.value = grid.bpm; result.value2 = grid.anchorFrame; result.flag = Int32(grid.downbeatOffset)
        case .adaptiveMap(let map, let id, let generation):
            result.kind = TDJ_ADAPTIVE_GRID; deck(id, generation)
            if let map { result.beatgrid = map.native }
        case .seek(let frame, let id, let generation):
            result.kind = TDJ_SEEK; deck(id, generation); result.value = frame
        case .cueRecall(let id, let generation, let frame, let loopEnd, let quantum):
            result.kind = TDJ_CUE_RECALL; deck(id, generation)
            result.value = frame; result.value2 = loopEnd ?? 0; result.value3 = quantum
        case .performance(let action, let id, let generation, let value, let end, let enabled, let quantum, let touchRate):
            result.kind = action.rawValue; deck(id, generation)
            result.value = value; result.value2 = end; result.value3 = quantum; result.flag = enabled ? 1 : 0
            if action == .touch, enabled, let touchRate {
                result.flag = TDJ_TOUCH_WITH_RATE; result.touch_rate = touchRate
            }
        }
        return result
    }
}

/// The serial producer transfers this ticket to submit, including submission failure.
public struct SourcePreparation: Sendable {
    public let asset: PCMAsset
    public let deck: DeckID
    public let generation: UInt64
    public let ticket: UInt64
    public init(asset: PCMAsset, deck: DeckID, generation: UInt64, ticket: UInt64) {
        self.asset = asset; self.deck = deck; self.generation = generation; self.ticket = ticket
    }
}
