import SwiftUI
import TDJCore

@MainActor struct FrontPerformanceView: View {
    @Bindable var model: ReplicaModel
    var importAudio: () -> Void
    var linkCollection: () -> Void
    @State private var selection = FrontDeckSelection(selected: DeckID.a)
    @State private var deckSlide = FrontDeckSlideState()
    @State private var panelsA = DeckPanelPresentation()
    @State private var panelsB = DeckPanelPresentation()
    @State private var browser = FrontBrowserPanelState()
    @State private var requestedTab = BrowserListTab.songs
    @State private var browserRequest = UUID()
    @State private var previousBrowserVisible = false
    @AppStorage("front.activeDeck") private var savedDeck = "a"
    @ScaledMetric(relativeTo: .body) private var selectorHeight = 64.0
    @ScaledMetric(relativeTo: .subheadline) private var controlsHeight = 52.0
    @Environment(\.touchSurfaceInterruption) private var interruption
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var activeDeck: DeckID { selection.selected }
    private var panels: DeckPanelPresentation { activeDeck == .a ? panelsA : panelsB }

    var body: some View {
        GeometryReader { space in
            let layout = FrontWorkspaceGeometry(
                width: space.size.width, height: space.size.height, browserExtent: browser.extent,
                selectorHeight: selectorHeight, controlsHeight: controlsHeight)
            VStack(spacing: 0) {
                deckSelector.frame(height: layout.selector.height)
                ZStack {
                    retainedDeck(.a, panels: panelsA).frame(width: layout.deck.width, height: layout.deck.height)
                        .offset(x: deckSlide.offset(isB: false, width: layout.deck.width))
                    retainedDeck(.b, panels: panelsB).frame(width: layout.deck.width, height: layout.deck.height)
                        .offset(x: deckSlide.offset(isB: true, width: layout.deck.width))
                }.environment(\.touchSurfaceInterruption, selection.contactID).frame(height: layout.deck.height)
                    .clipped()
                browserBar.frame(height: layout.handle.height)
                FrontBrowserView(
                    model: model, importAudio: importAudio, linkCollection: linkCollection, requestedTab: requestedTab,
                    navigationID: browserRequest, destinationDeck: activeDeck
                ).environment(\.touchSurfaceInterruption, browser.contactID).frame(
                    width: layout.library.width, height: layout.library.height, alignment: .top
                ).clipped().allowsHitTesting(browser.acceptsContentInput).disabled(!browser.acceptsContentInput)
                    .accessibilityHidden(!browser.acceptsContentInput)
                performanceControls.id(activeDeck).frame(height: layout.controls.height).protectsFrontDeckSwipe()
                crossfader.frame(height: layout.crossfader.height).protectsFrontDeckSwipe()
            }.frame(width: space.size.width, height: space.size.height, alignment: .top).clipped().background(
                PerformancePalette.stage
            ).overlayPreferenceValue(FrontDeckSwipeProtectionKey.self) { anchors in
                GeometryReader { geometry in
                    FrontDeckSwipeCapture(
                        protectedRegions: anchors.map { geometry[$0] }, selectorRegion: layout.selector,
                        contactID: deckSlide.sessionID, acceptsNewSwipe: !deckSlide.blocksDeckInput
                    ) { event in handleSwipe(event, width: layout.deck.width) }.allowsHitTesting(false)
                }
            }.environment(\.frontDeckSwipeEnabled, true).environment(\.performancePanelPortrait, true).animation(
                reduceMotion || browser.isDragging ? nil : .smooth(duration: 0.22), value: browser.extent
            ).onAppear {
                browser.configure(
                    width: space.size.width, height: space.size.height, selectorHeight: selectorHeight,
                    controlsHeight: controlsHeight)
                selection.select(DeckID(rawValue: savedDeck) ?? .a)
                deckSlide.reset(selectedIsB: activeDeck == .b)
                previousBrowserVisible = model.browserVisible
                model.browserVisible = false
            }.onChange(of: selection.selected) { _, deck in savedDeck = deck.rawValue }.onChange(of: space.size) {
                _, size in
                resetDeckSlide()
                browser.configure(
                    width: size.width, height: size.height, selectorHeight: selectorHeight,
                    controlsHeight: controlsHeight)
            }.onChange(of: selectorHeight) { _, _ in
                resetDeckSlide()
                browser.configure(
                    width: space.size.width, height: space.size.height, selectorHeight: selectorHeight,
                    controlsHeight: controlsHeight)
            }.onChange(of: controlsHeight) { _, _ in
                resetDeckSlide()
                browser.configure(
                    width: space.size.width, height: space.size.height, selectorHeight: selectorHeight,
                    controlsHeight: controlsHeight)
            }.onChange(of: model.browserPresentationID) { _, _ in
                browser.apply(.expand)
                model.browserVisible = true
            }.onChange(of: model.browserVisible) { _, visible in browser.setPresented(visible) }.onChange(
                of: interruption
            ) { _, _ in
                resetDeckSlide()
                selection.interrupt()
                browser.interrupt()
            }.onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    resetDeckSlide()
                    selection.interrupt()
                    browser.interrupt()
                }
            }.onDisappear {
                browser.interrupt()
                resetDeckSlide()
                selection.interrupt()
                model.browserVisible = previousBrowserVisible
            }
        }
    }

    private var deckSelector: some View {
        HStack(spacing: 4) {
            ForEach(DeckID.primary, id: \.self) { deck in
                Button {
                    settleDeck(on: deck)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(deck.rawValue.uppercased()).font(.headline)
                            Spacer(minLength: 4)
                            Text(status(deck)).font(.caption.weight(.semibold))
                        }
                        Text(model.track(deck)?.title ?? "No track").font(.caption).lineLimit(1)
                    }.padding(.horizontal, 10).frame(maxWidth: .infinity, minHeight: 60).background(
                        activeDeck == deck ? PerformancePalette.cyan.opacity(0.2) : PerformancePalette.panel,
                        in: RoundedRectangle(cornerRadius: 5))
                }.accessibilityLabel(
                    "Deck \(deck.rawValue.uppercased()), \(status(deck)), \(model.track(deck)?.title ?? "no track")"
                ).accessibilityAddTraits(activeDeck == deck ? .isSelected : [])
            }
        }.padding(.horizontal, 4).foregroundStyle(PerformancePalette.text)
    }

    private func status(_ deck: DeckID) -> String {
        if model.preparingTrack.contains(deck) || model.preparingPlayback.contains(deck) { return "Loading" }
        return switch model.controlDisplay[deck].phase {
        case .playing: "Playing"
        case .queued: "Queued"
        case .paused: "Paused"
        case .ended: "Ended"
        case .empty: "Empty"
        case .ready: "Ready"
        }
    }

    private func retainedDeck(_ deck: DeckID, panels: DeckPanelPresentation) -> some View {
        DeckView(
            model: model, deck: deck, panels: panels,
            requestPerformanceSpace: { _ in
                guard activeDeck == deck else { return }
                apply(.performance)
            }
        ).allowsHitTesting(activeDeck == deck && !deckSlide.blocksDeckInput).disabled(
            activeDeck != deck || deckSlide.blocksDeckInput
        ).accessibilityHidden(activeDeck != deck || deckSlide.blocksDeckInput).environment(
            \.frontDeckSwipeEnabled, activeDeck == deck)
    }

    private func handleSwipe(_ event: FrontDeckSwipeEvent, width: Double) {
        switch event {
        case .began(let horizontal, let vertical):
            guard deckSlide.begin(selectedIsB: activeDeck == .b, width: width) else { return }
            selection.interrupt()
            deckSlide.update(horizontal: horizontal, vertical: vertical)
        case .changed(let horizontal, let vertical): deckSlide.update(horizontal: horizontal, vertical: vertical)
        case .ended(let horizontal, let vertical, let velocity):
            guard deckSlide.isDragging else { return }
            deckSlide.update(horizontal: horizontal, vertical: vertical)
            let settlementID = UUID()
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.24), completionCriteria: .logicallyComplete) {
                deckSlide.end(velocity: velocity, settlementID: settlementID)
            } completion: {
                completeDeckSlide(settlementID)
            }
        case .cancelled: settleDeck(on: activeDeck)
        }
    }

    private func settleDeck(on deck: DeckID) {
        guard deckSlide.blocksDeckInput || deck != activeDeck else { return }
        selection.interrupt()
        let settlementID = UUID()
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.24), completionCriteria: .logicallyComplete) {
            deckSlide.settle(on: deck == .b, settlementID: settlementID)
        } completion: {
            completeDeckSlide(settlementID)
        }
    }

    private func completeDeckSlide(_ settlementID: UUID) {
        guard let isB = deckSlide.complete(settlementID: settlementID) else { return }
        selection.select(isB ? .b : .a)
    }

    private func resetDeckSlide() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { deckSlide.reset(selectedIsB: activeDeck == .b) }
    }

    private var browserBar: some View {
        HStack(spacing: 4) {
            FrontLibraryGrip(
                begin: { browser.beginDrag() }, update: { browser.updateDrag(translation: $0) },
                end: {
                    browser.endDrag(velocity: $0)
                    model.browserVisible = browser.extent > 0
                }, cancel: { browser.cancelDrag() },
                adjust: {
                    browser.adjust(by: $0)
                    model.browserVisible = browser.extent > 0
                }
            ).protectsFrontDeckSwipe()
            ViewThatFits(in: .horizontal) {
                browserButtons(compact: false)
                browserButtons(compact: true)
            }
            Menu {
                ForEach(LibraryWorkspaceShortcut.allCases, id: \.self) { shortcut in
                    Button(shortcut.rawValue) { apply(shortcut) }
                }
            } label: {
                Image(systemName: "rectangle.split.1x2").frame(width: 44, height: 44)
            }.accessibilityLabel("Performance, Browse and Expand")
        }.font(.subheadline.weight(.semibold)).foregroundStyle(PerformancePalette.text).background(
            PerformancePalette.frame)
    }

    private func browserButtons(compact: Bool) -> some View {
        HStack(spacing: 4) {
            Button {
                open(.songs)
            } label: {
                Group {
                    if compact {
                        Image(systemName: "music.note").font(.system(size: 18))
                    } else {
                        Text("Songs").fixedSize(horizontal: true, vertical: false)
                    }
                }.frame(maxWidth: .infinity, minHeight: 44)
            }.accessibilityLabel("Songs")
            Button {
                open(.suggestions)
            } label: {
                Group {
                    if compact {
                        Image(systemName: "sparkles").font(.system(size: 18))
                    } else {
                        Text("Suggestions").fixedSize(horizontal: true, vertical: false)
                    }
                }.frame(maxWidth: .infinity, minHeight: 44)
            }.accessibilityLabel("Suggestions for deck \(activeDeck.rawValue.uppercased())")
        }
    }

    private func open(_ tab: BrowserListTab) {
        requestedTab = tab
        browserRequest = UUID()
        browser.apply(.expand)
        model.browserVisible = true
    }

    private func apply(_ shortcut: LibraryWorkspaceShortcut) {
        browser.apply(shortcut)
        model.browserVisible = browser.extent > 0
    }

    private var performanceControls: some View {
        HStack(spacing: 4) {
            Button("FX") { panels.toggleEffects() }.foregroundStyle(
                panels.effectsVisible ? Color.orange : PerformancePalette.text)
            Button("EQ") { panels.toggleMixer() }.foregroundStyle(
                panels.mixerVisible ? PerformancePalette.cyan : PerformancePalette.text)
            Button {
                model.toggleLoop(deck: activeDeck)
            } label: {
                Image(systemName: "repeat")
            }.foregroundStyle(
                model.playbackSnapshot?[activeDeck].loopEnabled == true
                    ? PerformancePalette.syncGreen : PerformancePalette.text
            ).accessibilityLabel("Loop on deck \(activeDeck.rawValue.uppercased())")
            Button {
                model.toggleSync(deck: activeDeck)
            } label: {
                Text("Sync")
            }.accessibilityLabel("Sync deck \(activeDeck.rawValue.uppercased())")
            DeckPlaybackButton(model: model, deck: activeDeck)
        }.buttonStyle(FrontControlButtonStyle()).disabled(model.track(activeDeck) == nil).padding(.horizontal, 4)
            .background(PerformancePalette.frame)
    }

    private var crossfader: some View {
        HStack(spacing: 8) {
            Text("A").font(.caption.bold()).accessibilityHidden(true)
            TouchFader(
                value: model.controlDisplay.crossfader, range: 0...1, reset: 0.5, horizontalHeight: 44,
                readValue: { model.controlDisplay.crossfader }, change: { model.setMixer(.crossfader, value: $0) }
            ).accessibilityElement(children: .ignore).accessibilityLabel("Crossfader").accessibilityValue(
                String(format: "%.0f percent toward B", model.controlDisplay.crossfader * 100)
            ).accessibilityAdjustableAction { direction in
                model.setMixer(
                    .crossfader,
                    value: min(1, max(0, model.controlDisplay.crossfader + (direction == .increment ? 0.05 : -0.05))))
            }
            Text("B").font(.caption.bold()).accessibilityHidden(true)
        }.padding(.horizontal, 12).background(PerformancePalette.panel)
    }
}

private struct FrontControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.bold)).frame(maxWidth: .infinity, minHeight: 44).background(
            configuration.isPressed ? PerformancePalette.raised : PerformancePalette.panel,
            in: RoundedRectangle(cornerRadius: 4))
    }
}

private struct FrontLibraryGrip: View {
    let begin: () -> Void
    let update: (Double) -> Void
    let end: (Double) -> Void
    let cancel: () -> Void
    let adjust: (Double) -> Void
    @GestureState private var touching = false
    @State private var vertical: Bool?

    var body: some View {
        Image(systemName: "line.3.horizontal").frame(width: 44, height: 44).contentShape(Rectangle()).gesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .global).updating($touching) { _, active, _ in
                active = true
            }.onChanged { value in
                if vertical == nil {
                    vertical = abs(value.translation.height) >= abs(value.translation.width)
                    if vertical == true { begin() }
                }
                if vertical == true { update(-value.translation.height) }
            }.onEnded { value in
                if vertical == true {
                    update(-value.translation.height)
                    end(-value.velocity.height)
                }
                vertical = nil
            }
        ).onChange(of: touching) { _, active in
            if !active {
                cancel()
                vertical = nil
            }
        }.onDisappear { cancel() }.accessibilityLabel("Resize song browser").accessibilityAdjustableAction {
            direction in adjust(direction == .increment ? 44 : -44)
        }
    }
}
