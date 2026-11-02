import Foundation

/// Explicit presets for launching the separate diagnostic app on an authorised device.
public enum AudioRuntimeCheckLaunch: String, Sendable {
    case loop60, loop300, sequential300, ui60
    case loop60Near2x44100 = "loop60-near2x-44100"
    case loop300Near2x44100 = "loop300-near2x-44100"
    case uiLoop300PanelsNear2x44100 = "ui-loop300-panels-near2x-44100"
    case loop300Near2x = "loop300-near2x"
    case loop60Near2x = "loop60-near2x"
    case uiLoop300PanelsNear2x = "ui-loop300-panels-near2x"
    case uiLoop300Panels = "ui-loop300-panels"
    case uiSequential300Panels = "ui-sequential300-panels"

    public var durationSeconds: Double { self == .loop60 || self == .ui60 || self == .loop60Near2x || self == .loop60Near2x44100 ? 60:300 }
    public var sequential: Bool { self == .sequential300 || self == .uiSequential300Panels }
    public var liveInterface: Bool { self == .ui60 || panelMotion }
    public var panelMotion: Bool { self == .uiLoop300Panels || self == .uiSequential300Panels || self == .uiLoop300PanelsNear2x || self == .uiLoop300PanelsNear2x44100 }

    public var keylockStress: AudioRuntimeKeylockStress {
        self == .loop60Near2x || self == .loop300Near2x || self == .uiLoop300PanelsNear2x
            || self == .loop60Near2x44100 || self == .loop300Near2x44100 || self == .uiLoop300PanelsNear2x44100 ? .manual60BPM:.detectedGrid
    }

    public var fixtureSampleRate: Double {
        self == .loop60Near2x44100 || self == .loop300Near2x44100 || self == .uiLoop300PanelsNear2x44100 ? 44100:48000
    }

    public enum InvalidArgument: Error, LocalizedError {
        case unsupportedOrRepeated
        public var errorDescription: String? { "Choose one supported audio check: loop60, loop300, sequential300, ui60, ui-loop300-panels, ui-sequential300-panels, loop60-near2x, loop300-near2x, ui-loop300-panels-near2x, loop60-near2x-44100, loop300-near2x-44100 or ui-loop300-panels-near2x-44100." }
    }

    /// Process arguments include the executable. Other system launch arguments are ignored.
    public static func parse(arguments: [String]) throws -> Self? {
        let requests=arguments.dropFirst().filter { $0 == "--audio-check" || $0.hasPrefix("--audio-check=") }
        guard !requests.isEmpty else { return nil }
        guard requests.count == 1, let request=requests.first,
              request.hasPrefix("--audio-check="),
              let preset=Self(rawValue:String(request.dropFirst("--audio-check=".count))) else {
            throw InvalidArgument.unsupportedOrRepeated
        }
        return preset
    }
}
