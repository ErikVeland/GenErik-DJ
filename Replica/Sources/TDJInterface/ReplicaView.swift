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

@MainActor public struct ReplicaView: View {
    @State private var model: ReplicaModel
    @State private var importPresented = false
    @State private var traktorImportPresented = false
    @State private var tempoWheelVisible = false
    @State private var audioSettingsPresented = false
    @State private var deckAPanels = DeckPanelPresentation()
    @State private var deckBPanels = DeckPanelPresentation()
    @State private var libraryPanel = LibraryPanelState()
    @State private var deckSplit = DeckSplitState()
    @State private var touchInterruption = UUID()
    @State private var sectionEdit: (deck: DeckID, identity: SectionEditIdentity)?
    @AppStorage(DeckToolSettings.largePanelHandles) private var largePanelHandles = false
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    private var handleExtent: Double { PanelHandleMetrics(expanded: largePanelHandles || voiceOver).extent }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let snapshotEffectsDeck: DeckID?
    private let snapshotMixerDecks: Set<DeckID>
    private let snapshotFilterDecks: Set<DeckID>
    @Environment(\.scenePhase) private var scenePhase
    public init(
        model: ReplicaModel, snapshotEffectsDeck: DeckID? = nil, snapshotMixerDecks: Set<DeckID> = [],
        snapshotFilterDecks: Set<DeckID> = []
    ) {
        _model = State(initialValue: model)
        self.snapshotEffectsDeck = snapshotEffectsDeck
        self.snapshotMixerDecks = snapshotMixerDecks
        self.snapshotFilterDecks = snapshotFilterDecks
    }

    public var body: some View {
        GeometryReader { window in
            let width = window.size.width + window.safeAreaInsets.leading + window.safeAreaInsets.trailing
            let height = window.size.height + window.safeAreaInsets.top + window.safeAreaInsets.bottom
            let presentation = BrowserPresentation.select(isPhone: isPhone, windowWidth: width, windowHeight: height)
            workspaceRoot(presentation: presentation)
                .ignoresSafeArea(.container, edges: isPhone && width < height ? .horizontal : [])
        }.environment(\.touchSurfaceInterruption, touchInterruption).background(
            PerformancePalette.frame.ignoresSafeArea()
        )
        #if os(iOS)
            .statusBarHidden(true).persistentSystemOverlays(.hidden)
        #endif
    }

    private func workspaceRoot(presentation: BrowserPresentation) -> some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                if model.helpVisible { GestureHelp { model.helpVisible = false }.frame(width: 280) }
                performanceSurface(presentation: presentation).frame(maxWidth: .infinity, maxHeight: .infinity)
            }.frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading).onChange(
                of: geometry.size
            ) { _, _ in touchInterruption = UUID() }
                .allowsHitTesting(sectionEdit == nil).accessibilityHidden(sectionEdit != nil)
                .overlay {
                    if let sectionEdit {
                        ArrangementEditor(
                            model: model, deck: sectionEdit.deck, identity: sectionEdit.identity,
                            isPresented: true, usesColumns: true, close: { self.sectionEdit = nil }
                        ).id(sectionEdit.identity.id).frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(PerformancePalette.panel).padding(6)
                            .background(PerformancePalette.frame)
                    }
                }.onChange(of: sectionEdit?.identity.id) { _, _ in touchInterruption = UUID() }
        }
    }
    private var isPhone: Bool {
        #if os(iOS)
            UIDevice.current.userInterfaceIdiom == .phone
        #else
            false
        #endif
    }

    private var openFullHeightSections: ((DeckID, SectionEditIdentity) -> Void)? {
        #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                return { deck, identity in sectionEdit = (deck, identity) }
            }
        #endif
        return nil
    }

    private func performanceSurface(presentation: BrowserPresentation) -> some View {
        VStack(spacing: 0) {
            PerformanceToolbar(
                model: model, tempoWheelVisible: $tempoWheelVisible, audioSettingsPresented: $audioSettingsPresented,
                importPresented: $importPresented, traktorImportPresented: $traktorImportPresented)
            GeometryReader { space in
                if presentation == .frontPhone {
                    FrontPerformanceView(
                        model: model, importAudio: { importPresented = true },
                        linkCollection: { traktorImportPresented = true })
                } else {
                    let deckInset = isPhone ? 0.0 : 6.0
                    let workspaceHandle = handleExtent
                    let workspace = PerformanceWorkspaceGeometry(
                        width: space.size.width, height: space.size.height, libraryExtent: libraryPanel.extent,
                        handleExtent: workspaceHandle)
                    let split = deckSplit.geometry(
                        width: workspace.deckArea.width - 2 * deckInset, height: workspace.deckArea.height,
                        handleExtent: handleExtent)
                    ZStack(alignment: .topTrailing) {
                        VStack(alignment: .leading, spacing: 0) {
                            VStack(spacing: 0) {
                                DeckView(
                                    model: model, deck: .a, panels: deckAPanels,
                                    snapshotEffects: snapshotEffectsDeck == .a,
                                    snapshotMixer: snapshotMixerDecks.contains(.a),
                                    snapshotFilter: snapshotFilterDecks.contains(.a),
                                    openFullHeightSections: openFullHeightSections,
                                    requestPerformanceSpace: { minimum in
                                        if model.browserVisible {
                                            libraryPanel.makeRoom(
                                                by: max(
                                                    minimum - split.a.height,
                                                    minimum + DeckSplitGeometry.minimumDeckHeight + handleExtent
                                                        - workspace.deckArea.height))
                                        }
                                        let available = PerformanceWorkspaceGeometry(
                                            width: space.size.width, height: space.size.height,
                                            libraryExtent: libraryPanel.extent, handleExtent: workspaceHandle)
                                        deckSplit.ensureHeight(
                                            upper: true, minimum: minimum, height: available.deckArea.height,
                                            handleExtent: handleExtent)
                                    }
                                ).frame(height: split.a.height).contentShape(Rectangle()).clipped()
                                DeckSplitHandle(
                                    interruption: touchInterruption,
                                    aShare: split.a.height / max(1, split.a.height + split.b.height),
                                    begin: {
                                        deckSplit.beginDrag(
                                            height: workspace.deckArea.height, handleExtent: handleExtent)
                                    }, update: { deckSplit.updateDrag(translation: $0) },
                                    end: {
                                        deckSplit.endDrag(height: workspace.deckArea.height, handleExtent: handleExtent)
                                    }, cancel: { deckSplit.cancelDrag() }, balance: { deckSplit.balance() },
                                    adjust: {
                                        deckSplit.adjust(
                                            by: $0, height: workspace.deckArea.height, handleExtent: handleExtent)
                                    }
                                ).frame(height: split.handle.height).clipped()
                                DeckView(
                                    model: model, deck: .b, panels: deckBPanels,
                                    snapshotEffects: snapshotEffectsDeck == .b,
                                    snapshotMixer: snapshotMixerDecks.contains(.b),
                                    snapshotFilter: snapshotFilterDecks.contains(.b),
                                    openFullHeightSections: openFullHeightSections,
                                    requestPerformanceSpace: { minimum in
                                        if model.browserVisible {
                                            libraryPanel.makeRoom(
                                                by: max(
                                                    minimum - split.b.height,
                                                    minimum + DeckSplitGeometry.minimumDeckHeight + handleExtent
                                                        - workspace.deckArea.height))
                                        }
                                        let available = PerformanceWorkspaceGeometry(
                                            width: space.size.width, height: space.size.height,
                                            libraryExtent: libraryPanel.extent, handleExtent: workspaceHandle)
                                        deckSplit.ensureHeight(
                                            upper: false, minimum: minimum, height: available.deckArea.height,
                                            handleExtent: handleExtent)
                                    }
                                ).frame(height: split.b.height).contentShape(Rectangle()).clipped()
                            }.padding(.horizontal, deckInset).frame(
                                width: workspace.deckArea.width, height: workspace.deckArea.height)
                            HStack(spacing: 0) {
                                TouchPanelHandle(
                                    presented: libraryPanel.extent > 0, maximumExtent: libraryPanel.maximumExtent,
                                    presentationID: model.browserPresentationID,
                                    toggle: {
                                        libraryPanel.setPresented(libraryPanel.extent == 0)
                                        model.browserVisible = libraryPanel.extent > 0
                                    }, begin: { libraryPanel.beginDrag() },
                                    update: { translation in libraryPanel.updateDrag(translation: translation) },
                                    end: { velocity in
                                        libraryPanel.endDrag(velocity: velocity)
                                        model.browserVisible = libraryPanel.extent > 0
                                    },
                                    cancel: {
                                        libraryPanel.cancelDrag()
                                        model.browserVisible = libraryPanel.extent > 0
                                    },
                                    adjust: { delta in
                                        libraryPanel.adjust(by: delta)
                                        model.browserVisible = libraryPanel.extent > 0
                                    }
                                ).frame(maxWidth: .infinity)
                            }.frame(height: handleExtent)
                                .background(largePanelHandles ? PerformancePalette.frame : Color.clear)
                            BrowserView(
                                model: model, importAudio: { importPresented = true },
                                linkCollection: { traktorImportPresented = true }
                            ).frame(
                                width: workspace.libraryArea.width, height: workspace.libraryArea.height,
                                alignment: .top
                            ).clipped().allowsHitTesting(libraryPanel.acceptsContentInput).disabled(
                                !libraryPanel.acceptsContentInput
                            ).accessibilityHidden(!libraryPanel.acceptsContentInput)
                        }.frame(width: space.size.width, height: space.size.height, alignment: .topLeading)
                            .clipped().animation(
                                reduceMotion || libraryPanel.isDragging || deckSplit.isDragging
                                    ? nil : .smooth(duration: 0.25), value: libraryPanel.extent
                            ).onAppear {
                                libraryPanel.updateViewport(
                                    width: space.size.width, height: space.size.height, presented: model.browserVisible,
                                    handleExtent: workspaceHandle)
                                deckSplit.updateViewport(width: space.size.width, height: space.size.height)
                            }.onChange(of: space.size) { _, size in
                                libraryPanel.updateViewport(
                                    width: size.width, height: size.height, presented: model.browserVisible,
                                    handleExtent: workspaceHandle)
                                deckSplit.updateViewport(width: size.width, height: size.height)
                                model.browserVisible = libraryPanel.extent > 0
                            }.onChange(of: workspaceHandle) { _, value in
                                libraryPanel.updateViewport(
                                    width: space.size.width, height: space.size.height, presented: model.browserVisible,
                                    handleExtent: value)
                            }.onChange(of: model.browserPresentationID) { _, _ in
                                libraryPanel.present(fullyExpanded: model.browserPresentationExpands)
                                model.browserVisible = libraryPanel.extent > 0
                            }.onChange(of: model.browserVisible) { _, visible in libraryPanel.setPresented(visible) }
                            .onChange(of: scenePhase) { _, phase in
                                if phase != .active {
                                    libraryPanel.cancelDrag()
                                    deckSplit.cancelDrag()
                                    model.browserVisible = libraryPanel.extent > 0
                                }
                            }
                        PerformanceDock(
                            model: model, panelsA: deckAPanels, panelsB: deckBPanels,
                            geometry: PerformanceDockGeometry(
                                width: space.size.width, height: workspace.deckArea.height,
                                deckBoundary: split.handle.midY))
                    }.frame(width: space.size.width, height: space.size.height, alignment: .topLeading).environment(
                        \.performancePanelPortrait, space.size.width < space.size.height)
                }
            }

        }.background(PerformancePalette.frame).foregroundStyle(PerformancePalette.text).buttonStyle(.plain)
            .preferredColorScheme(.dark).task {
                ReplicaLifecycle.register(model)
                guard scenePhase != .background else { return }
                model.startPlaybackMonitor()
                async let music: Void = model.openNativeMusicLibrary()
                await model.refreshTraktorPreparation()
                await music
                // Launch argument for the clean-room comparison: -reference-benchmark <count>.
                let arguments = ProcessInfo.processInfo.arguments
                if let index = arguments.firstIndex(of: "-reference-benchmark"), index + 1 < arguments.count,
                    let count = Int(arguments[index + 1])
                {
                    _ = await model.runReferenceBenchmark(count: count)
                }
            }.task(id: model.browserVisible) {
                if model.browserVisible, model.musicLibraryCatalog == nil, !model.musicLibraryRefreshing {
                    await model.openNativeMusicLibrary()
                }
            }.onDisappear {
                model.stopPlaybackMonitor()
                ReplicaLifecycle.suspend(model)
            }.onChange(of: scenePhase) { _, phase in
                if phase != .active { touchInterruption = UUID() }
                #if os(iOS)
                    if phase == .background { ReplicaLifecycle.background(model) }
                #endif
                if phase == .active {
                    ReplicaLifecycle.foreground(model)
                    model.startPlaybackMonitor()
                    Task {
                        async let music: Void = model.openNativeMusicLibrary()
                        await model.refreshTraktorPreparation(force: true)
                        await music
                    }
                }
            }.fileImporter(
                isPresented: $traktorImportPresented, allowedContentTypes: [.data], allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls): if let url = urls.first { Task { await model.importTraktorPreparation(url) } }
                case .failure(let error): model.status = error.localizedDescription
                }
            }.fileImporter(isPresented: $importPresented, allowedContentTypes: [.audio, .mpeg4Movie], allowsMultipleSelection: true)
        { result in
            switch result {
            case .success(let urls): Task { await model.importFiles(urls) }
            case .failure(let error): model.status = error.localizedDescription
            }
        }
    }
}

/// Preserve the selector's six-row menu below the waveform while clipping sideways motion.
private struct DeckPanelHorizontalBounds: Shape {
    func path(in rect: CGRect) -> Path { Path(rect.insetBy(dx: 0, dy: -168)) }
}

/// Build drawers before performance, then move their retained layers. Closing still cancels contacts.
@MainActor private struct SlidingDeckPanel<Content: View>: View {
    let isPresented: Bool
    let edge: Edge
    let panelWidth: CGFloat
    let acceptsNewContacts: Bool
    let inputGate: TouchSurfaceInputGate
    @ViewBuilder var content: () -> Content
    var body: some View {
        content().environment(\.deckPanelPresented, isPresented).environment(
            \.touchSurfaceAcceptsNewContacts, acceptsNewContacts
        ).geometryGroup().frame(width: max(200, panelWidth)).frame(
            width: panelWidth, alignment: edge == .leading ? .leading : .trailing
        ).clipShape(DeckPanelHorizontalBounds()).contentShape(Rectangle()).allowsHitTesting(isPresented).disabled(
            !isPresented
        ).accessibilityHidden(!acceptsNewContacts).onAppear { inputGate.setEnabled(isPresented) }.onChange(
            of: isPresented
        ) { _, presented in inputGate.setEnabled(presented) }.onDisappear { inputGate.setEnabled(false) }
    }
}

@MainActor struct DeckView: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    @Bindable var panels: DeckPanelPresentation
    var snapshotEffects = false
    var snapshotMixer = false
    var snapshotFilter = false
    var showsSideHandles = true
    var openFullHeightSections: ((DeckID, SectionEditIdentity) -> Void)?
    var requestPerformanceSpace: (Double) -> Void = { _ in }
    @Environment(\.performancePanelPortrait) private var portrait
    @State private var sectionPanel = SectionEditorPanelState()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(DeckToolSettings.largePanelHandles) private var largePanelHandles = false
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    private var handleExtent: Double { PanelHandleMetrics(expanded: largePanelHandles || voiceOver).extent }
    @State private var frozenSpan: (loadID: UUID, seconds: Double)?
    private var waveformZoom: Binding<Double> {
        let loadID = model.loadIdentity(deck)
        return Binding {
            if let frozenSpan, frozenSpan.loadID == model.loadIdentity(deck), model.pendingNativeSelection[deck] == nil {
                return frozenSpan.seconds
            }
            return model.waveformZoomSeconds(deck: deck)
        } set: { seconds in
            guard let loadID, loadID == model.loadIdentity(deck), model.pendingNativeSelection[deck] == nil else { return }
            if frozenSpan?.loadID == loadID {
                frozenSpan = (loadID, seconds)
            } else {
                model.setWaveformZoomSeconds(seconds, deck: deck, loadID: loadID)
            }
        }
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mixerPanel = MixerPanel.equalizer
    private var mixerVisible: Bool { panels.mixerVisible }
    private var effectsVisible: Bool { panels.effectsVisible }
    private var effectsInput: TouchSurfaceInputGate { panels.effectsInput }
    private var mixerInput: TouchSurfaceInputGate { panels.mixerInput }
    @AppStorage(BrowserSettings.superSlicerKey) private var superSlicer = true
    @AppStorage(DeckToolSettings.tempoFader) private var tempoFader = false
    @AppStorage(DeckToolSettings.cueButton) private var cueButton = false
    @AppStorage(DeckToolSettings.headphoneButton) private var headphoneButton = false
    private var selection: MusicLibraryItem? { model.pendingNativeSelection[deck] }
    private var track: Track? { selection == nil ? model.track(deck) : nil }
    private var editing: Bool { selection == nil && model.editing.contains(deck) }
    private var playback: DeckPlaybackSnapshot? { model.playbackSnapshot?[deck] }
    var body: some View {
        GeometryReader { deckSpace in
            content(size: deckSpace.size)
        }.zIndex(effectsVisible || snapshotEffects ? 1 : 0).onChange(of: track?.id, initial: true) { _, _ in
            panels.setTrackAvailable(track != nil)
            sectionPanel.validate(trackID: track?.id, loadID: model.loadIdentity(deck))
        }.onChange(of: model.frozen.contains(deck)) { _, enabled in
            if enabled, let loadID = model.loadIdentity(deck), let track, let state = playback, state.loopEnabled {
                frozenSpan = (loadID, (state.loopEnd - state.loopStart) / track.analysis.sampleRate)
                model.viewport[deck] = (state.loopStart + state.loopEnd) / 2
            } else if !enabled {
                frozenSpan = nil
            }
        }
    }
    private var previewStripHeight: Double {
        #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad { return 60 }
        #endif
        return 24
    }

    @ViewBuilder func content(size: CGSize) -> some View {
        let sideHandleExtent = showsSideHandles ? handleExtent : 0
        let zoom = waveformZoom
        let showsHotcues = track != nil && model.hotcuePadsVisible.contains(deck)
        let layout = AdaptiveDeckGeometry(
            height: max(0, size.height - 8),
            hotcues: showsHotcues,
            compactControls: track != nil || selection != nil, editing: editing, previewStripHeight: previewStripHeight)
        let availableWidth = max(0, size.width - (tempoFader && track != nil ? 68 : 0))
        let sizes = panels.geometry(width: availableWidth, height: layout.waveformHeight, inlineControls: true)
        let frozenControlsWidth = track != nil && model.frozen.contains(deck) && !editing && superSlicer ? 44.0 : 0
        let waveformAxis = CGRect(
            x: sizes.waveform.minX + frozenControlsWidth, y: 0,
            width: max(0, sizes.waveform.width - frozenControlsWidth), height: layout.waveformHeight)
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    model.showSuggestions(destination: deck)
                } label: {
                    DeckArtwork(
                        source: ArtworkSource.track(track, item: selection, media: model.store.mediaDirectory)
                    ).frame(width: min(44, layout.headerHeight), height: min(44, layout.headerHeight)).background(
                        PerformancePalette.sunken
                    ).clipped().overlay { TrackHeadphoneIndicator(model: model, trackID: track?.id) }.overlay(
                        alignment: .bottomLeading
                    ) {
                        Text(deck.rawValue.uppercased()).font(.system(size: 10, weight: .bold)).padding(2)
                            .background(PerformancePalette.frame).allowsHitTesting(false)
                    }
                }.buttonStyle(.plain).accessibilityLabel("Load track for deck \(deck.rawValue.uppercased())")
                DeckHeader(model: model, deck: deck, dense: true, showsArtwork: false).buttonStyle(.plain)
            }.frame(height: layout.headerHeight, alignment: .top).background(
                DeckSectionHeader(model: model, deck: deck, visibleSeconds: zoom.wrappedValue, waveform: waveformAxis)
            ).clipped()
            HStack(spacing: 4) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        SlidingDeckPanel(
                            isPresented: effectsVisible || snapshotEffects, edge: .leading,
                            panelWidth: sizes.effectsContent.width,
                            acceptsNewContacts: sizes.effectsContent.width >= 200 && layout.waveformHeight >= 184,
                            inputGate: effectsInput
                        ) {
                            EffectsView(model: model, deck: deck).environment(\.touchSurfaceInputGate, effectsInput)
                        }
                        if showsSideHandles { panelHandle(.effects, edge: .leading, title: "FX") }
                        DeckWaveform(
                            model: model, deck: deck, visibleSeconds: zoom, mixerVisible: mixerVisible
                        ).frame(width: sizes.waveform.width).environment(
                            \.touchSurfaceAcceptsNewContacts,
                            layout.waveformHeight >= 44 && sizes.waveform.width >= 44)
                        if showsSideHandles { panelHandle(.mixer, edge: .trailing, title: "EQ") }
                        SlidingDeckPanel(
                            isPresented: mixerVisible || snapshotMixer, edge: .trailing,
                            panelWidth: sizes.mixerContent.width,
                            acceptsNewContacts: sizes.mixerContent.width >= 200 && layout.waveformHeight >= 184,
                            inputGate: mixerInput
                        ) {
                            DeckMixerView(
                                model: model, deck: deck, panel: snapshotFilter ? .constant(.filter) : $mixerPanel,
                                width: max(200, sizes.mixerContent.width)
                            ).environment(\.touchSurfaceInputGate, mixerInput)
                        }
                    }.frame(width: sizes.waveformWidth, height: layout.waveformHeight).clipShape(
                        DeckPanelHorizontalBounds()
                    ).zIndex(effectsVisible || snapshotEffects ? 1 : 0).overlay(alignment: .bottomLeading) {
                        if track != nil {
                            DeckActionPane(model: model, deck: deck, panels: panels, openSections: openSections)
                        }
                    }
                    if showsHotcues {
                        HotcuePadRow(model: model, deck: deck).frame(height: layout.hotcueHeight).clipped()
                            .allowsHitTesting(layout.hotcueHeight >= 44).protectsFrontDeckSwipe()
                    }
                }.frame(width: sizes.mainWidth)
                if tempoFader && track != nil { DeckTempoFader(model: model, deck: deck) }
            }.frame(height: layout.waveformHeight + layout.hotcueHeight)
            Group {
                if editing {
                    DeckTimeReadout(model: model, deck: deck, editing: true)
                } else {
                    DeckOverview(model: model, deck: deck, visibleSeconds: zoom).overlay {
                        DeckTimeReadout(model: model, deck: deck)
                    }
                }
            }.font(.system(size: 13, weight: .medium).monospacedDigit()).frame(height: layout.footerHeight)
                .clipped()
        }.padding(4).background(PerformancePalette.stage).bevelPanel(cornerRadius: 6, sunken: true).animation(
            reduceMotion || panels.isDragging ? nil : .smooth(duration: 0.22), value: sizes.extraWidth
        ).animation(
            reduceMotion || panels.isDragging ? nil : .smooth(duration: 0.22), value: sizes.effectsContent.width
        ).animation(
            reduceMotion || panels.isDragging ? nil : .smooth(duration: 0.22), value: sizes.mixerContent.width
        ).onAppear {
            panels.configure(width: availableWidth, portrait: portrait, handleExtent: sideHandleExtent)
            panels.setTrackAvailable(track != nil)
            sectionPanel.configure(height: size.height, portrait: portrait, handleExtent: handleExtent)
            if snapshotEffects && !effectsVisible { panels.toggleEffects() }
            if snapshotMixer && !mixerVisible { panels.toggleMixer() }
        }.onChange(of: availableWidth) { _, width in
            panels.configure(width: width, portrait: portrait, handleExtent: sideHandleExtent)
        }.onChange(of: portrait) { _, value in
            panels.configure(width: availableWidth, portrait: value, handleExtent: sideHandleExtent)
            sectionPanel.configure(height: size.height, portrait: value, handleExtent: handleExtent)
        }.onChange(of: handleExtent) { _, value in
            panels.configure(width: availableWidth, portrait: portrait, handleExtent: sideHandleExtent)
            sectionPanel.configure(height: size.height, portrait: portrait, handleExtent: value)
        }.onChange(of: size.height) { _, height in
            sectionPanel.configure(height: height, portrait: portrait, handleExtent: handleExtent)
        }.onChange(of: model.loadIdentity(deck)) { _, _ in
            sectionPanel.validate(trackID: track?.id, loadID: model.loadIdentity(deck))
        }.onChange(of: scenePhase) { _, phase in if phase != .active { sectionPanel.cancelDrag() } }.overlay(
            alignment: .bottom
        ) {
            if let session = sectionPanel.session {
                VStack(spacing: 0) {
                    TouchPanelHandle(
                        presented: sectionPanel.isPresented, maximumExtent: sectionPanel.maximumExtent,
                        presentationID: sectionPanel.presentationID, title: "SECTIONS",
                        accessibilityName: "Section editor",
                        toggle: { sectionPanel.setPresented(!sectionPanel.isPresented) },
                        begin: { sectionPanel.beginDrag() }, update: { sectionPanel.updateDrag(translation: $0) },
                        end: { sectionPanel.endDrag(velocity: $0) }, cancel: { sectionPanel.cancelDrag() },
                        adjust: { sectionPanel.adjust(by: $0) })
                    ArrangementEditor(
                        model: model, deck: deck, identity: session, isPresented: sectionPanel.isPresented,
                        close: { sectionPanel.discard() }
                    ).id(session.id).frame(height: sectionPanel.extent).clipped().contentShape(Rectangle())
                        .allowsHitTesting(sectionPanel.isPresented).protectsFrontDeckSwipe().overlay {
                            if !sectionPanel.acceptsContentInput { Color.clear.contentShape(Rectangle()) }
                        }.accessibilityHidden(!sectionPanel.acceptsContentInput)
                }.frame(width: size.width, height: sectionPanel.extent + handleExtent).background(
                    PerformancePalette.panel
                ).clipped()
            }
        }.onChange(of: [effectsVisible, mixerVisible, panels.extraVisible]) { _, _ in
            if sectionPanel.isPresented { sectionPanel.setPresented(false) }
        }.onChange(of: panels.spaceRequestID) { _, _ in
            if panels.spaceRequestKind != .extra && layout.waveformHeight < 184 {
                requestPerformanceSpace(236 + (editing ? 44 : previewStripHeight) + (showsHotcues ? 56 : 0))
            }
        }
    }

    private func openSections() {
        guard let track, model.arrangements[track.id] != nil else { return }
        let loadID = model.loadIdentity(deck)
        if let openFullHeightSections {
            panels.toggleControls()
            openFullHeightSections(deck, .init(trackID: track.id, loadID: loadID))
        } else {
            sectionPanel.open(trackID: track.id, loadID: loadID)
            requestPerformanceSpace(52 + handleExtent + 260)
        }
    }

    private func panelHandle(_ kind: PerformancePanel, edge: TouchPanelEdge, title: String) -> some View {
        TouchPanelHandle(
            presented: panels.isPresented(kind), maximumExtent: panels.maximum(kind),
            presentationID: panels.presentationID(for: kind), edge: edge, title: title,
            accessibilityName: "Deck \(deck.rawValue.uppercased()) \(title)",
            canToggle: kind != .extra || panels.extraVisible || panels.maximum(.extra) >= 144,
            toggle: { panels.toggle(kind) }, begin: { panels.begin(kind) },
            update: { panels.update(kind, translation: $0) }, end: { panels.end(kind, velocity: $0) },
            cancel: { panels.cancel(kind) }, adjust: { panels.adjust(kind, by: $0) }
        ).opacity(track == nil ? 0 : 1).allowsHitTesting(track != nil).accessibilityHidden(track == nil)
            .protectsFrontDeckSwipe()
    }
}

@MainActor struct DeckTimeReadout: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    var editing = false
    var body: some View {
        Group {
            if editing {
                HStack(spacing: 6) {
                    Text(elapsedTime)
                    DeckFooter(model: model, deck: deck)
                    Text(remainingTime)
                }
            } else {
                HStack(spacing: 6) {
                    Text(elapsedTime).accessibilityLabel(
                        "Current time on deck \(deck.rawValue.uppercased()): \(elapsedTime)"
                    ).padding(.horizontal, 3).background(.black.opacity(0.72))
                    Spacer(minLength: 0)
                    if let status = model.arrangementStatus(deck: deck) {
                        Text(status.endingText).font(
                            .system(size: 10, weight: .semibold, design: .monospaced)
                        ).foregroundStyle(
                            status.warning == .red || status.warning == .urgent
                                ? Color.red : PerformancePalette.text
                        ).lineLimit(1).padding(.horizontal, 3).background(.black.opacity(0.72))
                    }
                    Spacer(minLength: 0)
                    Text(remainingTime).accessibilityLabel(
                        "Time left on deck \(deck.rawValue.uppercased()): \(remainingTime)"
                    ).padding(.horizontal, 3).background(.black.opacity(0.72))
                }.allowsHitTesting(false)
            }
        }
    }
    private var selection: MusicLibraryItem? { model.pendingNativeSelection[deck] }
    private var track: Track? { selection == nil ? model.track(deck) : nil }
    private var playback: DeckPlaybackSnapshot? { model.playbackSnapshot?[deck] }
    private var elapsedTime: String {
        let seconds = max(
            0, Int((selection == nil ? playback?.sourceFrame ?? 0 : 0) / (track?.analysis.sampleRate ?? 1)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
    private var remainingTime: String {
        let seconds = max(
            0,
            Int(
                ceil(
                    (selection?.duration ?? track?.analysis.duration ?? 0)
                        - (selection == nil ? playback?.sourceFrame ?? 0 : 0) / (track?.analysis.sampleRate ?? 1))))
        return String(format: "−%d:%02d", seconds / 60, seconds % 60)
    }
}

@MainActor private struct DeckActionPane: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    @Bindable var panels: DeckPanelPresentation
    let openSections: () -> Void
    @AppStorage(DeckToolSettings.cueButton) private var cueButton = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 4) {
            Button {
                panels.toggleControls()
            } label: {
                Image(systemName: panels.extraVisible ? "xmark" : "slider.horizontal.3")
                    .frame(width: 44, height: 48).foregroundStyle(
                        panels.extraVisible ? PerformancePalette.cyan : PerformancePalette.text
                    ).bevelPanel(cornerRadius: 5, sunken: panels.extraVisible)
            }.buttonStyle(.plain).accessibilityLabel(
                "\(panels.extraVisible ? "Close" : "Open") utility strip for deck \(deck.rawValue.uppercased())"
            ).simultaneousGesture(
                DragGesture(minimumDistance: 12).onEnded { value in
                    let open = value.translation.height < -16 || value.translation.width > 24
                    let close = value.translation.height > 16 || value.translation.width < -24
                    if (open && !panels.extraVisible) || (close && panels.extraVisible) { panels.toggleControls() }
                }
            ).layoutPriority(1)
            ZStack(alignment: .leading) {
                if panels.extraVisible {
                    ViewThatFits(in: .horizontal) {
                        controls
                        ScrollView(.horizontal, showsIndicators: false) { controls }
                    }.transition(.move(edge: .leading).combined(with: .opacity))
                }
            }.clipped()
        }.background {
            if panels.extraVisible { RoundedRectangle(cornerRadius: 5).fill(PerformancePalette.sunken) }
        }.overlay {
            if panels.extraVisible {
                RoundedRectangle(cornerRadius: 5).strokeBorder(PerformancePalette.secondaryText.opacity(0.5))
                    .allowsHitTesting(false)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).environment(\.deckPanelPresented, panels.extraVisible)
            .protectsFrontDeckSwipe().animation(
            reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.9), value: panels.extraVisible)
    }

    private var controls: some View {
        HStack(spacing: 6) {
            PerformanceControls(model: model, deck: deck, compact: true, openSections: openSections)
            OptionalHeadphoneButton(model: model, deck: deck)
            if cueButton { Button("CUE") { model.pressCue(deck: deck) }.frame(width: 48) }
        }.buttonStyle(PerformanceToolButtonStyle()).padding(.horizontal, 4)
            .fixedSize(horizontal: true, vertical: false)
    }
}

struct DeckRailButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(maxWidth: .infinity, maxHeight: .infinity).bevelPanel(
            cornerRadius: 3, sunken: configuration.isPressed
        ).contentShape(Rectangle())
    }
}

@MainActor private struct StripeView: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let track: Track
    @Binding var visibleSeconds: Double
    @State private var zoomStart: Double?
    @State private var session = StripeGestureSession()
    var body: some View {
        GeometryReader { geometry in
            WaveformView(
                track: track, grid: nil, centerFrame: Double(track.analysis.frameCount) / 2,
                visibleSeconds: track.analysis.duration, sections: model.arrangements[track.id]?.sections ?? []
            ).equatable().overlay {
                ArrangementWaveformOverlay(
                    model: model, deck: deck, track: track, center: Double(track.analysis.frameCount) / 2,
                    span: Double(track.analysis.frameCount), overview: true)
            }.overlay {
                if model.hotcuePadsVisible.contains(deck) {
                    OverviewCueFlags(model: model, track: track)
                }
            }.overlay(alignment: .leading) {
                StripeViewportMarker(
                    model: model, deck: deck, width: geometry.size.width, frameCount: Double(track.analysis.frameCount),
                    duration: track.analysis.duration, visibleSeconds: visibleSeconds)
            }.clipped().contentShape(Rectangle()).overlay {
                TouchSurface(geometryPolicy: .retainContactSpace) { event in
                    session.handle(
                        event, model: model, deck: deck, visibleSeconds: visibleSeconds,
                        width: geometry.size.width) { visibleSeconds = $0 }
                }.id(track.id)
            }
            #if os(macOS)
                .simultaneousGesture(
                    MagnifyGesture().onChanged { value in
                        if zoomStart == nil { zoomStart = visibleSeconds }
                        visibleSeconds = max(
                            min(1, track.analysis.duration),
                            min(track.analysis.duration, (zoomStart ?? 8) / value.magnification))
                    }.onEnded { _ in zoomStart = nil })
            #endif
        }
    }
}

@MainActor private struct StripeViewportMarker: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let width: CGFloat
    let frameCount: Double
    let duration: Double
    let visibleSeconds: Double
    var body: some View {
        let fraction = (model.viewport[deck] ?? 0) / frameCount
        let window = max(10, width * visibleSeconds / duration)
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).stroke(PerformancePalette.red, lineWidth: 2)
                .frame(width: window).offset(x: width * fraction - window / 2)
            if model.previewing.contains(deck), let state = model.playbackSnapshot?[deck] {
                Rectangle().fill(Color.white.opacity(0.8)).frame(width: 1)
                    .offset(x: width * state.sourceFrame / frameCount)
            }
        }
    }
}

struct WaveformView: View, Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        WaveformIndexKey(lhs.track.analysis) == WaveformIndexKey(rhs.track.analysis)
            && lhs.track.analysis.frameCount == rhs.track.analysis.frameCount
            && lhs.track.analysis.sampleRate == rhs.track.analysis.sampleRate
            && lhs.track.analysis.waveformDecodedFrames == rhs.track.analysis.waveformDecodedFrames
            && lhs.grid == rhs.grid && lhs.adaptiveMap == rhs.adaptiveMap && lhs.centerFrame == rhs.centerFrame
            && lhs.visibleSeconds == rhs.visibleSeconds && lhs.playheadFrame == rhs.playheadFrame
            && lhs.leadInFrame == rhs.leadInFrame && (lhs.band == nil) == (rhs.band == nil)
            && lhs.sections == rhs.sections
    }
    /// A filled shape mirrored about the centre line, one vertex per device pixel, anti-aliased.
    static func mirrored(_ heights: [Double], scale: Double, middle: Double) -> Path {
        var path = Path()
        guard !heights.isEmpty else { return path }
        path.move(to: CGPoint(x: 0, y: middle - heights[0]))
        for (x, h) in heights.enumerated() { path.addLine(to: CGPoint(x: Double(x) / scale, y: middle - h)) }
        for (x, h) in heights.enumerated().reversed() { path.addLine(to: CGPoint(x: Double(x) / scale, y: middle + h)) }
        path.closeSubpath()
        return path
    }
    /// Keep the three audio layers distinct within each section colour.
    static func draw(
        _ paths: [Path], fallback: [Color], regions: [ArrangementColourRegion], in context: inout GraphicsContext,
        size: CGSize
    ) {
        var gaps = Path(CGRect(origin: .zero, size: size))
        for region in regions { gaps.addRect(region.rect) }
        var uncoloured = context
        uncoloured.clip(to: gaps, style: FillStyle(eoFill: true))
        for (path, colour) in zip(paths, fallback) { uncoloured.fill(path, with: .color(colour)) }
        for region in regions {
            var coloured = context
            coloured.clip(to: Path(region.rect))
            for (path, opacity) in zip(paths, [0.55, 0.82, 1.0]) {
                coloured.fill(path, with: .color(region.colour.opacity(opacity)))
            }
        }
    }
    static func draw(
        _ bands: BandWaveformColumns, in context: inout GraphicsContext, size: CGSize, scale: Double,
        regions: [ArrangementColourRegion]
    ) {
        let paths = [bands.low, bands.mid, bands.high].map { mirrored($0, scale: scale, middle: size.height / 2) }
        draw(
            paths,
            fallback: [
                PerformancePalette.waveLow.opacity(0.92), PerformancePalette.waveMid.opacity(0.95),
                PerformancePalette.waveHigh.opacity(0.9),
            ], regions: regions, in: &context, size: size)
    }
    /// Use the same section colours while the detailed band waveform prepares.
    static func draw(
        _ layers: WaveformLayers, in context: inout GraphicsContext, size: CGSize, scale: Double,
        regions: [ArrangementColourRegion]
    ) {
        let count = max(0, Int(size.width * scale))
        let paths = [\WaveformLayers.Column.peak, \WaveformLayers.Column.body, \WaveformLayers.Column.core].map {
            keyPath in
            var heights = [Double](repeating: 0, count: count)
            for column in layers.columns where column.x < count { heights[column.x] = column[keyPath: keyPath] }
            return mirrored(heights, scale: scale, middle: size.height / 2)
        }
        draw(
            paths, fallback: [PerformancePalette.waveLow, PerformancePalette.waveMid, PerformancePalette.waveHigh],
            regions: regions, in: &context, size: size)
    }
    /// Bar lines brighter than beat lines. Positions are in device pixels.
    static func drawBeats(
        _ beats: [(x: Double, downbeat: Bool)], in context: inout GraphicsContext, size: CGSize, scale: Double
    ) {
        for beat in beats {
            let x = beat.x / scale
            var line = Path()
            line.move(to: CGPoint(x: x, y: 0))
            line.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(
                line, with: .color(beat.downbeat ? Color(white: 0.82) : PerformancePalette.beatLine.opacity(0.5)),
                lineWidth: beat.downbeat ? 1.5 : 1)
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
    var sections: [ArrangementSection] = []
    @Environment(\.displayScale) private var displayScale
    @State private var prepared: (WaveformIndexKey, WaveformRangeIndex)?
    @Environment(\.snapshotWaveformIndexes) private var snapshotIndexes
    var body: some View {
        Canvas { context, size in
            let a = track.analysis
            let span = max(1, visibleSeconds * a.sampleRate)
            let left = centerFrame - span / 2
            let scale = max(1, Double(displayScale))
            let pixels = max(1, Int(size.width * scale))
            let index = WaveformIndexes.visible(a, prepared: prepared, snapshots: snapshotIndexes)
            if let decoded = a.waveformDecodedFrames {
                let x = max(0, min(size.width, (Double(decoded) - left) / span * size.width))
                context.fill(
                    Path(CGRect(x: x, y: 0, width: size.width - x, height: size.height)),
                    with: .color(Color.gray.opacity(0.10)))
            }
            let regions = ArrangementColourRegion.visible(
                sections, left: left, span: span, width: size.width, height: size.height)
            if let band, band.frameCount == a.frameCount {
                WaveformView.draw(
                    BandWaveformColumns(band, left: left, span: span, pixelWidth: pixels, height: size.height),
                    in: &context, size: size, scale: scale, regions: regions)
            } else {
                WaveformView.draw(
                    WaveformLayers(
                        index: index, framesPerBin: a.waveformFramesPerBin, left: left, span: span, width: pixels,
                        height: size.height), in: &context, size: size, scale: scale, regions: regions)
            }
            if let grid {
                WaveformView.drawBeats(
                    WaveformLayers.beatLines(
                        grid: grid, adaptiveMap: adaptiveMap, left: left, span: span, width: pixels), in: &context,
                    size: size, scale: scale)
            }
            let perPixel = span / max(1, size.width)
            for (frame, colour, width) in [
                (playheadFrame, PerformancePalette.red, 2.0), (leadInFrame, Color(white: 0.8), 1.0),
            ] {
                if let frame {
                    let x = (frame - left) / perPixel
                    var marker = Path()
                    marker.move(to: CGPoint(x: x, y: 0))
                    marker.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(marker, with: .color(colour), lineWidth: width)
                }
            }
        }.clipped().task(id: WaveformIndexKey(track.analysis)) {
            let key = WaveformIndexKey(track.analysis)
            let index = await WaveformIndexes.shared.load(track.analysis)
            guard !Task.isCancelled else { return }
            prepared = (key, index)
        }
    }
}

@MainActor struct LoadSlider: View {
    var tall = false
    let load: (DeckID) -> Void
    @State private var gesture = LoadSliderGestureSession()
    @State private var contactActive = false
    @State private var contactGeometry = LoadSliderContactGeometry()
    @State private var ignoreUntilRelease = false
    @GestureState private var dragging = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.deckPanelPresented) private var panelPresented
    @Environment(\.touchSurfaceAcceptsNewContacts) private var acceptsNewContacts
    @Environment(\.touchSurfaceInterruption) private var touchInterruption
    private var maximumTravel: Double { tall ? TallLoadSliderMetrics.maximumTravel : 18 }
    var body: some View {
        VStack(spacing: 0) {
            Text("A").font(.system(size: tall ? 28 : 9, weight: .heavy)).foregroundStyle(
                gesture.armedDeck == .a ? PerformancePalette.cyan : Color(white: tall ? 0.45 : 0.88)
            ).frame(height: tall ? TallLoadSliderMetrics.labelHeight : nil)
            ZStack {
                if tall { RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.3)) }
                VStack(spacing: 2) {
                    if tall { Image(systemName: "chevron.up").font(.system(size: 10)) }
                    Text("LOAD").font(.system(size: tall ? 17 : 10, weight: .bold))
                    if tall { Image(systemName: "chevron.down").font(.system(size: 10)) }
                }.padding(tall ? 4 : 6).frame(maxWidth: tall ? .infinity : nil).frame(
                    height: tall ? TallLoadSliderMetrics.handleHeight : nil
                ).bevelPanel(cornerRadius: 4).offset(y: gesture.offset)
            }.frame(height: tall ? TallLoadSliderMetrics.railHeight : nil)
            Text("B").font(.system(size: tall ? 28 : 9, weight: .heavy)).foregroundStyle(
                gesture.armedDeck == .b ? PerformancePalette.cyan : Color(white: tall ? 0.45 : 0.88)
            ).frame(height: tall ? TallLoadSliderMetrics.labelHeight : nil)
        }.frame(width: tall ? 96 : 64, height: tall ? TallLoadSliderMetrics.height : 56).padding(tall ? 4 : 0)
            .background(RoundedRectangle(cornerRadius: 6).fill(PerformancePalette.sunken)).contentShape(Rectangle())
            .overlay {
                GeometryReader { geometry in
                    Color.clear.contentShape(Rectangle()).highPriorityGesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .global).updating($dragging) { _, active, _ in
                            active = true
                        }.onChanged { value in
                            guard !ignoreUntilRelease else { return }
                            if !contactActive {
                                guard panelPresented, acceptsNewContacts,
                                    contactGeometry.begin(frame: geometry.frame(in: .global))
                                else {
                                    ignoreUntilRelease = true
                                    return
                                }
                                contactActive = true
                                handle(.began, at: value.startLocation)
                            }
                            handle(.moved, at: value.location)
                        }.onEnded { value in
                            if !ignoreUntilRelease, contactActive, panelPresented { handle(.ended, at: value.location) }
                            cancelContact(untilRelease: false)
                        })
                }
            }.onChange(of: dragging) { _, active in if !active { cancelContact(untilRelease: false) } }.onChange(
                of: panelPresented
            ) { _, presented in if !presented { cancelContact() } }.onChange(of: touchInterruption) { _, _ in
                cancelContact()
            }.accessibilityLabel("Load track. Drag up for deck A or down for deck B.").accessibilityAction(
                named: "Load deck A"
            ) { if panelPresented && acceptsNewContacts { load(.a) } }.accessibilityAction(named: "Load deck B") {
                if panelPresented && acceptsNewContacts { load(.b) }
            }.onDisappear { cancelContact() }
    }
    private func cancelContact(untilRelease: Bool = true) {
        contactActive = false
        contactGeometry.cancel()
        gesture = LoadSliderGestureSession()
        ignoreUntilRelease = untilRelease && dragging
    }
    private func handle(_ phase: SurfaceEvent.Phase, at point: CGPoint) {
        guard contactActive, let mapped = contactGeometry.point(at: point) else { return }
        let event = SurfaceEvent(phase: phase, points: [mapped], ending: phase == .ended ? [1] : [])
        let deck = gesture.handle(
            event, height: contactGeometry.height, maximumTravel: maximumTravel, edgeTapThreshold: tall ? 0.22 : nil,
            edgeTapMovementTolerance: 10)
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
        for deck in DeckID.primary { await model.prepareArrangement(deck: deck) }
        var indexes: [WaveformIndexKey: WaveformRangeIndex] = [:]
        for deck in DeckID.primary {
            if let track = model.track(deck) {
                indexes[WaveformIndexKey(track.analysis)] = await WaveformIndexes.shared.load(track.analysis)
            }
        }
        let collection =
            model.browserVisible
            ? try? await CollectionProjection.build(
                tracks: model.library.tracks, suggestionIDs: nil, search: "", sort: .title, category: .songs,
                group: nil, playlists: .init(), catalog: nil) : nil
        var bands: [String: BandWaveform] = [:]
        for deck in DeckID.primary {
            if let track = model.track(deck) {
                _ = try? PCMCache.prepare(track: track, store: model.store)
                bands[track.id] = await BandWaveforms.shared.load(track: track, store: model.store, core: model.playback.core, patience: 5)
            }
        }
        return environment(\.snapshotWaveformIndexes, indexes).environment(\.snapshotCollectionProjection, collection)
            .environment(\.snapshotBandWaveforms, bands)
    }
}

// Keep playback observations in the leaf views that render them.

@MainActor private struct PerformanceToolbar: View {
    @Bindable var model: ReplicaModel
    @Binding var tempoWheelVisible: Bool
    @Binding var audioSettingsPresented: Bool
    @Binding var importPresented: Bool
    @Binding var traktorImportPresented: Bool

    private var horizontalInset: CGFloat {
        #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad { return 12 }
        #endif
        return 32
    }

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                toolbarRow(showClock: true, showsWordmark: true)
                toolbarRow(showClock: false, showsWordmark: true)
                toolbarRow(showClock: false, showsWordmark: false)
            }.frame(height: 60)
            if model.preparationImport != nil || model.analysisProgress != nil {
                HStack(spacing: 12) {
                    if let progress = model.preparationImport { PreparationImportPill(progress: progress) }
                    if let progress = model.analysisProgress { PreparationImportPill(progress: progress) }
                    Spacer(minLength: 0)
                }.padding(.horizontal, horizontalInset).frame(height: 24).clipped()
            }
        }.background(
            LinearGradient(
                colors: [PerformancePalette.raised, PerformancePalette.frame], startPoint: .top, endPoint: .bottom))
    }
    private func toolbarRow(showClock: Bool, showsWordmark: Bool) -> some View {
        HStack(spacing: 8) {
            GenErikBrandLockup(showsWordmark: showsWordmark)
            Spacer(minLength: 8)
            HStack(spacing: 0) {
                if showClock {
                    TimelineView(.everyMinute) { context in
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                            Text(context.date.formatted(date: .omitted, time: .shortened)).monospacedDigit()
                        }.padding(.horizontal, 12)
                    }
                    Divider().frame(height: 22)
                }
                MasterTempoButton(model: model, tempoWheelVisible: $tempoWheelVisible).padding(.horizontal, 12).popover(
                    isPresented: $tempoWheelVisible
                ) { TempoWheel(model: model).padding(16) }
                if showClock { BatteryReadout() }
            }.font(.system(size: 16, weight: .medium)).foregroundStyle(PerformancePalette.text).fixedSize(
                horizontal: true, vertical: false
            ).frame(height: 44).bevelPanel(cornerRadius: 6, sunken: true)
            Spacer(minLength: 8)
            NotificationCenterButton(model: model)
            HStack(spacing: 0) {
                Button {
                    if model.browserVisible { model.browserVisible = false } else { model.showLibrary() }
                } label: {
                    Image(systemName: "music.note").font(.system(size: 18)).foregroundStyle(
                        model.browserVisible ? PerformancePalette.cyan : PerformancePalette.text
                    ).frame(width: 44, height: 44)
                }.accessibilityLabel("Music library")
                Divider().frame(height: 22)
                Button {
                    audioSettingsPresented.toggle()
                } label: {
                    Image(systemName: "speaker.wave.2.fill").font(.system(size: 18)).frame(width: 44, height: 44)
                }.accessibilityLabel("Audio routing").popover(isPresented: $audioSettingsPresented) {
                    AudioQuickPanel(model: model)
                }
            }.frame(height: 44).bevelPanel(cornerRadius: 5)
        }.padding(.horizontal, horizontalInset)
    }
}

/// RECORD, SPLIT OUTPUT and MASTER, as in the original speaker popover, with routing details below.
@MainActor struct AudioQuickPanel: View {
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
            row(model.automaticOutputDevice.map { "\($0.uppercased()) OUTPUT" } ?? "SPLIT OUTPUT") {
                if model.automaticOutputDevice != nil {
                    Text("Automatic").foregroundStyle(.secondary)
                } else {
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { model.outputRoute == .masterAndHeadphones },
                            set: { model.setOutputRoute($0 ? .masterAndHeadphones : .stereoMaster) })
                    ).labelsHidden().disabled(model.isRecording || model.recordingFinishing).accessibilityLabel(
                        "Split output")
                }
            }
            Divider()
            row("MASTER") {
                Slider(
                    value: Binding(
                        get: { model.playbackSnapshot?.masterGain ?? 0.5 }, set: { model.setMixer(.master, value: $0) }),
                    in: 0...1
                ).frame(width: 170).tint(PerformancePalette.cyan).accessibilityLabel("Master level")
            }
            Divider()
            DisclosureGroup("Routing and headphones", isExpanded: $details) {
                AudioSettingsView(model: model)
                HStack {
                    ForEach([DeckID.a, .b], id: \.self) { deck in
                        Button {
                            model.toggleKeylock(deck: deck)
                        } label: {
                            Label(
                                "Keylock \(deck.rawValue.uppercased())",
                                systemImage: model.controlDisplay[deck].keylock == true
                                    ? "checkmark.circle.fill" : "circle")
                        }.disabled(
                            model.track(deck) == nil || model.preparingPlayback.contains(deck)
                                || model.controlDisplay[deck].phase == .queued)
                    }
                    Spacer()
                    Button {
                        model.stopAudio()
                    } label: {
                        Label("Stop audio", systemImage: "stop.fill")
                    }
                }
            }.padding(14).font(.system(size: 13))
        }.frame(width: 360).foregroundStyle(PerformancePalette.text).background(PerformancePalette.panel).alert(
            "Recording location", isPresented: $locationPrompt
        ) {
            TextField("Venue or location", text: $model.recordingLocation)
            Button("Record") { Task { await model.toggleRecording() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Add a venue or location for the recording filename.")
        }
    }
    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(PerformancePalette.secondaryText)
            Spacer()
            content()
        }.padding(.horizontal, 14).frame(height: 54)
    }
}

@MainActor struct BatteryReadout: View {
    #if os(iOS)
        @Environment(\.scenePhase) private var scenePhase
        @State private var level: Float = -1
        @State private var isCharging = false
    #endif

    var body: some View {
        #if os(iOS)
            HStack(spacing: 0) {
                if let reading = Self.presentation(for: level, isCharging: isCharging) {
                    HStack(spacing: 5) {
                        Image(systemName: reading.symbol)
                            .foregroundStyle(reading.tint)
                        if let symbol = reading.chargingSymbol {
                            Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                        }
                        Text("\(reading.percent)%").monospacedDigit()
                    }.padding(.horizontal, 14).overlay(alignment: .leading) { Divider().frame(height: 22) }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Battery")
                        .accessibilityValue(isCharging ? "\(reading.percent)%, charging" : "\(reading.percent)%")
                }
            }.onAppear {
                UIDevice.current.isBatteryMonitoringEnabled = true
                refresh()
            }.onReceive(
                NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
                    .merge(with: NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification))
                    .receive(on: RunLoop.main)
            ) { _ in
                refresh()
            }.onChange(of: scenePhase) { _, phase in
                if phase == .active { refresh() }
            }
        #else
            EmptyView()
        #endif
    }
    #if os(iOS)
        private func refresh() {
            let device = UIDevice.current
            level = device.batteryLevel
            isCharging = device.batteryState == .charging
        }
    #endif

    static func presentation(for level: Float, isCharging: Bool = false)
        -> (percent: Int, symbol: String, tint: Color, chargingSymbol: String?)?
    {
        guard (0...1).contains(level) else { return nil }
        let percent = Int((level * 100).rounded())
        let fill = switch percent {
        case 100: 100
        case 63...: 75
        case 38...: 50
        case 1...: 25
        default: 0
        }
        let tint: Color = if level < 0.10 {
            PerformancePalette.red
        } else if level < 0.20 {
            .orange
        } else {
            PerformancePalette.text
        }
        return (percent, "battery.\(fill)percent", tint, isCharging ? "bolt.fill" : nil)
    }
}

@MainActor private struct DeckHeader: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    var dense = false
    var showsArtwork = true
    @AppStorage(DeckToolSettings.beatJump) private var beatJump = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                if showsArtwork {
                    Button {
                        model.showSuggestions(destination: deck)
                    } label: {
                        ZStack {
                            PerformancePalette.sunken
                            DeckArtwork(
                                source: ArtworkSource.track(track, item: selection, media: model.store.mediaDirectory))
                        }.frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 3)).overlay(
                            RoundedRectangle(cornerRadius: 3).strokeBorder(Color.black.opacity(0.7)))
                    }.accessibilityLabel("Suggestions for deck \(deck.rawValue.uppercased())")
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(selection?.title ?? track?.title ?? "Deck \(deck.rawValue.uppercased())").font(
                            .system(size: dense ? 16 : 19, weight: .semibold)
                        ).foregroundStyle(PerformancePalette.text).lineLimit(1)
                        if dense {
                            Text(selection?.artist ?? track?.artist ?? "").font(.system(size: 12)).foregroundStyle(
                                PerformancePalette.secondaryText
                            ).lineLimit(1)
                        }
                        if NativeAnalysisPlan.isMix(duration: track?.analysis.duration) { MixBadge(size: 14) }
                    }
                    HStack(spacing: 10) {
                        if !dense || track == nil {
                            Text(selection?.artist ?? track?.artist ?? "Swipe up to browse your collection").lineLimit(
                                1)
                        }
                        if track != nil {
                            HStack(spacing: 3) {
                                Image(systemName: playback?.keylock == true ? "lock.fill" : "music.note").font(
                                    .system(size: 11))
                                Text(track?.key?.openKeyName ?? "—")
                            }.accessibilityLabel("Key. Keylock \(playback?.keylock == true ? "on" : "off")")
                            HStack(spacing: 3) {
                                Image(systemName: "waveform.path.ecg").font(.system(size: 11))
                                DeckTempoReadout(model: model, deck: deck)
                            }
                            ArrangementDeckStrip(
                                model: model, deck: deck, rowHeight: 14, showsEditorButton: false, inHeader: true)
                        }
                    }.font(.system(size: dense ? 12 : 15)).foregroundStyle(PerformancePalette.secondaryText)
                }
                Spacer()
                if editing {
                    GridEditBar(model: model, deck: deck).protectsFrontDeckSwipe()
                } else {
                    if beatJump && track != nil {
                        ForEach([-1.0, 1.0], id: \.self) { direction in
                            Button {
                                model.beatJump(beats: direction * model.performance.loopBeats(for: deck), deck: deck)
                            } label: {
                                Image(systemName: direction < 0 ? "chevron.left.2" : "chevron.right.2").font(
                                    .system(size: 15, weight: .semibold)
                                ).foregroundStyle(PerformancePalette.text).frame(width: 54, height: 44).bevelPanel(
                                    cornerRadius: 3)
                            }.protectsFrontDeckSwipe().accessibilityLabel(
                                "Beat jump \(direction < 0 ? "back" : "forward") on deck \(deck.rawValue.uppercased())")
                        }
                    }
                    HStack(spacing: 1) {
                        Button {
                            model.toggleSync(deck: deck)
                        } label: {
                            Text("SYNC").font(.system(size: 17, weight: .medium)).foregroundStyle(syncColour).padding(
                                .horizontal, 12
                            ).frame(height: 44).background(
                                RoundedRectangle(cornerRadius: 3).fill(
                                    playback?.synced == true
                                        ? PerformancePalette.syncGreenBackground : PerformancePalette.sunken)
                            ).overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.white.opacity(0.08)))
                        }.disabled(track == nil || preparing).protectsFrontDeckSwipe().accessibilityLabel(
                            "Sync deck \(deck.rawValue.uppercased())")
                        Button {
                            model.toggleGridEditing(deck: deck)
                        } label: {
                            FourBeatGridIcon().foregroundStyle(editing ? Color.orange : PerformancePalette.text).frame(
                                width: 44, height: 44
                            ).bevelPanel(cornerRadius: 3)
                        }.disabled(track == nil || preparing || playback?.phase == .queued).protectsFrontDeckSwipe()
                            .accessibilityLabel("Edit grid on deck \(deck.rawValue.uppercased())")
                    }.background(PerformancePalette.sunken, in: RoundedRectangle(cornerRadius: 5))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5).strokeBorder(PerformancePalette.secondaryText.opacity(0.5))
                                .allowsHitTesting(false)
                        }.layoutPriority(1)
                }
            }.frame(minWidth: 0, maxWidth: .infinity).clipped().contentShape(Rectangle())
        }.padding(.horizontal, 8).padding(.vertical, dense ? 0 : 8)

    }
    private var selection: MusicLibraryItem? { model.pendingNativeSelection[deck] }
    private var track: Track? { selection == nil ? model.track(deck) : nil }
    private var playback: DeckControlDisplay? { model.controlDisplay[deck] }
    private var editing: Bool { selection == nil && model.editing.contains(deck) }
    private var preparing: Bool { model.preparingTrack.contains(deck) }
    private var syncColour: Color {
        guard let playback, playback.synced else { return Color(white: 0.6) }
        if model.controlDisplay[deck].needsAlignment { return PerformancePalette.red }
        return PerformancePalette.syncGreen
    }
}

@MainActor private struct DeckWaveform: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    @Binding var visibleSeconds: Double
    let mixerVisible: Bool
    @AppStorage(BrowserSettings.superSlicerKey) private var superSlicer = true

    var body: some View {
        Group {
            if let failure = model.trackLoadFailures[deck], !model.preparingTrack.contains(deck) {
                Text(failure).font(.callout).foregroundStyle(.orange).padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black)
            } else if model.pendingNativeSelection[deck] != nil {
                if let preview = model.pendingNativeWaveforms[deck], !preview.analysis.waveform.isEmpty {
                    WaveformView(
                        track: preview, grid: preview.grid, centerFrame: 0,
                        visibleSeconds: visibleSeconds, playheadFrame: 0,
                        sections: model.arrangements[preview.id]?.sections ?? [])
                } else {
                    Color.black
                }
            } else if let track {
                HStack(spacing: 0) {
                    if model.frozen.contains(deck), !editing, superSlicer {
                        SuperSlicerControls(model: model, deck: deck)
                    }
                    DeckWaveformDrawing(model: model, deck: deck, track: track, visibleSeconds: visibleSeconds).overlay
                    {
                        if model.preparingSourceActions.contains(deck) {
                            Text("Preparing audio…").font(.caption).foregroundStyle(.secondary).allowsHitTesting(false)
                        } else if model.preparingWaveforms.contains(track.id) {
                            Text("Preparing waveform…").font(.caption).foregroundStyle(.secondary).allowsHitTesting(
                                false)
                        } else if track.analysis.waveformDecodedFrames != nil {
                            Text("Reading waveform…").font(.caption).foregroundStyle(.secondary).allowsHitTesting(false)
                        }
                    }.contentShape(Rectangle()).overlay {
                        PerformanceOverlay(model: model, deck: deck, span: visibleSeconds * track.analysis.sampleRate)
                    }.overlay(alignment: .topLeading) {
                        if editing, let grid = model.grid(deck) {
                            GridBeatMarkers(
                                model: model, deck: deck, grid: grid, center: model.viewport[deck] ?? 0,
                                span: visibleSeconds * track.analysis.sampleRate)
                        }
                    }.overlay {
                        WaveformTouch(model: model, deck: deck, span: visibleSeconds * track.analysis.sampleRate) {
                            frameSpan in
                            visibleSeconds = WaveformZoom.seconds(
                                frameSpan: frameSpan, sampleRate: track.analysis.sampleRate,
                                duration: track.analysis.duration)
                        }.id(model.loadIdentity(deck))
                    }
                }

            } else {
                ZStack {
                    Color.black
                    Text("No track loaded").font(.system(size: 12)).foregroundStyle(.secondary)
                }.contentShape(Rectangle()).gesture(
                    DragGesture(minimumDistance: 40).onEnded { value in
                        if !mixerVisible && value.translation.height < -70
                            && abs(value.translation.height) > abs(value.translation.width)
                        {
                            model.showLibrary()
                        }
                    })
            }
        }

    }
    private var track: Track? { model.track(deck) }
    private var editing: Bool { model.editing.contains(deck) }

}

@MainActor private struct DeckWaveformDrawing: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let track: Track
    let visibleSeconds: Double
    @AppStorage(DeckToolSettings.sectionWaveformColours) private var sectionColours = true
    @State private var band: (String, BandWaveform)?
    @Environment(\.snapshotBandWaveforms) private var snapshotBands
    var body: some View {
        let playback = model.waveformPlayback(deck)
        WaveformView(
            track: track, grid: model.grid(deck), centerFrame: model.viewport[deck] ?? 0,
            visibleSeconds: visibleSeconds, adaptiveMap: playback?.adaptiveMap,
            playheadFrame: playback?.sourceFrame ?? 0,
            leadInFrame: playback?.leadInSourceFrame,
            band: band?.0 == track.id ? band?.1 : snapshotBands[track.id],
            sections: sectionColours ? model.arrangements[track.id]?.sections ?? [] : []
        ).overlay {
            ArrangementWaveformOverlay(
                model: model, deck: deck, track: track, center: model.viewport[deck] ?? 0,
                span: visibleSeconds * track.analysis.sampleRate)
        }.task(id: track.id) {
            let id = track.id
            guard let loaded = await BandWaveforms.shared.load(track: track, store: model.store, core: model.playback.core), !Task.isCancelled
            else { return }
            band = (id, loaded)
        }
    }
}

@MainActor private struct DeckOverview: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    @Binding var visibleSeconds: Double

    var body: some View {
        if model.pendingNativeSelection[deck] != nil, let preview = model.pendingNativeWaveforms[deck] {
            WaveformView(
                track: preview, grid: nil, centerFrame: Double(preview.analysis.frameCount) / 2,
                visibleSeconds: preview.analysis.duration, sections: model.arrangements[preview.id]?.sections ?? [])
        } else if let track {
            StripeView(model: model, deck: deck, track: track, visibleSeconds: $visibleSeconds)
                .id(model.loadIdentity(deck))
        } else {
            Color.black
        }

    }
    private var track: Track? { model.track(deck) }

}

@MainActor private struct DeckFooter: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID

    var body: some View {
        HStack(spacing: 18) {
            if let track, model.arrangements[track.id] != nil {
                ArrangementRemainingTime(model: model, deck: deck)
            } else {
                Text(remainingTime).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
            if let recovery = model.recoveryLabel(deck: deck) {
                Text(recovery).font(.system(size: 11)).foregroundStyle(PerformancePalette.syncGreen).accessibilityLabel(
                    recovery)
            }
            Spacer()
            if editing, let grid = model.grid(deck) {
                ForEach(0..<4) { beat in
                    Button("\(beat + 1)") { model.selectDownbeat(deck: deck, beat: beat) }.frame(width: 44, height: 44)
                        .foregroundStyle(
                            (model.timing(deck)?.downbeatOffset ?? grid.downbeatOffset) == beat ? .orange : deckBlue)
                }
            }
        }.padding(.horizontal, 8).frame(height: 44).background(surface)

    }
    private var track: Track? { model.track(deck) }
    private var playback: DeckPlaybackSnapshot? { model.playbackSnapshot?[deck] }
    private var editing: Bool { model.editing.contains(deck) }
    private var remainingTime: String {
        guard let track else { return "—:—" }
        let remaining = max(
            0, Int(ceil(track.analysis.duration - (playback?.sourceFrame ?? 0) / track.analysis.sampleRate)))
        return String(format: "−%d:%02d", remaining / 60, remaining % 60)
    }
}

@MainActor private struct DeckTransportButtons: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID

    var body: some View {
        Group {
            Button {
                model.setMixer(.cue, value: playback?.mixer.cue == true ? 0 : 1, deck: deck)
            } label: {
                Image(systemName: "headphones").foregroundStyle(
                    playback?.mixer.cue == true ? deckBlue : Color(white: 0.65))
            }.accessibilityLabel("Headphone cue for deck \(deck.rawValue.uppercased())")
            DeckPlaybackButton(model: model, deck: deck)
        }
    }
    private var track: Track? { model.track(deck) }
    private var playback: DeckControlDisplay? { model.controlDisplay[deck] }
    private var preparing: Bool { model.preparingPlayback.contains(deck) }

}

@MainActor private struct MasterTempoButton: View {
    @Bindable var model: ReplicaModel
    @Binding var tempoWheelVisible: Bool
    var body: some View {
        Button {
            tempoWheelVisible.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                Text(String(format: "%.1f", model.controlDisplay.masterBPM)).monospacedDigit()
            }
        }.accessibilityLabel("Master tempo")
    }
}
@MainActor private struct DeckTempoReadout: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    var body: some View {
        Text(
            model.grid(deck).map {
                String(
                    format: "%.1f",
                    (model.playbackSnapshot?[deck].adaptiveMap?.bpm(
                        atFrame: model.editing.contains(deck)
                            ? model.viewport[deck] ?? 0 : model.playbackSnapshot?[deck].sourceFrame ?? 0) ?? $0.bpm)
                        * (model.editing.contains(deck) ? 1 : model.controlDisplay[deck].speed))
            } ?? "—"
        ).monospacedDigit()
    }
}

/// Grid editing controls: lock, tap mode, halve, tempo (tap when in tap mode), double, reset and done.
@MainActor struct GridEditBar: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    var body: some View {
        let locked = model.gridLocked.contains(deck)
        let tapping = model.gridTapMode.contains(deck)
        HStack(spacing: 6) {
            Menu {
                Button("Automatic") { model.selectGridMode(.automatic, deck: deck) }
                Button("Fixed") { model.selectGridMode(.fixed, deck: deck) }
                Button("Adaptive") { model.selectGridMode(.adaptive, deck: deck) }
                Button(model.detectingGrids.contains(deck) ? "Detecting grid…" : "Detect grid from audio") {
                    model.detectGrid(deck: deck)
                }.disabled(
                    locked || model.detectingGrids.contains(deck) || model.arrangementPlaybackActive
                        || (model.gridPreparation(deck)?.gridMode != .fixed
                            && model.gridPreparation(deck)?.adaptiveMap != nil)
                )
                Button("Correct local anchor") { model.correctLocalAnchor(deck: deck) }.disabled(
                    model.gridPreparation(deck)?.adaptiveMap == nil)
                Button("Undo correction") { model.undoGridCorrection(deck: deck) }
                Button(model.gridPreparation(deck)?.gridLocked == true ? "Unlock preparation" : "Lock preparation") {
                    model.setGridLocked(model.gridPreparation(deck)?.gridLocked != true, deck: deck)
                }
                if let confidence = model.candidateConfidence(deck) {
                    Text("Candidate confidence estimate: \(Int(confidence * 100))%")
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            button(locked ? "lock.fill" : "lock.open", label: "Lock grid") {
                if model.gridLocked.remove(deck) == nil { model.gridLocked.insert(deck) }
                model.setGridLocked(model.gridLocked.contains(deck), deck: deck)
            }.frame(width: 40)
            text("TAP MODE", active: tapping) {
                if model.gridTapMode.remove(deck) == nil { model.gridTapMode.insert(deck) }
            }.disabled(locked)
            HStack(spacing: 0) {
                text("/2") { model.correctTempo(deck: deck, factor: 0.5) }
                if tapping {
                    text("TAP", active: true) { model.tapTempo(deck: deck) }
                } else {
                    Text(
                        model.grid(deck).map {
                            String(
                                format: "%.1f",
                                model.playbackSnapshot?[deck].adaptiveMap?.bpm(atFrame: model.viewport[deck] ?? 0)
                                    ?? $0.bpm)
                        } ?? "—"
                    ).font(.system(size: 15).monospacedDigit()).foregroundStyle(PerformancePalette.cyan).frame(
                        width: 70, height: 44
                    ).background(PerformancePalette.sunken)
                }
                text("x2") { model.correctTempo(deck: deck, factor: 2) }
            }.disabled(locked || model.grid(deck) == nil)
            text("RESET") { model.resetGrid(deck: deck) }.disabled(locked)
            text("DONE") { model.toggleGridEditing(deck: deck) }
        }.font(.system(size: 14, weight: .medium)).foregroundStyle(PerformancePalette.text)
    }
    private func button(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).frame(maxWidth: .infinity).frame(height: 44).bevelPanel(cornerRadius: 3)
        }.accessibilityLabel(label)
    }
    private func text(_ title: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).padding(.horizontal, 10).frame(height: 44).foregroundStyle(
                active ? PerformancePalette.cyan : PerformancePalette.text
            ).bevelPanel(cornerRadius: 3)
        }
    }
}

/// Numbered bar positions over the waveform while editing. Tapping a number makes that beat beat 1.
@MainActor struct GridBeatMarkers: View {
    @Bindable var model: ReplicaModel
    let deck: DeckID
    let grid: BeatGrid
    let center: Double
    let span: Double
    var body: some View {
        GeometryReader { geometry in
            let left = center - span / 2
            let perPoint = span / max(1, geometry.size.width)
            let timing = model.timing(deck) ?? BeatTiming(fixed: grid)
            let first = Int(exactly: ceil(timing.beat(atFrame: left))) ?? 0
            let last = Int(exactly: ceil(timing.beat(atFrame: left + span))) ?? first
            ForEach(0..<max(0, min(64, last - first + 1)), id: \.self) { offset in
                let beat = first + offset
                let x = (timing.frame(atBeat: Double(beat)) - left) / perPoint
                if x >= 0 && x <= geometry.size.width {
                    Button {
                        model.setDownbeat(atBeat: beat, deck: deck)
                    } label: {
                        Text("\(((beat-timing.downbeatOffset)%4+4)%4+1)").font(.system(size: 14, weight: .bold))
                            .foregroundStyle(PerformancePalette.text).frame(width: 44, height: 44).bevelPanel(
                                cornerRadius: 3)
                    }.position(x: x + 22, y: 22).accessibilityLabel("Make this beat the downbeat")
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
