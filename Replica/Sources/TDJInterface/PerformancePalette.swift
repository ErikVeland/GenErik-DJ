import SwiftUI

/// Graphite performance palette: near-black stage, bevelled graphite panels, cyan accent,
/// green active sync, red playhead and position marker.
enum PerformancePalette {
    static let cyan = Color(red: 0.49, green: 0.87, blue: 0.90)
    static let panel = Color(red: 0.105, green: 0.115, blue: 0.125)
    static let stage = Color(red: 0.045, green: 0.05, blue: 0.055)
    static let frame = Color(red: 0.19, green: 0.205, blue: 0.22)
    static let raised = Color(red: 0.235, green: 0.25, blue: 0.27)
    static let sunken = Color(red: 0.07, green: 0.075, blue: 0.08)
    static let red = Color(red: 0.93, green: 0.27, blue: 0.22)
    static let syncGreen = Color(red: 0.25, green: 0.86, blue: 0.27)
    static let syncGreenBackground = Color(red: 0.07, green: 0.2, blue: 0.08)
    static let text = Color(white: 0.9)
    static let secondaryText = Color(white: 0.6)
    /// Waveform layers, outermost first: low body, mid band, high core.
    static let waveLow = Color(red: 0.2, green: 0.36, blue: 0.62)
    static let waveMid = Color(red: 0.55, green: 0.89, blue: 0.91)
    static let waveHigh = Color(red: 0.9, green: 0.98, blue: 1)
    static let beatLine = Color(white: 0.42)
}

/// A raised graphite panel with a soft top highlight and dark lower edge.
struct BevelPanel: ViewModifier {
    var cornerRadius: CGFloat = 4
    var sunken = false
    func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(LinearGradient(colors: sunken ? [PerformancePalette.sunken, PerformancePalette.stage]
                                                    : [PerformancePalette.raised, PerformancePalette.frame],
                                     startPoint: .top, endPoint: .bottom))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(LinearGradient(colors: [Color.white.opacity(sunken ? 0.04 : 0.14), Color.black.opacity(0.6)],
                                                     startPoint: .top, endPoint: .bottom), lineWidth: 1)
                }
        }
    }
}

extension View {
    func bevelPanel(cornerRadius: CGFloat = 4, sunken: Bool = false) -> some View {
        modifier(BevelPanel(cornerRadius: cornerRadius, sunken: sunken))
    }
}

/// Square rail buttons: bevelled graphite, cyan when pressed.
struct BevelButtonStyle: ButtonStyle {
    var active = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(active ? PerformancePalette.cyan : PerformancePalette.text.opacity(0.85))
            .bevelPanel(cornerRadius: 3, sunken: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// Stacked waveform bars marking audio long enough to be a DJ mix.
struct MixBadge: View {
    var size: CGFloat = 12
    var body: some View {
        VStack(spacing: size * 0.12) {
            ForEach([0.55, 1.0, 0.75], id: \.self) { width in
                Capsule().fill(PerformancePalette.cyan).frame(width: size * width, height: size * 0.2)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement().accessibilityLabel("Mix")
    }
}
