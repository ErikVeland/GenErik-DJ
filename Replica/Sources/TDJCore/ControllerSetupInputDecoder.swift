/**
 * Shares bounded setup handling while each protocol retains its own ownership rules.
 */
public struct ControllerSetupInputDecoder: Sendable {
    public enum Mode: Equatable, Sendable {
        case korg(ControllerKorgInputDecoder.Mode)
        case xdjAN
    }
    private var korg: ControllerKorgInputDecoder?
    private var xdj: ControllerXDJANDecoder?

    public init(mode: Mode) {
        switch mode {
        case .korg(let mode): korg = .init(mode: mode)
        case .xdjAN: xdj = .init()
        }
    }
    public var isReady: Bool { korg?.isReady ?? xdj?.isReady ?? false }
    public var exitRequest: [UInt8]? { korg?.exitRequest }
    public var pendingRequest: [UInt8]? { xdj?.pendingRequest }
    public mutating func didSendPendingRequest(_ bytes: [UInt8]) -> Bool {
        xdj?.didSendPendingRequest(bytes) ?? false
    }
    public mutating func append(_ bytes: [UInt8]) -> [ControllerKorgNativeEvent] {
        if var decoder = korg {
            let result = decoder.append(bytes)
            korg = decoder
            return result
        }
        if var decoder = xdj {
            let result = decoder.append(bytes)
            xdj = decoder
            return result
        }
        return []
    }
}
