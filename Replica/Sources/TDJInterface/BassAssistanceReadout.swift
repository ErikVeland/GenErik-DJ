import SwiftUI
import TDJCore

struct BassAssistanceReadout: View {
    let mode: BassAssistanceMode
    let meter: BassAssistanceMeter

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if meter.available {
                Text("Bass cancellation estimate: \(meter.cancellationDB, specifier: "%.1f") dB")
                if mode == .handover, let leader = meter.leader {
                    Text("\(leader == .a ? "A" : "B") leads the bass")
                    Text(
                        "Bass cut · A: \(meter.reductionADB, specifier: "%.1f") dB · B: \(meter.reductionBDB, specifier: "%.1f") dB"
                    )
                }
            } else {
                Text("Waiting for overlapping bass on two decks.")
            }
            Text("Uses A on the left crossfader side and B on the right. Available for two-deck playback.")
        }
        .font(.caption).foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}
