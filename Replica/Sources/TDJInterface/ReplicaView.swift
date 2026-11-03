import SwiftUI
import TDJCore
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

private let deckBlue = PerformancePalette.cyan
private let surface = PerformancePalette.panel

@MainActor
public struct ReplicaView: View {
    @State private var model: ReplicaModel
    @State private var importPresented = false
    @State private var traktorImportPresented = false
    @State private var tempoWheelVisible = false
    @State private var audioSettingsPresented = false
    @State private var deckShare = 0.28
    @State private var dividerOrigin: Double?
    @GestureState private var resizingLibrary = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let snapshotEffectsDeck: DeckID?
    private let snapshotMixerDecks: Set<DeckID>
    private let snapshotFilterDecks: Set<DeckID>
    @Environment(\.scenePhase) private var scenePhase
    public init(model: ReplicaModel, snapshotEffectsDeck: DeckID? = nil,
                snapshotMixerDecks: Set<DeckID> = [], snapshotFilterDecks: Set<DeckID> = []) {
        _model = State(initialValue:model); self.snapshotEffectsDeck = snapshotEffectsDeck
        self.snapshotMixerDecks=snapshotMixerDecks; self.snapshotFilterDecks=snapshotFilterDecks
    }

    public var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                if model.helpVisible { GestureHelp { model.helpVisible=false }.frame(width:280) }
                performanceSurface.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .background(PerformancePalette.frame.ignoresSafeArea())
#if os(iOS)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
#endif
    }
    private var performanceSurface: some View {
        VStack(spacing: 0) {
            PerformanceToolbar(model:model,tempoWheelVisible:$tempoWheelVisible,
                audioSettingsPresented:$audioSettingsPresented,
                importPresented:$importPresented,traktorImportPresented:$traktorImportPresented)
            GeometryReader { space in
                let deckHeight = AdaptivePerformanceLayout.deckHeight(available: space.size.height,
                    browserVisible: model.browserVisible, share: deckShare)
                VStack(spacing: 0) {
                    HStack(spacing: 2) {
                        VStack(spacing: 2) {
                            DeckView(model: model, deck: .a,
                                snapshotEffects: snapshotEffectsDeck == .a,
                                snapshotMixer: snapshotMixerDecks.contains(.a), snapshotFilter: snapshotFilterDecks.contains(.a))
                            DeckView(model: model, deck: .b,
                                snapshotEffects: snapshotEffectsDeck == .b,
                                snapshotMixer: snapshotMixerDecks.contains(.b), snapshotFilter: snapshotFilterDecks.contains(.b))
                        }
                        CrossfaderView(model: model, width: 52)
                    }.padding(.horizontal, 6).frame(height: deckHeight)
                    Group {
                        Capsule().fill(PerformancePalette.secondaryText.opacity(0.5))
                            .frame(width: 44, height: 4)
                            .frame(maxWidth: .infinity).frame(height: AdaptivePerformanceLayout.dividerHeight)
                            .background(PerformancePalette.frame).contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .global)
                                .updating($resizingLibrary) { _, active, _ in active = true }
                                .onChanged { value in
                                    if dividerOrigin == nil { dividerOrigin = deckHeight }
                                    if !model.browserVisible { model.browserVisible = true }
                                    deckShare = ((dividerOrigin ?? deckHeight) + value.translation.height) / max(1, space.size.height)
                                }
                                .onEnded { _ in
                                    deckShare = AdaptivePerformanceLayout.deckHeight(available: space.size.height,
                                        browserVisible: true, share: deckShare) / max(1, space.size.height)
                                    if space.size.height - deckShare * space.size.height < AdaptivePerformanceLayout.librarySnapDistance {
                                        model.browserVisible = false
                                    }
                                    dividerOrigin = nil
                                })
                            .accessibilityLabel("Deck and library divider")
                            .accessibilityAdjustableAction { direction in
                                deckShare = min(0.8, max(0.1, deckShare + (direction == .increment ? 0.05 : -0.05)))
                            }
                        BrowserView(model: model, importAudio: { importPresented = true }, linkCollection: { traktorImportPresented = true })
                            .frame(maxWidth: .infinity)
                            .frame(height: max(0, space.size.height - deckHeight - AdaptivePerformanceLayout.dividerHeight), alignment: .top)
                            .clipped().allowsHitTesting(model.browserVisible)
                            .disabled(!model.browserVisible).accessibilityHidden(!model.browserVisible)
                    }
                }
                .frame(width: space.size.width, height: space.size.height, alignment: .top)
                .animation(reduceMotion || dividerOrigin != nil ? nil : .smooth(duration: 0.25), value: model.browserVisible)
                .onChange(of: resizingLibrary) { _, active in if !active { dividerOrigin = nil } }
                .onChange(of: model.browserVisible) { _, visible in
                    if visible && !resizingLibrary { deckShare = 0.28 }
                }
            }

        }
        .background(PerformancePalette.frame).foregroundStyle(PerformancePalette.text).buttonStyle(.plain)
        .preferredColorScheme(.dark)
        .task {
            ReplicaLifecycle.register(model)
            model.startPlaybackMonitor()
            async let music: Void = model.openNativeMusicLibrary()
            await model.refreshTraktorPreparation()
            await music
            // Launch argument for the clean-room comparison: -reference-benchmark <count>.
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "-reference-benchmark"), index + 1 < arguments.count, let count = Int(arguments[index + 1]) {
                _ = await model.runReferenceBenchmark(count: count)
            }
        }
        .onDisappear { model.stopPlaybackMonitor(); ReplicaLifecycle.suspend(model) }
        .onChange(of: scenePhase) { _, phase in
#if os(iOS)
            if phase == .background { ReplicaLifecycle.background(model) }
#endif
            if phase == .active {
                model.startPlaybackMonitor()
                Task {
                    async let music: Void = model.openNativeMusicLibrary()
                    await model.refreshTraktorPreparation(force:true)
                    await music
                }
            }
        }
        .fileImporter(isPresented: $traktorImportPresented, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls): if let url = urls.first { Task { await model.importTraktorPreparation(url) } }
            case .failure(let error): model.status = error.localizedDescription
            }
        }
        .fileImporter(isPresented: $importPresented, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): Task { await model.importFiles(urls) }
            case .failure(let error): model.status = error.localizedDescription
            }
        }
    }
}


/// Preserve the selector's six-row menu below the waveform while clipping sideways motion.
private struct DeckPanelHorizontalBounds: Shape {
    func path(in rect: CGRect) -> Path {
        Path(rect.insetBy(dx:0,dy:-168))
    }
}

/// Build drawers before performance, then move their retained layers. Closing still cancels contacts.
@MainActor
private struct SlidingDeckPanel<Content: View>: View {
    let isPresented: Bool
    let edge: Edge
    let panelWidth: CGFloat
    let inputGate: TouchSurfaceInputGate
    @ViewBuilder var content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var alignment: Alignment { edge == .leading ? .leading : .trailing }
    var body: some View {
        ZStack(alignment:alignment) {
            content()
                .environment(\.deckPanelPresented,isPresented)
                .geometryGroup()
                .offset(x:isPresented ? 0:(edge == .leading ? -panelWidth:panelWidth))
        }
        .frame(maxWidth:.infinity,maxHeight:.infinity,alignment:alignment)
        .clipShape(DeckPanelHorizontalBounds())
        .allowsHitTesting(isPresented)
        .disabled(!isPresented)
        .accessibilityHidden(!isPresented)
        .onAppear { inputGate.setEnabled(isPresented) }
        .onChange(of:isPresented) { _,presented in inputGate.setEnabled(presented) }
        .onDisappear { inputGate.setEnabled(false) }
        .animation(reduceMotion ? nil : .smooth(duration:0.22,extraBounce:0),value:isPresented)
    }
}

@MainActor
private struct DeckView: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    var snapshotEffects = false
    var snapshotMixer = false
    var snapshotFilter = false
    @State private var visibleSeconds = WaveformLayers.defaultSeconds(bpm: nil)
    @State private var previousSpan: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var toolsVisible = false
    @State private var mixerVisible = false
    @State private var mixerPanel = MixerPanel.equalizer
    @State private var effectsVisible = false
    @State private var effectsInput=TouchSurfaceInputGate()
    @State private var mixerInput=TouchSurfaceInputGate()
    @AppStorage(DeckToolSettings.tempoFader) private var tempoFader = false
    @AppStorage(DeckToolSettings.cueButton) private var cueButton = false
    @AppStorage(DeckToolSettings.hotcuePads) private var hotcuePads = false
    private var track: Track? { model.track(deck) }
    private var editing: Bool { model.editing.contains(deck) }
    private var playback: DeckPlaybackSnapshot? { model.playbackSnapshot?[deck] }
    var body: some View {
        GeometryReader { deckSpace in
        let layout = AdaptiveDeckGeometry(height: max(0, deckSpace.size.height - 8),
            hotcues: (hotcuePads || model.hotcuePadsVisible.contains(deck)) && track != nil)
        HStack(spacing: 4) {
        ZStack(alignment: .topLeading) {
        Button { model.showSuggestions(destination: deck) } label: {
            DeckArtwork(source: ArtworkSource.track(track, media: model.store.mediaDirectory))
                .frame(width: 44, height: 44).background(PerformancePalette.sunken).clipped()
        }.accessibilityLabel("Suggestions for deck \(deck.rawValue.uppercased())")
            .offset(y: (1 - layout.expansion) * max(0, (deckSpace.size.height - 52) / 2))
        VStack(spacing: 0) {
            DeckHeader(model: model, deck: deck, showsArtwork: false)
                .frame(height: layout.headerHeight, alignment: .top).clipped()
                .opacity(layout.expansion).allowsHitTesting(layout.headerHeight >= 44)
            if track != nil {
                ArrangementDeckStrip(model: model, deck: deck)
                    .frame(height: layout.sectionHeight).clipped().opacity(layout.expansion)
                    .allowsHitTesting(layout.sectionHeight >= 24)
            }
            GeometryReader { geometry in
                DeckWaveform(model:model,deck:deck,visibleSeconds:$visibleSeconds,mixerVisible:mixerVisible)
                .overlay(alignment:.leading) {
                    SlidingDeckPanel(isPresented:(effectsVisible || snapshotEffects) && layout.waveformHeight >= 44,edge:.leading,
                                     panelWidth:geometry.size.width/2,inputGate:effectsInput) {
                        EffectsView(model:model,deck:deck).frame(width:geometry.size.width/2)
                            .environment(\.touchSurfaceInputGate,effectsInput)
                    }
                }
                .overlay(alignment:.trailing) {
                    SlidingDeckPanel(isPresented:(mixerVisible || snapshotMixer) && layout.waveformHeight >= 44,edge:.trailing,
                                     panelWidth:geometry.size.width/2,inputGate:mixerInput) {
                        DeckMixerView(model:model,deck:deck,panel:snapshotFilter ? .constant(.filter) : $mixerPanel,
                                      width:geometry.size.width/2)
                            .environment(\.touchSurfaceInputGate,mixerInput)
                    }
                }
            }
            .frame(height: layout.waveformHeight)
            .clipShape(DeckPanelHorizontalBounds()).allowsHitTesting(layout.waveformHeight >= 44)
            .zIndex(effectsVisible || snapshotEffects ? 1 : 0)
            HStack(spacing: 6) {
                Text(elapsedTime).frame(width: 48, alignment: .trailing)
                DeckOverview(model: model, deck: deck, visibleSeconds: $visibleSeconds)
                    .frame(maxWidth: .infinity)
                Text(remainingTime).frame(width: 60, alignment: .leading)
            }.font(.system(size: 13).monospacedDigit())
                .frame(height: layout.overviewHeight)
            if (hotcuePads || model.hotcuePadsVisible.contains(deck)) && track != nil {
                HotcuePadRow(model: model, deck: deck).frame(height: layout.hotcueHeight).clipped()
                    .allowsHitTesting(layout.hotcueHeight >= 44)
            }
            DeckFooter(model: model, deck: deck)
                .frame(height: layout.footerHeight).clipped().opacity(layout.expansion)
        }.padding(.leading, 52)
        }
        if tempoFader && track != nil { DeckTempoFader(model:model,deck:deck) }
        ScrollView(.vertical) {
            VStack(spacing: 8) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    Button("FX") {
                        effectsInput.setEnabled(!effectsVisible); effectsVisible.toggle()
                    }.foregroundStyle(effectsVisible ? Color.orange : PerformancePalette.secondaryText)
                        .accessibilityLabel("Effects for deck \(deck.rawValue.uppercased())")
                    Button("EQ") {
                        mixerInput.setEnabled(!mixerVisible); mixerVisible.toggle()
                    }.foregroundStyle(mixerVisible ? PerformancePalette.cyan : PerformancePalette.secondaryText)
                        .accessibilityLabel("EQ and filter for deck \(deck.rawValue.uppercased())")
                    Button { model.toggleLoop(deck: deck) } label: { Image(systemName: "repeat") }
                        .foregroundStyle(playback?.loopEnabled == true ? PerformancePalette.syncGreen : PerformancePalette.text)
                        .disabled(track == nil).accessibilityLabel("Loop on deck \(deck.rawValue.uppercased())")
                    if cueButton {
                        Button("CUE") { model.pressCue(deck: deck) }.disabled(track == nil)
                            .accessibilityLabel("Cue on deck \(deck.rawValue.uppercased())")
                    }
                }
                if track != nil { PerformanceControls(model: model, deck: deck) }
            }.padding(8)
        }
        .font(.system(size: 17, weight: .semibold))
        .buttonStyle(PerformanceToolButtonStyle())
        .frame(width: toolsVisible ? AdaptivePerformanceLayout.panelWidth(available: deckSpace.size.width) : 0)
        .background(PerformancePalette.sunken).clipped()
        .allowsHitTesting(toolsVisible)
        .disabled(!toolsVisible).accessibilityHidden(!toolsVisible)
        ZStack {
            Button {
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.22)) { toolsVisible.toggle() }
            } label: { Image(systemName: toolsVisible ? "sidebar.right" : "slider.horizontal.3") }
                .frame(width: 64, height: 44)
                .position(x: 32, y: 22)
                .accessibilityLabel("\(toolsVisible ? "Hide" : "Show") controls for deck \(deck.rawValue.uppercased())")
            Button { model.setMixer(.cue, value: playback?.mixer.cue == true ? 0 : 1, deck: deck) } label: {
                Image(systemName: "headphones")
                    .foregroundStyle(playback?.mixer.cue == true ? PerformancePalette.cyan : PerformancePalette.secondaryText)
            }.frame(width: 64, height: 50)
                .position(x: 32, y: max(25, deckSpace.size.height - 92))
                .opacity(min(1, max(0, (deckSpace.size.height - 164) / 48)))
                .allowsHitTesting(deckSpace.size.height >= 212)
                .accessibilityHidden(deckSpace.size.height < 212)
                .accessibilityLabel("Headphone cue for deck \(deck.rawValue.uppercased())")
            DeckPlaybackButton(model: model, deck: deck)
                .frame(width: 64, height: 50)
                .position(x: 32 + 64 * (1 - layout.expansion), y: max(25, deckSpace.size.height - 33))
        }.font(.system(size: 24, weight: .heavy))
            .buttonStyle(DeckRailButtonStyle()).frame(width: layout.transportWidth)
        }.padding(4).background(PerformancePalette.stage).bevelPanel(cornerRadius: 6, sunken: true)
        }
        .zIndex(effectsVisible || snapshotEffects ? 1 : 0)
        .onChange(of:track?.id,initial:true) { _,_ in
            // About four and a half beats, centred on the playhead.
            visibleSeconds=WaveformLayers.defaultSeconds(bpm:track?.bpm)
        }
        .onChange(of:model.frozen.contains(deck)) { _,enabled in
            if enabled,let track,let state=playback,state.loopEnabled {
                previousSpan=visibleSeconds
                visibleSeconds=(state.loopEnd-state.loopStart)/track.analysis.sampleRate
                model.viewport[deck]=(state.loopStart+state.loopEnd)/2
            } else if !enabled,let previousSpan { visibleSeconds=previousSpan; self.previousSpan=nil }
        }
    }
    private var preparing: Bool { model.preparingPlayback.contains(deck) }
    private var elapsedTime: String {
        let seconds = max(0, Int((playback?.sourceFrame ?? 0) / (track?.analysis.sampleRate ?? 1)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
    private var remainingTime: String {
        let seconds = max(0, Int(ceil((track?.analysis.duration ?? 0) - (playback?.sourceFrame ?? 0) / (track?.analysis.sampleRate ?? 1))))
        return String(format: "−%d:%02d", seconds / 60, seconds % 60)
    }


}

private struct DeckRailButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(maxWidth: .infinity, maxHeight: .infinity)
            .bevelPanel(cornerRadius: 3, sunken: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

@MainActor
private struct StripeView: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let track: Track
    @Binding var visibleSeconds: Double
    let navigate: (Double) -> Void
    @State private var zoomStart: Double?
    @State private var contacts: [SurfacePoint] = []
    @State private var zooming=false
    var body: some View {
        GeometryReader { geometry in
            WaveformView(track: track, grid: nil, centerFrame: Double(track.analysis.frameCount) / 2,
                         visibleSeconds: track.analysis.duration).equatable()
                .overlay { ArrangementWaveformOverlay(model:model,deck:deck,track:track,center:Double(track.analysis.frameCount)/2,span:Double(track.analysis.frameCount),overview:true) }
                .overlay(alignment: .leading) {
                    StripeViewportMarker(model:model,deck:deck,width:geometry.size.width,
                        frameCount:Double(track.analysis.frameCount),duration:track.analysis.duration,
                        visibleSeconds:visibleSeconds)
                }.clipped().contentShape(Rectangle())
                .overlay {
                    TouchSurface { event in
                        if event.phase == .cancelled { contacts=[]; zoomStart=nil; zooming=false; return }
                        if event.points.count>=2 {
                            if !zooming { contacts=event.points; zoomStart=visibleSeconds; zooming=true }
                            let before=max(0.01,abs(contacts[1].x-contacts[0].x))
                            let after=max(0.01,abs(event.points[1].x-event.points[0].x))
                            visibleSeconds=max(min(1,track.analysis.duration),min(track.analysis.duration,(zoomStart ?? visibleSeconds)*before/after))
                        } else if !zooming,let point=event.points.first,event.phase != .began {
                            navigate(Double(track.analysis.frameCount)*max(0,min(1,point.x)))
                        }
                        if event.phase == .ended && event.remaining.isEmpty { contacts=[]; zoomStart=nil; zooming=false }
                    }
                }
#if os(macOS)
                .simultaneousGesture(MagnifyGesture().onChanged { value in
                    if zoomStart == nil { zoomStart=visibleSeconds }
                    visibleSeconds=max(min(1,track.analysis.duration),min(track.analysis.duration,(zoomStart ?? 8)/value.magnification))
                }.onEnded { _ in zoomStart=nil })
#endif
        }
    }
}

@MainActor
private struct StripeViewportMarker: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let width: CGFloat
    let frameCount: Double
    let duration: Double
    let visibleSeconds: Double
    var body: some View {
        let fraction=(model.viewport[deck] ?? 0)/frameCount
        let window=max(10,width*visibleSeconds/duration)
        RoundedRectangle(cornerRadius:2).stroke(PerformancePalette.red,lineWidth:2)
            .frame(width:max(6,window)).offset(x:width*fraction-max(6,window)/2)
    }
}

private struct WaveformView: View, Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        WaveformIndexKey(lhs.track.analysis) == WaveformIndexKey(rhs.track.analysis)
            && lhs.track.analysis.frameCount == rhs.track.analysis.frameCount
            && lhs.track.analysis.sampleRate == rhs.track.analysis.sampleRate
            && lhs.grid == rhs.grid && lhs.adaptiveMap == rhs.adaptiveMap && lhs.centerFrame == rhs.centerFrame
            && lhs.visibleSeconds == rhs.visibleSeconds && lhs.playheadFrame == rhs.playheadFrame
            && lhs.leadInFrame == rhs.leadInFrame && (lhs.band == nil) == (rhs.band == nil)
    }
    /// A filled shape mirrored about the centre line, one vertex per device pixel, anti-aliased.
    static func mirrored(_ heights: [Double], scale: Double, middle: Double) -> Path {
        var path=Path()
        guard !heights.isEmpty else { return path }
        path.move(to:CGPoint(x:0,y:middle-heights[0]))
        for (x,h) in heights.enumerated() { path.addLine(to:CGPoint(x:Double(x)/scale,y:middle-h)) }
        for (x,h) in heights.enumerated().reversed() { path.addLine(to:CGPoint(x:Double(x)/scale,y:middle+h)) }
        path.closeSubpath()
        return path
    }
    /// Low body (translucent dark blue), mids (cyan), then transients (near white) on top.
    static func draw(_ bands: BandWaveformColumns, in context: inout GraphicsContext, size: CGSize, scale: Double) {
        let middle=size.height/2
        context.fill(mirrored(bands.low,scale:scale,middle:middle),with:.color(PerformancePalette.waveLow.opacity(0.92)))
        context.fill(mirrored(bands.mid,scale:scale,middle:middle),with:.color(PerformancePalette.waveMid.opacity(0.95)))
        context.fill(mirrored(bands.high,scale:scale,middle:middle),with:.color(PerformancePalette.waveHigh.opacity(0.9)))
    }
    /// Stored-bin fallback while the band waveform is prepared: peak, RMS and core as smooth shapes.
    static func draw(_ layers: WaveformLayers, in context: inout GraphicsContext, size: CGSize, scale: Double) {
        let middle=size.height/2,count=Int(size.width*scale)
        for keyPath in [\WaveformLayers.Column.peak,\WaveformLayers.Column.body,\WaveformLayers.Column.core] {
            var heights=[Double](repeating:0,count:max(0,count))
            for column in layers.columns where column.x<count { heights[column.x]=column[keyPath:keyPath] }
            let colour=keyPath == \WaveformLayers.Column.peak ? PerformancePalette.waveLow : keyPath == \WaveformLayers.Column.body ? PerformancePalette.waveMid : PerformancePalette.waveHigh
            context.fill(mirrored(heights,scale:scale,middle:middle),with:.color(colour))
        }
    }
    /// Bar lines brighter than beat lines. Positions are in device pixels.
    static func drawBeats(_ beats: [(x: Double, downbeat: Bool)], in context: inout GraphicsContext, size: CGSize, scale: Double) {
        for beat in beats {
            let x=beat.x/scale
            var line=Path(); line.move(to:CGPoint(x:x,y:0)); line.addLine(to:CGPoint(x:x,y:size.height))
            context.stroke(line,with:.color(beat.downbeat ? Color(white:0.82) : PerformancePalette.beatLine.opacity(0.5)),lineWidth:beat.downbeat ? 1.5 : 1)
        }
    }
    let track: Track
    let grid: BeatGrid?
    let centerFrame: Double
    let visibleSeconds: Double
    var adaptiveMap: BeatGridMap? = nil
    var playheadFrame: Double? = nil
    var leadInFrame: Double? = nil
    var band: BandWaveform? = nil
    @Environment(\.displayScale) private var displayScale
    @State private var prepared: (WaveformIndexKey,WaveformRangeIndex)?
    @Environment(\.snapshotWaveformIndexes) private var snapshotIndexes
    var body: some View {
        Canvas { context, size in
            let a = track.analysis
            let span = max(1, visibleSeconds * a.sampleRate)
            let left = centerFrame - span / 2
            let key=WaveformIndexKey(a)
            let scale=max(1,Double(displayScale)),pixels=max(1,Int(size.width*scale))
            if let band, band.frameCount == a.frameCount {
                WaveformView.draw(BandWaveformColumns(band,left:left,span:span,pixelWidth:pixels,height:size.height),
                                  in:&context,size:size,scale:scale)
            } else if let index = (prepared?.0 == key ? prepared?.1 : nil) ?? snapshotIndexes[key] {
                WaveformView.draw(WaveformLayers(index:index,framesPerBin:a.waveformFramesPerBin,left:left,span:span,
                                                 width:pixels,height:size.height),in:&context,size:size,scale:scale)
            }
            if let grid,let index=(prepared?.0 == key ? prepared?.1 : nil) ?? snapshotIndexes[key] {
                WaveformView.drawBeats(WaveformLayers(index:index,framesPerBin:a.waveformFramesPerBin,left:left,span:span,
                                                      width:pixels,height:0,grid:grid,adaptiveMap:adaptiveMap).beats,in:&context,size:size,scale:scale)
            }
            let perPixel = span / max(1, size.width)
            for (frame, colour, width) in [(playheadFrame, PerformancePalette.red, 2.0), (leadInFrame, Color(white: 0.8), 1.0)] {
                if let frame {
                    let x = (frame - left) / perPixel
                    var marker = Path(); marker.move(to: CGPoint(x: x, y: 0)); marker.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(marker, with: .color(colour), lineWidth: width)
                }
            }
        }.clipped().task(id:WaveformIndexKey(track.analysis)) {
            let key=WaveformIndexKey(track.analysis)
            let index=await WaveformIndexes.shared.load(track.analysis)
            guard !Task.isCancelled else { return }
            prepared=(key,index)
        }
    }
}

@MainActor
struct LoadSlider: View {
    var tall = false
    let load: (DeckID) -> Void
    @State private var gesture = LoadSliderGestureSession()
    @State private var contactActive = false
    @GestureState private var dragging = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var maximumTravel: Double { tall ? TallLoadSliderMetrics.maximumTravel : 18 }
    var body: some View {
        VStack(spacing: 0) {
            Text("A").font(.system(size: tall ? 28 : 9, weight: .heavy))
                .foregroundStyle(gesture.armedDeck == .a ? PerformancePalette.cyan : Color(white: tall ? 0.45 : 0.88))
                .frame(height: tall ? TallLoadSliderMetrics.labelHeight : nil)
            ZStack {
                if tall { RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.3)) }
                VStack(spacing: 2) {
                    if tall { Image(systemName: "chevron.up").font(.system(size: 10)) }
                    Text("LOAD").font(.system(size: tall ? 17 : 10, weight: .bold))
                    if tall { Image(systemName: "chevron.down").font(.system(size: 10)) }
                }.padding(tall ? 4 : 6).frame(maxWidth: tall ? .infinity : nil)
                    .frame(height: tall ? TallLoadSliderMetrics.handleHeight : nil)
                    .bevelPanel(cornerRadius: 4).offset(y: gesture.offset)
            }.frame(height: tall ? TallLoadSliderMetrics.railHeight : nil)
            Text("B").font(.system(size: tall ? 28 : 9, weight: .heavy))
                .foregroundStyle(gesture.armedDeck == .b ? PerformancePalette.cyan : Color(white: tall ? 0.45 : 0.88))
                .frame(height: tall ? TallLoadSliderMetrics.labelHeight : nil)
        }.frame(width: tall ? 96 : 64, height: tall ? TallLoadSliderMetrics.height : 56).padding(tall ? 4 : 0)
            .background(RoundedRectangle(cornerRadius: 6).fill(PerformancePalette.sunken)).contentShape(Rectangle())
            .overlay {
                GeometryReader { geometry in
                    Color.clear.contentShape(Rectangle())
                        .highPriorityGesture(DragGesture(minimumDistance: 0)
                            .updating($dragging) { _, active, _ in active = true }
                            .onChanged { value in
                                if !contactActive {
                                    contactActive = true
                                    handle(.began, at: value.startLocation, size: geometry.size)
                                }
                                handle(.moved, at: value.location, size: geometry.size)
                            }
                            .onEnded { value in
                                handle(.ended, at: value.location, size: geometry.size)
                                contactActive = false
                            })
                }
            }
            .onChange(of: dragging) { _, active in
                if !active && contactActive {
                    contactActive = false
                    gesture = LoadSliderGestureSession()
                }
            }
            .accessibilityLabel("Load track. Drag up for deck A or down for deck B.")
            .accessibilityAction(named: "Load deck A") { load(.a) }
            .accessibilityAction(named: "Load deck B") { load(.b) }
            .onDisappear { contactActive = false; gesture = LoadSliderGestureSession() }
    }
    private func handle(_ phase: SurfaceEvent.Phase, at point: CGPoint, size: CGSize) {
        let event = SurfaceEvent(phase: phase,
            points: [.init(id: 1, x: point.x / max(1, size.width), y: point.y / max(1, size.height))],
            ending: phase == .ended ? [1] : [])
        let deck = gesture.handle(event, height: Double(size.height), maximumTravel: maximumTravel,
                                  edgeTapThreshold: tall ? 0.22 : nil, edgeTapMovementTolerance: 10)
        if phase == .ended {
            withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8)) {
                gesture = LoadSliderGestureSession()
            }
        }
        if let deck { load(deck) }
    }

}

extension ReplicaView {
    /// ImageRenderer does not mount asynchronous view tasks. Prepare its waveforms explicitly.
    public func preparedForSnapshot() async throws -> some View {
        try await model.prepareLoadedWaveforms()
        for deck in DeckID.allCases { await model.prepareArrangement(deck:deck) }
        var indexes: [WaveformIndexKey:WaveformRangeIndex]=[:]
        for deck in DeckID.allCases {
            if let track=model.track(deck) {
                indexes[WaveformIndexKey(track.analysis)]=await WaveformIndexes.shared.load(track.analysis)
            }
        }
        let collection = model.browserVisible ? try? await CollectionProjection.build(
            tracks:model.library.tracks, suggestionIDs:nil, search:"", sort:.title,
            category:.songs, group:nil, playlists:.init(), catalog:nil) : nil
        var bands: [String:BandWaveform]=[:]
        for deck in DeckID.allCases {
            if let track=model.track(deck) {
                _=try? PCMCache.prepare(track:track,store:model.store)
                bands[track.id]=await BandWaveforms.shared.load(track:track,store:model.store,patience:5)
            }
        }
        return environment(\.snapshotWaveformIndexes,indexes)
            .environment(\.snapshotCollectionProjection,collection)
            .environment(\.snapshotBandWaveforms,bands)
    }
}


// Keep playback observations in the leaf views that render them.

@MainActor
private struct PerformanceToolbar: View {
    @Bindable var model: ReplicaModel
    @Binding var tempoWheelVisible: Bool
    @Binding var audioSettingsPresented: Bool
    @Binding var importPresented: Bool
    @Binding var traktorImportPresented: Bool

    var body: some View {
            HStack(spacing: 12) {
                GenErikBrandLockup()
                Spacer(minLength: 8)
                HStack(spacing: 0) {
                    TimelineView(.everyMinute) { context in
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                            Text(context.date.formatted(date: .omitted, time: .shortened)).monospacedDigit()
                        }.padding(.horizontal, 14)
                    }
                    Divider().frame(height: 22)
                    MasterTempoButton(model:model,tempoWheelVisible:$tempoWheelVisible).padding(.horizontal, 14)
                        .popover(isPresented:$tempoWheelVisible) { TempoWheel(model:model).padding(16) }
                    BatteryReadout()
                }
                .font(.system(size: 16, weight: .medium)).foregroundStyle(PerformancePalette.text)
                .frame(height: 34).bevelPanel(cornerRadius: 6, sunken: true)
                if let progress = model.preparationImport {
                    PreparationImportPill(progress: progress).transition(.opacity)
                }
                if let progress = model.analysisProgress {
                    PreparationImportPill(progress: progress).transition(.opacity)
                }
                Spacer(minLength: 8)
                Button { model.helpVisible.toggle() } label: {
                    Image(systemName: "info.circle.fill").font(.system(size: 18))
                        .frame(width: 44, height: 34).bevelPanel(cornerRadius: 5)
                        .overlay(alignment: .topLeading) {
                            if noticeCount > 0 {
                                Text("\(noticeCount)").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                                    .frame(minWidth: 18, minHeight: 18).background(Circle().fill(PerformancePalette.red)).offset(x: -6, y: -6)
                            }
                        }
                }.accessibilityLabel("Notification Center")
                HStack(spacing: 0) {
                    Button { if model.browserVisible { model.browserVisible = false } else { model.showLibrary() } } label: {
                        Image(systemName: "music.note").font(.system(size: 18))
                            .foregroundStyle(model.browserVisible ? PerformancePalette.cyan : PerformancePalette.text)
                            .frame(width: 44, height: 34)
                    }.accessibilityLabel("Music library")
                    Divider().frame(height: 22)
                    Button { audioSettingsPresented.toggle() } label: {
                        Image(systemName: "speaker.wave.2.fill").font(.system(size: 16)).frame(width: 44, height: 34)
                    }
                    .accessibilityLabel("Audio routing")
                    .popover(isPresented: $audioSettingsPresented) { AudioQuickPanel(model: model) }
                }.bevelPanel(cornerRadius: 5)
            }.padding(.horizontal, 14).frame(height: 50)
            .background(LinearGradient(colors: [PerformancePalette.raised, PerformancePalette.frame], startPoint: .top, endPoint: .bottom))
            .animation(.easeOut(duration: 0.4), value: model.preparationImport)
            .animation(.easeOut(duration: 0.4), value: model.analysisProgress)

    }
    /// Unread problems: music library and analysis failures.
    private var noticeCount: Int { min(99, model.musicLibraryFailures.count + (model.musicLibraryError == nil ? 0 : 1)) }

}

/// RECORD, SPLIT OUTPUT and MASTER, as in the original speaker popover, with routing details below.
@MainActor
struct AudioQuickPanel: View {
    @Bindable var model: ReplicaModel
    @State private var details = false
    @State private var locationPrompt = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row("RECORD") {
                Button {
                    if model.isRecording { Task { await model.toggleRecording() } } else { locationPrompt = true }
                } label: {
                    Image(systemName: model.isRecording ? "stop.circle.fill" : "record.circle").font(.system(size: 26))
                        .foregroundStyle(model.isRecording ? PerformancePalette.red : PerformancePalette.text)
                }.disabled(model.recordingFinishing).accessibilityLabel(model.isRecording ? "Stop recording" : "Record")
            }
            Divider()
            row("SPLIT OUTPUT") {
                Toggle("", isOn: Binding(get: { model.outputRoute == .masterAndHeadphones },
                                         set: { model.setOutputRoute($0 ? .masterAndHeadphones : .stereoMaster) }))
                    .labelsHidden().disabled(model.isRecording || model.recordingFinishing).accessibilityLabel("Split output")
            }
            Divider()
            row("MASTER") {
                Slider(value: Binding(get: { model.playbackSnapshot?.masterGain ?? 0.5 }, set: { model.setMixer(.master, value: $0) }), in: 0...1)
                    .frame(width: 170).tint(PerformancePalette.cyan).accessibilityLabel("Master level")
            }
            Divider()
            DisclosureGroup("Routing and headphones", isExpanded: $details) {
                AudioSettingsView(model: model)
                HStack {
                    ForEach([DeckID.a, .b], id: \.self) { deck in
                        Button {
                            model.toggleKeylock(deck: deck)
                        } label: {
                            Label("Keylock \(deck.rawValue.uppercased())", systemImage: model.controlDisplay[deck].keylock == true ? "checkmark.circle.fill" : "circle")
                        }.disabled(model.track(deck) == nil || model.preparingPlayback.contains(deck) || model.controlDisplay[deck].phase == .queued)
                    }
                    Spacer()
                    Button { model.stopAudio() } label: { Label("Stop audio", systemImage: "stop.fill") }
                }
            }.padding(14).font(.system(size: 13))
        }
        .frame(width: 360).foregroundStyle(PerformancePalette.text).background(PerformancePalette.panel)
        .alert("Recording location", isPresented: $locationPrompt) {
            TextField("Venue or location", text: $model.recordingLocation)
            Button("Record") { Task { await model.toggleRecording() } }
            Button("Cancel", role: .cancel) { }
        } message: { Text("Add a venue or location for the recording filename.") }
    }
    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(PerformancePalette.secondaryText)
            Spacer()
            content()
        }.padding(.horizontal, 14).frame(height: 54)
    }
}

@MainActor
private struct BatteryReadout: View {
    var body: some View {
#if os(iOS)
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            let level = Self.level()
            if level >= 0 {
                HStack(spacing: 5) {
                    Image(systemName: "battery.75percent")
                    Text("\(Int((level * 100).rounded()))%").monospacedDigit()
                }.padding(.horizontal, 14)
                .overlay(alignment: .leading) { Divider().frame(height: 22) }
            }
        }
#else
        EmptyView()
#endif
    }
#if os(iOS)
    static func level() -> Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryLevel
    }
#endif
}

@MainActor
private struct DeckHeader: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    var showsArtwork = true
    @AppStorage(DeckToolSettings.beatJump) private var beatJump = false

    var body: some View {
            HStack(alignment:.top, spacing: 12) {
                if showsArtwork {
                Button { model.showSuggestions(destination: deck) } label: {
                    ZStack {
                        PerformancePalette.sunken
                        DeckArtwork(source:ArtworkSource.track(track,media:model.store.mediaDirectory))
                    }.frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 3))
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.black.opacity(0.7)))
                }.accessibilityLabel("Suggestions for deck \(deck.rawValue.uppercased())")
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(track?.title ?? "Deck \(deck.rawValue.uppercased())")
                            .font(.system(size: 19, weight: .semibold)).foregroundStyle(PerformancePalette.text).lineLimit(1)
                        if NativeAnalysisPlan.isMix(duration: track?.analysis.duration) { MixBadge(size: 14) }
                    }
                    HStack(spacing: 10) {
                        Text(track?.artist ?? "Swipe up to browse your collection").lineLimit(1)
                        if track != nil {
                            HStack(spacing: 3) {
                                Image(systemName: playback?.keylock == true ? "lock.fill" : "music.note").font(.system(size: 11))
                                Text(track?.key?.openKeyName ?? "—")
                            }.accessibilityLabel("Key. Keylock \(playback?.keylock == true ? "on" : "off")")
                            HStack(spacing: 3) {
                                Image(systemName: "waveform.path.ecg").font(.system(size: 11))
                                DeckTempoReadout(model:model,deck:deck)
                            }
                        }
                    }.font(.system(size: 15)).foregroundStyle(PerformancePalette.secondaryText)
                }
                Spacer()
                if editing { GridEditBar(model: model, deck: deck) } else {
                if beatJump && track != nil {
                    ForEach([-1.0, 1.0], id: \.self) { direction in
                        Button { model.beatJump(beats: direction * model.performance.loopBeats(for: deck), deck: deck) } label: {
                            Image(systemName: direction < 0 ? "chevron.left.2" : "chevron.right.2").font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(PerformancePalette.text).frame(width: 54, height: 36).bevelPanel(cornerRadius: 3)
                        }.accessibilityLabel("Beat jump \(direction < 0 ? "back" : "forward") on deck \(deck.rawValue.uppercased())")
                    }
                }
                Button { model.toggleSync(deck: deck) } label: {
                    Text("SYNC").font(.system(size: 17, weight: .medium))
                        .foregroundStyle(syncColour).padding(.horizontal, 12).frame(height: 36)
                        .background(RoundedRectangle(cornerRadius: 3).fill(playback?.synced == true ? PerformancePalette.syncGreenBackground : PerformancePalette.sunken))
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.white.opacity(0.08)))
                }.disabled(track == nil || preparing).accessibilityLabel("Sync deck \(deck.rawValue.uppercased())")
                Button {
                    model.toggleGridEditing(deck:deck)
                } label: {
                    Image(systemName: "chart.bar.fill").rotationEffect(.degrees(90)).font(.system(size: 15))
                        .foregroundStyle(editing ? Color.orange : PerformancePalette.text)
                        .frame(width: 44, height: 36).bevelPanel(cornerRadius: 3)
                }
                    .disabled(track == nil || preparing || playback?.phase == .queued).accessibilityLabel("Edit grid on deck \(deck.rawValue.uppercased())")
                }
            }.padding(.horizontal, 12).padding(.vertical, 8)

    }
    private var track: Track? { model.track(deck) }
    private var playback: DeckControlDisplay? { model.controlDisplay[deck] }
    private var editing: Bool { model.editing.contains(deck) }
    private var preparing: Bool { model.preparingPlayback.contains(deck) }
    private var syncColour: Color {
        guard let playback, playback.synced else { return Color(white: 0.6) }
        if model.controlDisplay[deck].needsAlignment { return PerformancePalette.red }
        return PerformancePalette.syncGreen
    }
}

@MainActor
private struct DeckWaveform: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    @Binding var visibleSeconds: Double
    let mixerVisible: Bool
    @AppStorage(BrowserSettings.superSlicerKey) private var superSlicer = true

    var body: some View {
                Group {
                if let track {
                    HStack(spacing:0) {
                    if model.frozen.contains(deck), !editing, superSlicer { SuperSlicerControls(model:model,deck:deck) }
                    DeckWaveformDrawing(model:model,deck:deck,track:track,visibleSeconds:visibleSeconds)
                        .overlay {
                            if model.preparingSourceActions.contains(deck) {
                                Text("Preparing audio…").font(.caption).foregroundStyle(.secondary).allowsHitTesting(false)
                            } else if model.preparingWaveforms.contains(track.id) {
                                Text("Preparing waveform…").font(.caption).foregroundStyle(.secondary).allowsHitTesting(false)
                            }
                        }
                        .contentShape(Rectangle())
                        .overlay { PerformanceOverlay(model:model,deck:deck,span:visibleSeconds*track.analysis.sampleRate) }
                        .overlay(alignment:.topLeading) {
                            if editing, let grid=model.grid(deck) {
                                GridBeatMarkers(model:model,deck:deck,grid:grid,center:model.viewport[deck] ?? 0,
                                                span:visibleSeconds*track.analysis.sampleRate)
                            }
                        }
                        .overlay {
                            WaveformTouch(model:model,deck:deck,span:visibleSeconds*track.analysis.sampleRate) { frameSpan in
                                visibleSeconds=WaveformZoom.seconds(frameSpan:frameSpan,sampleRate:track.analysis.sampleRate,
                                                                    duration:track.analysis.duration)
                            }.id(track.id)
                        }
                    }

                } else {
                    ZStack {
                        Color.black.opacity(0.4)
                        Rectangle().fill(deckBlue.opacity(0.2)).frame(height: 1)
                        Text("No track loaded").font(.system(size: 12)).foregroundStyle(.secondary)
                    }.contentShape(Rectangle()).gesture(DragGesture(minimumDistance:40).onEnded { value in
                        if !mixerVisible && value.translation.height < -70 && abs(value.translation.height) > abs(value.translation.width) { model.showLibrary() }
                    })
                }
                }

    }
    private var track: Track? { model.track(deck) }
    private var editing: Bool { model.editing.contains(deck) }

}

@MainActor
private struct DeckWaveformDrawing: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let track: Track
    let visibleSeconds: Double
    @State private var band: (String, BandWaveform)?
    @Environment(\.snapshotBandWaveforms) private var snapshotBands
    var body: some View {
        WaveformView(track:track,grid:model.grid(deck),centerFrame:model.viewport[deck] ?? 0,
                     visibleSeconds:visibleSeconds,adaptiveMap:model.playbackSnapshot?[deck].adaptiveMap,playheadFrame:model.playbackSnapshot?[deck].sourceFrame,
                     leadInFrame:model.playbackSnapshot?[deck].leadInSourceFrame,
                     band:band?.0 == track.id ? band?.1 : snapshotBands[track.id])
        .overlay { ArrangementWaveformOverlay(model:model,deck:deck,track:track,center:model.viewport[deck] ?? 0,span:visibleSeconds*track.analysis.sampleRate) }
        .task(id:track.id) {
            let id=track.id
            guard let loaded=await BandWaveforms.shared.load(track:track,store:model.store),!Task.isCancelled else { return }
            band=(id,loaded)
        }
    }
}

@MainActor
private struct DeckOverview: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    @Binding var visibleSeconds: Double

    var body: some View {
            if let track {
                StripeView(model:model,deck:deck,track:track,visibleSeconds:$visibleSeconds) {
                    model.previewing.insert(deck); model.viewport[deck] = $0
                }.frame(height: 31)
            } else { Color.black.frame(height: 31) }

    }
    private var track: Track? { model.track(deck) }

}

@MainActor
private struct DeckFooter: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID

    var body: some View {
            HStack(spacing: 18) {
                if let track, model.arrangements[track.id] != nil {
                    ArrangementRemainingTime(model:model,deck:deck)
                } else {
                    Text(remainingTime).font(.system(size:11,design:.monospaced)).foregroundStyle(.secondary)
                }
                if let recovery = model.recoveryLabel(deck: deck) {
                    Text(recovery).font(.system(size: 11)).foregroundStyle(PerformancePalette.syncGreen)
                        .accessibilityLabel(recovery)
                }
                Spacer()
                if editing, let grid = model.grid(deck) {
                    ForEach(0..<4) { beat in
                        Button("\(beat + 1)") { model.selectDownbeat(deck: deck, beat: beat) }
                            .foregroundStyle((model.timing(deck)?.downbeatOffset ?? grid.downbeatOffset) == beat ? .orange : deckBlue)
                    }
                }
            }.padding(.horizontal, 18).frame(height: 36).background(surface)

    }
    private var track: Track? { model.track(deck) }
    private var playback: DeckPlaybackSnapshot? { model.playbackSnapshot?[deck] }
    private var editing: Bool { model.editing.contains(deck) }
    private var remainingTime: String {
        guard let track else { return "—:—" }
        let remaining = max(0, Int(ceil(track.analysis.duration - (playback?.sourceFrame ?? 0) / track.analysis.sampleRate)))
        return String(format: "−%d:%02d", remaining / 60, remaining % 60)
    }
}

@MainActor
private struct DeckTransportButtons: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID

    var body: some View {
        Group {
            Button { model.setMixer(.cue, value: playback?.mixer.cue == true ? 0 : 1, deck: deck) } label: {
                Image(systemName: "headphones")
                    .foregroundStyle(playback?.mixer.cue == true ? deckBlue : Color(white: 0.65))
            }.accessibilityLabel("Headphone cue for deck \(deck.rawValue.uppercased())")
            DeckPlaybackButton(model:model,deck:deck)
        }
    }
    private var track: Track? { model.track(deck) }
    private var playback: DeckControlDisplay? { model.controlDisplay[deck] }
    private var preparing: Bool { model.preparingPlayback.contains(deck) }

}

@MainActor
private struct MasterTempoButton: View {
    @Bindable var model: ReplicaModel
    @Binding var tempoWheelVisible: Bool
    var body: some View {
                Button { tempoWheelVisible.toggle() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.path.ecg")
                        Text(String(format: "%.1f", model.controlDisplay.masterBPM))
                            .monospacedDigit()
                    }
                }.accessibilityLabel("Master tempo")
    }
}
@MainActor
private struct DeckTempoReadout: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    var body: some View {
                            Text(model.grid(deck).map { String(format: "%.1f", (model.playbackSnapshot?[deck].adaptiveMap?.bpm(atFrame:model.editing.contains(deck) ? model.viewport[deck] ?? 0 : model.playbackSnapshot?[deck].sourceFrame ?? 0) ?? $0.bpm) * (model.editing.contains(deck) ? 1 : model.controlDisplay[deck].speed)) } ?? "—")
                                .monospacedDigit()
    }
}


/// Grid editing controls: lock, tap mode, halve, tempo (tap when in tap mode), double, reset and done.
@MainActor
struct GridEditBar: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    var body: some View {
        let locked = model.gridLocked.contains(deck), tapping = model.gridTapMode.contains(deck)
        HStack(spacing: 6) {
                    Menu {
                        Button("Automatic") { model.selectGridMode(.automatic, deck: deck) }
                        Button("Fixed") { model.selectGridMode(.fixed, deck: deck) }
                        Button("Adaptive") { model.selectGridMode(.adaptive, deck: deck) }
                        Button("Correct local anchor") { model.correctLocalAnchor(deck: deck) }
                            .disabled(model.gridPreparation(deck)?.adaptiveMap == nil)
                        Button("Undo correction") { model.undoGridCorrection(deck: deck) }
                        Button(model.gridPreparation(deck)?.gridLocked == true ? "Unlock preparation" : "Lock preparation") {
                            model.setGridLocked(model.gridPreparation(deck)?.gridLocked != true, deck: deck)
                        }
                        if let confidence = model.candidateConfidence(deck) {
                            Text("Candidate confidence: \(Int(confidence * 100))%")
                        }
                    } label: { Image(systemName: "slider.horizontal.3") }
            button(locked ? "lock.fill" : "lock.open", label: "Lock grid") {
                if model.gridLocked.remove(deck) == nil { model.gridLocked.insert(deck) }; model.setGridLocked(model.gridLocked.contains(deck),deck:deck)
            }.frame(width: 40)
            text("TAP MODE", active: tapping) { if model.gridTapMode.remove(deck) == nil { model.gridTapMode.insert(deck) } }.disabled(locked)
            HStack(spacing: 0) {
                text("/2") { model.correctTempo(deck: deck, factor: 0.5) }
                if tapping { text("TAP", active: true) { model.tapTempo(deck: deck) } }
                else { Text(model.grid(deck).map { String(format: "%.1f", model.playbackSnapshot?[deck].adaptiveMap?.bpm(atFrame:model.viewport[deck] ?? 0) ?? $0.bpm) } ?? "—").font(.system(size: 15).monospacedDigit())
                        .foregroundStyle(PerformancePalette.cyan).frame(width: 70, height: 34).background(PerformancePalette.sunken) }
                text("x2") { model.correctTempo(deck: deck, factor: 2) }
            }.disabled(locked || model.grid(deck) == nil)
            text("RESET") { model.resetGrid(deck: deck) }.disabled(locked)
            text("DONE") { model.toggleGridEditing(deck: deck) }
        }.font(.system(size: 14, weight: .medium)).foregroundStyle(PerformancePalette.text)
    }
    private func button(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(maxWidth: .infinity).frame(height: 34).bevelPanel(cornerRadius: 3) }
            .accessibilityLabel(label)
    }
    private func text(_ title: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).padding(.horizontal, 10).frame(height: 34)
                .foregroundStyle(active ? PerformancePalette.cyan : PerformancePalette.text).bevelPanel(cornerRadius: 3)
        }
    }
}

/// Numbered bar positions over the waveform while editing. Tapping a number makes that beat beat 1.
@MainActor
struct GridBeatMarkers: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let grid: BeatGrid
    let center: Double
    let span: Double
    var body: some View {
        GeometryReader { geometry in
            let left = center - span / 2, perPoint = span / max(1, geometry.size.width)
            let timing=model.timing(deck) ?? BeatTiming(fixed:grid)
            let first=Int(exactly:ceil(timing.beat(atFrame:left))) ?? 0
            let last=Int(exactly:ceil(timing.beat(atFrame:left+span))) ?? first
            ForEach(0..<max(0,min(64,last-first+1)), id: \.self) { offset in
                let beat = first + offset
                let x = (timing.frame(atBeat: Double(beat)) - left) / perPoint
                if x >= 0 && x <= geometry.size.width {
                    Button { model.setDownbeat(atBeat: beat, deck: deck) } label: {
                        Text("\(((beat-timing.downbeatOffset)%4+4)%4+1)").font(.system(size: 14, weight: .bold))
                            .foregroundStyle(PerformancePalette.text).frame(width: 26, height: 28).bevelPanel(cornerRadius: 3)
                    }.position(x: x + 15, y: 18).accessibilityLabel("Make this beat the downbeat")
                }
            }
        }.disabled(model.gridLocked.contains(deck))
    }
    static func count(span: Double, grid: BeatGrid) -> Int { max(0, min(64, Int(ceil(span / grid.framesPerBeat)) + 1)) }
    /// 1 to 4 within the bar.
    static func number(beat: Int, grid: BeatGrid) -> Int {
        var index = 0
        while index < 4 && !grid.isDownbeat(beat - index) { index += 1 }
        return index % 4 + 1
    }
}
