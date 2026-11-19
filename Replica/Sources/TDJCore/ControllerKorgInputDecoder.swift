public struct ControllerKorgInputDecoder: Sendable {
    public enum Mode: Equatable, Sendable {
        case native(ControllerKorgNativeDecoder.Model)
        case originalNanoKontrol
    }
    private var native: ControllerKorgNativeDecoder?
    private var scene: ControllerNanoKontrolSceneDecoder?

    public init(mode: Mode) {
        switch mode {
        case .native(let model): native = .init(model: model)
        case .originalNanoKontrol: scene = .init()
        }
    }
    public var isReady: Bool { native?.isReady ?? scene?.isReady ?? false }
    public var exitRequest: [UInt8]? { native?.exitRequest }

    /**
     * Shares bounded setup events while keeping original scene reads separate from native-mode requests.
     */
    public mutating func append(_ bytes: [UInt8]) -> [ControllerKorgNativeEvent] {
        if var decoder = native {
            let events = decoder.append(bytes)
            native = decoder
            return events
        }
        if var decoder = scene {
            let events = decoder.append(bytes)
            scene = decoder
            return events
        }
        return []
    }
}
