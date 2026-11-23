#if os(iOS)
import SwiftUI
import TDJCore
import UIKit

@MainActor private final class WaveformDisplayClock: NSObject, ObservableObject {
    @Published private(set) var frame: Double?
    private var link: CADisplayLink?
    private var read: (() -> (frame: Double, framesPerSecond: Double)?)?
    private var previousTime: Double?

    func start(read: @escaping () -> (frame: Double, framesPerSecond: Double)?) {
        stop()
        self.read = read
        frame = read()?.frame
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = .init(minimum: 30, maximum: 120, preferred: 120)
        self.link = link
        link.add(to: .main, forMode: .common)
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.targetTimestamp
        defer { previousTime = now }
        guard let sample = read?() else { return }
        var next = sample.frame
        if let frame, let previousTime {
            let elapsed = now - previousTime
            let distance = sample.frame - frame
            let step = elapsed * sample.framesPerSecond
            // Advance between audio buffers. A wrap or seek takes effect immediately.
            if elapsed > 0, elapsed < 0.05, step * distance > 0,
               abs(distance) <= abs(sample.framesPerSecond) * 0.05 {
                next = frame + (abs(step) < abs(distance) ? step : distance)
            }
        }
        if frame != next { frame = next }
    }

    func stop() {
        link?.invalidate()
        link = nil
        previousTime = nil
        read = nil
    }
}

@MainActor struct ScrollingDeckWaveform: View {
    let model: ReplicaModel
    let deck: DeckID
    let track: Track
    let visibleSeconds: Double
    let grid: BeatGrid?
    let map: BeatGridMap?
    let band: BandWaveform?
    let sections: [ArrangementSection]
    let generation: UInt64
    let initialFrame: Double
    let size: CGSize
    @StateObject private var clock = WaveformDisplayClock()

    var body: some View {
        let center = clock.frame ?? initialFrame
        let span = max(1, visibleSeconds * track.analysis.sampleRate)
        let stride = span / 2
        let anchor = (center / stride).rounded() * stride
        ZStack {
            WaveformView(track: track, grid: nil, centerFrame: anchor, visibleSeconds: visibleSeconds * 1.5,
                         band: band, sections: sections)
                .equatable().frame(width: size.width * 1.5, height: size.height)
                .offset(x: (anchor - center) / span * size.width)
            Canvas { context, bounds in
                if let grid {
                    WaveformView.drawBeats(WaveformLayers.beatLines(
                        grid: grid, adaptiveMap: map, left: center - span / 2, span: span,
                        width: max(1, Int(bounds.width))), in: &context, size: bounds, scale: 1)
                }
            }
            Rectangle().fill(PerformancePalette.red).frame(width: 2)
            ArrangementWaveformOverlay(model: model, deck: deck, track: track, center: center, span: span)
            PerformanceOverlay(model: model, deck: deck, span: span, center: center)
        }.frame(width: size.width, height: size.height).clipped()
            .onAppear {
                let core = model.playback.core
                clock.start { [deck, generation] in core.waveformPosition(deck: deck, generation: generation) }
            }
            .onDisappear { clock.stop() }
    }
}
#endif
