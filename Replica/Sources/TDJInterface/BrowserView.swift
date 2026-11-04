import SwiftUI
import TDJCore

private let deckBlue = PerformancePalette.cyan
private let surface = PerformancePalette.panel
private let selectedTeal = Color(red: 0.17, green: 0.45, blue: 0.5)

struct BrowserView: View {
    @Bindable var model: ReplicaModel
    var importAudio: () -> Void = {}
    var linkCollection: () -> Void = {}
    @State private var query = ""
    @State private var suggestionQuery = ""
    @State private var prepQuery = ""
    private var hasSearchQuery: Bool { query.contains { !$0.isWhitespace } }
    @State private var sort: CollectionSort? = .title
    private var displayedSort: CollectionSort? { hasSearchQuery ? sort ?? .title : sort }
    @State private var panes = BrowserPaneStack()
    private var category: CollectionCategory { panes.category }
    private var group: String? { panes.group }
    @State private var selectedEntry: LibraryBrowserEntry?
    @State private var recommendations: [BrowserRecommendations.Match] = []
    @State private var recommendationRefresh = UUID()
    @State private var recommendationSeed: LibraryBrowserEntry?
    @State private var recommendationDeck: DeckID?
    @State private var recommendationDestination: DeckID?
    @State private var layout = BrowserLayoutState(categoriesHidden: true)
    @State private var browserWidth = 0.0
    @State private var section = BrowserSection.songs
    private var displayedSection: BrowserSection { hasSearchQuery || layout.tab != .songs ? .songs : section }
    private var showingSuggestions: Bool { showingLists && layout.tab == .suggestions }
    private var showingPrep: Bool { showingLists && layout.tab == .prep }
    private var showingLists: Bool { displayedSection == .songs || displayedSection == .playlists }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var sourcesFocused: Bool
    @AccessibilityFocusState private var detailsFocused: Bool
    @State private var newPlaylistPresented = false
    @State private var playlists = CollectionPlaylists()
    @State private var selecting = false
    @State private var selection = Set<String>()
    @State private var adding = false
    @State private var settingsVisible = false
    @State private var playlistName = ""
    @State private var playlistError: String?
    private var playlistURL: URL { model.store.root.appendingPathComponent("collection-playlists.json") }
    @Environment(\.snapshotCollectionProjection) private var snapshotProjection
    @State private var projection: LibraryBrowserProjection?
    @State private var projectionToken = UUID()
    @State private var playlistSave = LibraryBrowserPlaylistSave()
    private var entryCount: Int { snapshotProjection?.tracks.count ?? projection?.entries.count ?? 0 }
    @State private var snapshotGroups=LibraryGroupSource.empty
    private var groupSource:LibraryGroupSource {
        if snapshotProjection != nil { return snapshotGroups }
        guard displayedRequest?.category == category else { return .empty }
        return projection?.groupSource ?? .empty
    }
    private var groupSourceLoading:Bool { snapshotProjection == nil && displayedRequest?.category != category }
    private func visibleEntries(in range: Range<Int>) -> [LibraryBrowserEntry] {
        if let snapshotProjection { return snapshotProjection.tracks[range].map { LibraryBrowserEntry(track:$0) } }
        guard let projection else { return [] }
        return Array(projection.entries[range])
    }
    @State private var collectionVersion = UUID()
    @State private var searching = true
    @State private var displayedRequest: LibraryBrowserRequest?
    private var request: LibraryBrowserRequest {
        .init(revision: model.library.revision, version: collectionVersion, query: query,
              sort: displayedSort, category: category, group: group,
              suggestionIDs: nil)
    }
    var body: some View { content }
    private var content: some View {
        VStack(spacing: 0) {
            searchBar
            if showingLists { listTabs }
            GeometryReader { geometry in
                let bounds = BrowserContentGeometry(width: geometry.size.width, height: geometry.size.height)
                ZStack(alignment: .leading) {
                    browserLists
                        .allowsHitTesting(layout.categoriesHidden && layout.detailHidden)
                        .accessibilityHidden(!layout.categoriesHidden || !layout.detailHidden)
                    if !layout.categoriesHidden || !layout.detailHidden {
                        Button { closeDrawers() } label: { Color.black.opacity(0.4) }
                            .buttonStyle(.plain).accessibilityLabel("Close browser drawer")
                    }
                    if !layout.categoriesHidden {
                        sourceDrawer.frame(width: bounds.drawerWidth)
                            .background(PerformancePalette.panel)
                            .offset(x: layout.categoryOffset)
                            .transition(.move(edge: .leading))
                    }
                    if !layout.detailHidden {
                        detailPane.frame(width: bounds.drawerWidth)
                            .background(PerformancePalette.panel)
                            .offset(x: layout.detailOffset)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .transition(.move(edge: .trailing))
                    }
                }
                .frame(width: bounds.listArea.width, height: bounds.listArea.height)
                .clipped()
                .onAppear { browserWidth = bounds.listArea.width }
                .onChange(of: bounds.listArea.width) { _, width in
                    browserWidth = width
                    panes.dragChanged(translation: 0)
                    layout.hideDrawers()
                }
            }
            if showingLists { selectedSongShelf }
        }
        .background(PerformancePalette.stage)
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: layout.tab)
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: layout.categoriesHidden)
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: layout.detailHidden)
        .onAppear { handleBrowserPresentation() }
        .onChange(of: model.browserPresentationID) { _, _ in handleBrowserPresentation() }
        .task(id: recommendationKey) { await refreshRecommendations() }
        .onDisappear { playlistSave.cancel() }
        .onChange(of:adding) { _,presented in
            if !presented { playlistSave.cancel() }
        }
        .task {
            if let snapshotProjection { snapshotGroups=LibraryGroupSource(groups:snapshotProjection.groups,sortByName:false) }
            let url=playlistURL
            do { playlists=try await Task.detached(priority:.utility) { try CollectionPlaylists.load(from:url) }.value }
            catch { model.status=error.localizedDescription; playlistError=error.localizedDescription }
        }
        .onChange(of: playlists) { _, _ in collectionVersion = UUID() }
        .onChange(of: model.musicLibraryCatalogVersion) { _, _ in collectionVersion = UUID() }
        .onChange(of: model.browserHintsVersion) { _, _ in collectionVersion = UUID() }
        .task(id: request) {
            let current = request
            searching = true
            do {
                let librarySource = model.libraryReadSource()
                let catalogSource = model.catalogReadSource()
                let hints = model.browserHints
                let result = try await LibraryBrowserProjection.build(librarySource: librarySource, catalogSource: catalogSource,
                    suggestionIDs: current.suggestionIDs, search: current.query, sort: current.sort,
                    category: current.category, group: current.group, playlists: playlists,
                    previous: projection, hints: hints)
                guard !Task.isCancelled, current == request else { return }
                if current.resetsScroll(comparedTo: displayedRequest) { projectionToken = UUID() }
                displayedRequest = current
                projection = result; searching = false
            } catch is CancellationError { }
            catch { searching = false; model.status = error.localizedDescription }
        }
        .sheet(isPresented:$adding) {
            VStack(alignment:.leading,spacing:16) {
                Text("Add to Playlist").font(.headline)
                if let playlistError { Text(playlistError).foregroundStyle(.red) }
                TextField("New playlist name",text:$playlistName).textFieldStyle(.roundedBorder)
                Button("Create Playlist") { savePlaylist() }
                    .disabled(playlistName.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || playlistError != nil || playlistSave.isSaving)
                LibraryGroupList(title:"Playlists",source:projection?.playlistTargets ?? .empty,
                    selectedID:nil,includesAll:false,loading:projection == nil) { group in
                    if let group,let id=UUID(uuidString:group.id) { savePlaylist(id:id) }
                }.frame(height:260).disabled(playlistError != nil || playlistSave.isSaving)
                Button("Cancel") { playlistSave.cancel();adding=false }
            }.padding(24).frame(minWidth:320)
        }
    }
    private var browserLists: some View {
        ZStack {
            Group {
                if displayedSection == .settings {
                    SettingsBrowser(model: model, importAudio: importAudio, linkCollection: linkCollection)
                } else if displayedSection == .recordings {
                    RecordingsBrowser(model: model)
                } else if displayedSection == .history {
                    HistoryBrowser(model: model)
                } else {
                    listColumn
                }
            }
            .opacity(showingSuggestions || showingPrep ? 0 : 1)
            .allowsHitTesting(!showingSuggestions && !showingPrep)
            .accessibilityHidden(showingSuggestions || showingPrep)
            suggestionsPane
                .opacity(showingSuggestions ? 1 : 0)
                .allowsHitTesting(showingSuggestions).accessibilityHidden(!showingSuggestions)
            prepPane
                .opacity(showingPrep ? 1 : 0)
                .allowsHitTesting(showingPrep).accessibilityHidden(!showingPrep)
        }
    }
    private func songRow(_ entry:LibraryBrowserEntry, keyOK: Bool? = nil, tempoOK: Bool? = nil) -> some View {
        HStack(spacing: 12) {
            if selecting && layout.tab == .songs {
                Button {
                    if !selection.insert(entry.membershipID).inserted { selection.remove(entry.membershipID) }
                } label: {
                    Image(systemName:selection.contains(entry.membershipID) ? "checkmark.circle.fill":"circle").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Select \(entry.title)")
            }
            Button { select(entry) } label: {
                HStack(spacing: 12) {
                    DeckArtwork(source:ArtworkSource.track(entry.track,item:entry.nativeItem,media:model.store.mediaDirectory),placeholderSize:14)
                        .frame(width:48,height:48).background(PerformancePalette.sunken).clipShape(RoundedRectangle(cornerRadius:3))
                        .overlay { TrackHeadphoneIndicator(model:model,trackID:entry.track?.id) }
                        .accessibilityHidden(true)
                    VStack(alignment:.leading,spacing:2) {
                        HStack(spacing: 6) {
                            Text(entry.title).font(.body.weight(.semibold)).foregroundStyle(PerformancePalette.text).lineLimit(1)
                            if entry.isMix { MixBadge(size: 12) }
                        }
                        Text(entry.artist).font(.subheadline).foregroundStyle(PerformancePalette.secondaryText).lineLimit(1)
                        if let keyOK, let tempoOK {
                            Text([keyOK ? "Key match" : nil, tempoOK ? "Tempo match" : nil].compactMap { $0 }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(PerformancePalette.secondaryText)
                        }
                        if !entry.canLoad,let item=entry.nativeItem {
                            Text(item.availability.message).font(.system(size:10)).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                    if layout.listShowsTempoAndKey {
                        HStack(spacing: 3) { Image(systemName: "music.note"); Text(entry.key?.openKeyName ?? "—") }
                            .foregroundStyle(KeyColour.colour(entry.key)).frame(width: 70, alignment: .leading)
                        HStack(spacing: 3) { Image(systemName: "waveform.path.ecg"); Text(entry.bpm.map { String(format:"%.1f",$0) } ?? "—") }
                            .foregroundStyle(PerformancePalette.text).frame(width: 90, alignment: .leading)
                    } else {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(entry.key?.openKeyName ?? "—").foregroundStyle(KeyColour.colour(entry.key))
                            Text(entry.bpm.map { String(format:"%.1f",$0) } ?? "—").foregroundStyle(PerformancePalette.secondaryText)
                        }.font(.system(size: 12).monospacedDigit())
                    }
                }.contentShape(Rectangle())
            }
        }.padding(.horizontal,12).padding(.vertical, 6).frame(minHeight: 64)
            .background(model.selectedTrackID == entry.id ? selectedTeal.opacity(0.45) : Color.white.opacity(0.02))
            .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.6)).frame(height: 1) }
    }
    private func select(_ entry: LibraryBrowserEntry) {
        model.selectedTrackID=entry.id
        selectedEntry=entry
    }
    /// Horizontal-only drag in global space, so the moving pane does not change the finger's reading.
    private func horizontalDrag(changed: @escaping (Double) -> Void, ended: @escaping (Double, Double) -> Void) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                changed(value.translation.width)
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                ended(value.translation.width, value.velocity.width)
            }
    }
    private func savePlaylist(id:UUID?=nil) {
        let selected=selection,name=playlistName,librarySource=model.libraryReadSource(),catalogSource=model.catalogReadSource()
        playlistSave.start(resolve:{
            try await LibraryBrowserProjection.selectedIDs(selection:selected,librarySource:librarySource,catalogSource:catalogSource)
        },commit:{ members in
            guard selection == selected else { return }
            var changed=playlists
            try changed.add(trackIDs:members,to:id,name:name)
            model.persistCollectionPlaylists(changed)
            playlists=changed;adding=false;selecting=false;selection=[];playlistName=""
        },failed:{ error in model.status=error.localizedDescription })
    }
}


// MARK: Panes
extension BrowserView {
    private var activeQuery: Binding<String> {
        switch layout.tab {
        case .songs: return $query
        case .suggestions: return $suggestionQuery
        case .prep: return $prepQuery
        }
    }

    fileprivate var searchBar: some View {
        HStack(spacing: 10) {
            Button { layout.categoriesHidden ? layout.showCategories() : closeDrawers() } label: {
                Label("Sources", systemImage: "sidebar.left").frame(minHeight: 44)
            }
            .accessibilityFocused($sourcesFocused)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(PerformancePalette.secondaryText)
                TextField("", text: activeQuery,
                    prompt: Text(layout.tab == .songs ? "Search full library" : "Search \(layout.tab.rawValue.lowercased())"))
                    .textFieldStyle(.plain).foregroundStyle(PerformancePalette.text)
                    .accessibilityLabel(layout.tab == .songs ? "Search full library by song, artist, album or genre" : "Search \(layout.tab.rawValue.lowercased())")
                if !activeQuery.wrappedValue.isEmpty {
                    Button { activeQuery.wrappedValue = "" } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }
                        .accessibilityLabel("Clear search")
                }
            }.padding(.leading, 12).frame(minHeight: 44)
                .background(Capsule().fill(PerformancePalette.sunken))
            if layout.tab == .songs && showingLists {
                Button(selecting ? "Done" : "Edit") { selecting.toggle(); selection=[] }.frame(minWidth: 44, minHeight: 44)
            }
            Button { model.browserVisible = false } label: { Image(systemName: "chevron.down").frame(width: 44, height: 44) }
                .accessibilityLabel("Return to decks")
        }
        .font(.subheadline.weight(.semibold)).foregroundStyle(PerformancePalette.text)
        .padding(.horizontal, 12).padding(.vertical, 4)
        .background(PerformancePalette.panel)
    }

    fileprivate var listTabs: some View {
        HStack(spacing: 8) {
            ForEach(BrowserListTab.allCases, id: \.self) { tab in
                Button {
                    if tab == .suggestions && recommendationSeed == nil { captureRecommendationReference() }
                    layout.selectTab(tab)
                } label: {
                    Text(tab == .prep ? "Prep list (\(model.queuedIDs.count))" : tab.rawValue)
                        .font(.subheadline.weight(.semibold)).lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(layout.tab == tab ? selectedTeal : Color.clear, in: RoundedRectangle(cornerRadius: 5))
                }
                .accessibilityAddTraits(layout.tab == tab ? .isSelected : [])
            }
        }.foregroundStyle(PerformancePalette.text).padding(.horizontal, 12)
            .background(PerformancePalette.panel)
    }

    fileprivate var sourceDrawer: some View {
        VStack(spacing: 0) {
            drawerHeader("Sources", source: true)
            ScrollView {
                VStack(spacing: 0) {
                    categoryColumn
                    Button { newPlaylistPresented = true } label: {
                        Label("New playlist", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }.padding(.horizontal, 22)
                    Divider()
                    sourceButton("Recordings", symbol: "recordingtape", target: .recordings)
                    sourceButton("History", symbol: "clock.fill", target: .history)
                    sourceButton("Settings", symbol: "gearshape.fill", target: .settings)
                }
            }
        }
        .alert("New playlist", isPresented: $newPlaylistPresented) {
            TextField("Name", text: $playlistName)
            Button("Create") { createEmptyPlaylist() }
            Button("Cancel", role: .cancel) { playlistName = "" }
        }
    }

    private func sourceButton(_ title: String, symbol: String, target: BrowserSection) -> some View {
        Button { open(target) } label: {
            Label(title, systemImage: symbol).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }.padding(.horizontal, 22)
    }

    private func drawerHeader(_ title: String, source: Bool) -> some View {
        GeometryReader { geometry in
            HStack {
                Text(title).font(.headline)
                Spacer()
                Image(systemName: source ? "chevron.left" : "chevron.right").accessibilityHidden(true)
                Button { closeDrawers() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                    .accessibilityLabel("Close \(title.lowercased())")
            }
            .padding(.leading, 14).contentShape(Rectangle())
            .simultaneousGesture(horizontalDrag(changed: { translation in
                if source { layout.dragCategories(translation: translation) }
                else { layout.dragDetail(translation: translation) }
            }, ended: { translation, velocity in
                if source { _ = layout.endCategories(translation: translation, velocity: velocity, width: geometry.size.width) }
                else { _ = layout.endDetail(translation: translation, velocity: velocity, width: geometry.size.width) }
            }))
        }.frame(height: 44)
        .background(PerformancePalette.frame)
        .accessibilityAction(named: "Close \(title.lowercased())") { closeDrawers() }
    }

    private func closeDrawers() {
        let wasSource = !layout.categoriesHidden
        layout.hideDrawers()
        if wasSource { sourcesFocused = true } else { detailsFocused = true }
    }

    private func open(_ target: BrowserSection) {
        query = ""
        layout.selectTab(.songs)
        section = target
        if target == .songs { panes.select(.songs) }
        if target == .playlists { panes.select(.playlists) }
        sourcesFocused = true
    }

    private func createEmptyPlaylist() {
        let name = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var changed = playlists
        do { try changed.add(trackIDs: [], to: nil, name: name); model.persistCollectionPlaylists(changed); playlists = changed }
        catch { model.status = error.localizedDescription }
        playlistName = ""
    }

    private func select(category: CollectionCategory) {
        query = ""
        layout.selectTab(.songs)
        section = category == .playlists ? .playlists : .songs
        panes.select(category)
        if sort == nil { sort = .title }
        sourcesFocused = true
    }

    fileprivate var categoryColumn: some View {
        VStack(spacing: 0) {
            ForEach(CollectionCategory.allCases, id: \.self) { item in
                Button { select(category: item) } label: {
                    Text(item.rawValue).font(.body.weight(.semibold))
                        .foregroundStyle(PerformancePalette.text)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 22).frame(height: 66)
                        .background(category == item ? selectedTeal : Color.clear)
                        .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.5)).frame(height: 1) }
                }.accessibilityAddTraits(category == item ? .isSelected : [])
            }
        }.background(PerformancePalette.frame.opacity(0.6))
    }

    fileprivate var listColumn: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if !hasSearchQuery && panes.depth > 0 {
                    Button { panes.back() } label: {
                        Label(category.rawValue, systemImage: "chevron.left").frame(minHeight: 44)
                    }.foregroundStyle(deckBlue)
                } else {
                    Text(hasSearchQuery ? "All songs" : category.rawValue).font(.subheadline.weight(.semibold))
                }
                Spacer(minLength: 0)
                Menu {
                    if category == .playlists && !hasSearchQuery { Button("Playlist order") { sort = nil } }
                    ForEach(CollectionSort.allCases, id: \.self) { item in
                        Button { sort = item } label: {
                            if displayedSort == item { Label(item.rawValue, systemImage: "checkmark") }
                            else { Text(item.rawValue) }
                        }
                    }
                } label: {
                    Label(displayedSort?.rawValue ?? "Playlist order", systemImage: "arrow.up.arrow.down")
                        .font(.subheadline).frame(minHeight: 44)
                }.accessibilityLabel("Sort songs, \(displayedSort?.rawValue ?? "playlist order")")
                if selecting {
                    Button("Add to Playlist") { adding = true }.disabled(selection.isEmpty).frame(minHeight: 44)
                }
            }.padding(.horizontal, 12).background(PerformancePalette.panel)
                .contentShape(Rectangle())
                .simultaneousGesture(horizontalDrag(changed: { translation in
                    guard !hasSearchQuery else { return }
                    panes.dragChanged(translation: translation)
                }, ended: { translation, velocity in
                    guard !hasSearchQuery else { return }
                    _ = panes.dragEnded(translation: translation, velocity: velocity, width: browserWidth)
                }))
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    let drilled = !hasSearchQuery && panes.depth > 0
                    rootPane
                        .offset(x: drilled && !reduceMotion ? -geometry.size.width * 0.3 + panes.dragOffset * 0.3 : 0)
                        .allowsHitTesting(!drilled).accessibilityHidden(drilled)
                    if drilled {
                        songPane
                            .background(PerformancePalette.stage)
                            .shadow(color: .black.opacity(0.6), radius: 8, x: -4)
                            .offset(x: panes.dragOffset)
                            .transition(reduceMotion ? .identity : .move(edge: .trailing))

                    }
                }.frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading).clipped()
            }
            if let progress = model.analysisProgress, progress.message == nil, progress.done < progress.total {
                Text("Analysing: \(progress.done)/\(progress.total)").font(.system(size: 14).monospacedDigit())
                    .foregroundStyle(PerformancePalette.secondaryText).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22).frame(height: 36).background(PerformancePalette.panel)
            }
        }
    }
    @ViewBuilder fileprivate var rootPane: some View {
        if hasSearchQuery {
            songPane
        } else if category == .songs { songPane }
        else {
            LibraryGroupList(title: category.rawValue, source: groupSource, selectedID: group, includesAll: false,
                             loading: groupSourceLoading, counts: category == .playlists ? playlistCounts : [:]) { chosen in
                guard let chosen else { return }
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { panes.open(group: chosen.id) }
                if category == .playlists { sort = nil }
            }.padding(.horizontal, 10).padding(.top, 8)
        }
    }

    /// Song counts for Music library and collection playlists.
    fileprivate var playlistCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for playlist in model.musicLibraryCatalog?.playlists ?? [] { counts[playlist.id] = playlist.itemIDs.count }
        return counts
    }

    @ViewBuilder fileprivate var songPane: some View {
        if entryCount == 0 {
            VStack { Spacer(); Text(searching ? "Searching…" : hasSearchQuery ? "No matching songs." : "No songs available.")
                .font(.system(size: 13)).foregroundStyle(.secondary); Spacer() }.frame(maxWidth: .infinity)
        } else if snapshotProjection != nil {
            // ImageRenderer does not draw scroll views or lazy rows; snapshots list their few rows directly.
            VStack(spacing:0) { ForEach(visibleEntries(in:0..<entryCount)) { songRow($0).padding(.bottom,1) }; Spacer(minLength:0) }
        } else {
            // LazyVStack renders each row as it scrolls into view. The earlier manual window
            // depended on scroll-offset preferences, which iPadOS 17 did not deliver while scrolling.
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(spacing:0) {
                        Color.clear.frame(height:0).id("librarySongsTop").accessibilityHidden(true)
                        ForEach(LibraryBrowserRows(count:entryCount).indices,id:\.self) { index in
                            if let entry=visibleEntries(in:index..<(index+1)).first {
                                songRow(entry).padding(.bottom,1).id(entry.id)
                            } else {
                                Color.clear.frame(height:LibraryBrowserRowWindow.rowHeight)
                            }
                        }
                    }
                }
                .onChange(of:projectionToken) { _,_ in reader.scrollTo("librarySongsTop",anchor:.top) }
            }
        }
    }

    fileprivate var detailPane: some View {
        VStack(spacing: 0) {
            drawerHeader("Track details", source: false)
            ScrollView {
            HStack(alignment: .top, spacing: 14) {
                let entry = currentSelection
                DeckArtwork(source: entry.flatMap { ArtworkSource.track($0.track, item: $0.nativeItem, media: model.store.mediaDirectory) }, placeholderSize: 40)
                    .frame(width: 112, height: 112).background(PerformancePalette.sunken).clipShape(RoundedRectangle(cornerRadius: 3))
                    .overlay { TrackHeadphoneIndicator(model:model,trackID:entry?.track?.id) }
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(entry?.title ?? "Choose a song").font(.system(size: 18, weight: .bold)).lineLimit(2).minimumScaleFactor(0.8)
                        if entry?.isMix == true { MixBadge(size: 14) }
                    }.foregroundStyle(PerformancePalette.text)
                    Text(entry?.artist ?? "").font(.system(size: 17)).foregroundStyle(PerformancePalette.secondaryText).lineLimit(1)
                    let comment = [entry?.album, entry?.genre ?? nil].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                    if !comment.isEmpty { Text(comment).font(.system(size: 15)).foregroundStyle(PerformancePalette.secondaryText.opacity(0.8)).lineLimit(1) }
                    if let duration = entry?.nativeItem?.duration ?? entry?.track?.analysis.duration {
                        Text(String(format: "%d:%02d", Int(duration) / 60, Int(duration) % 60)).font(.system(size: 15).monospacedDigit())
                            .foregroundStyle(PerformancePalette.secondaryText)
                    }
                    Spacer(minLength: 4)
                    Button {
                        guard let entry else { return }
                        model.enqueue(entry.id)
                    } label: {
                        Image(systemName: "text.badge.plus").font(.system(size: 20)).frame(width: 48, height: 44).bevelPanel(cornerRadius: 4)
                            .foregroundStyle(entry.map { model.queuedIDs.contains($0.id) } == true ? deckBlue : PerformancePalette.text)
                    }.disabled(entry == nil).accessibilityLabel("Add to prep list")
                }
                Spacer(minLength: 0)
                LoadSlider(tall: true) { deck in if let entry { model.loadLibraryEntry(entry, deck: deck) } }
                    .disabled(entry?.canLoad != true)
            }.padding(14).frame(height: TallLoadSliderMetrics.height + 8 + 28)
            }
        }
    }

    fileprivate var suggestionsPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendationDestination.map { "Suggestions for \($0.rawValue.uppercased())" } ?? "Suggestions")
                        .font(.headline)
                    if let seed = recommendationSeed {
                        Text("Based on \(recommendationDeck.map { "\($0.rawValue.uppercased()): " } ?? "")\(seed.title)")
                            .font(.subheadline).foregroundStyle(PerformancePalette.secondaryText).lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                Button { captureRecommendationReference() } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
                }.accessibilityLabel("Update suggestions from the current reference track")
            }.padding(.horizontal, 12).padding(.vertical, 6).background(PerformancePalette.panel)
            ScrollView {
                LazyVStack(spacing: 0) {
                    if recommendations.isEmpty {
                        Text(recommendationSeed == nil ? "Load or select a reference song, then update suggestions." : "No matching tracks yet.")
                            .font(.subheadline).foregroundStyle(.secondary).padding(24)
                    } else if !recommendations.contains(where: { matchesSearch($0.entry, query: suggestionQuery) }) {
                        Text("No suggestions match this search.").font(.subheadline).foregroundStyle(.secondary).padding(24)
                    } else {
                        ForEach(recommendations.filter { matchesSearch($0.entry, query: suggestionQuery) }) { match in
                            songRow(match.entry, keyOK: match.keyCompatible, tempoOK: match.tempoCompatible)
                        }
                    }
                }
            }
        }
    }

    fileprivate var prepPane: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if model.queuedIDs.isEmpty {
                    Text("Select a song and add it to the prep list.").font(.subheadline).foregroundStyle(.secondary).padding(24)
                } else if !prepQuery.isEmpty && !queuedEntries.contains(where: { matchesSearch($0, query: prepQuery) }) {
                    Text("No prep songs match this search.").font(.subheadline).foregroundStyle(.secondary).padding(24)
                }
                ForEach(queuedEntries.filter { matchesSearch($0, query: prepQuery) }, id: \.id) { entry in
                    songRow(entry).contextMenu { Button("Remove from prep list", role: .destructive) { model.dequeue(entry.id) } }
                }
                ForEach(unavailableQueuedIDs, id: \.self) { queuedID in
                    HStack {
                        Text("Track unavailable in library").font(.subheadline)
                        Spacer()
                        Button("Remove") { model.dequeue(queuedID) }.frame(minHeight: 44)
                            .accessibilityLabel("Remove unavailable track from prep list")
                    }.padding(.horizontal, 12)
                }
            }
        }
    }

    private func matchesSearch(_ entry: LibraryBrowserEntry, query: String) -> Bool {
        query.split(whereSeparator: \.isWhitespace).allSatisfy { word in
            [entry.title, entry.artist, entry.album, entry.genre ?? ""].contains { $0.localizedStandardContains(String(word)) }
        }
    }

    fileprivate var selectedSongShelf: some View {
        Group {
            if let entry = currentSelection {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        selectedSongTitle(entry).frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)
                        selectedSongActions(entry)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        selectedSongTitle(entry)
                        selectedSongActions(entry).frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }.padding(.horizontal, 12).padding(.vertical, 6)
            } else {
                Text("Select a song to load A or B").font(.subheadline).foregroundStyle(PerformancePalette.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }.background(PerformancePalette.panel)
            .overlay(alignment: .top) { Divider() }
    }

    private func selectedSongTitle(_ entry: LibraryBrowserEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.title).font(.subheadline.weight(.semibold)).lineLimit(1)
            Text(entry.artist).font(.caption).foregroundStyle(PerformancePalette.secondaryText).lineLimit(1)
        }
    }

    private func selectedSongActions(_ entry: LibraryBrowserEntry) -> some View {
        HStack(spacing: 8) {
            Button { model.enqueue(entry.id) } label: {
                Image(systemName: "text.badge.plus").frame(width: 44, height: 44)
            }.accessibilityLabel("Add \(entry.title) to prep list")
            Button { layout.showDetail() } label: {
                Image(systemName: "info.circle").frame(width: 44, height: 44)
            }.accessibilityLabel("Details for \(entry.title)").accessibilityFocused($detailsFocused)
            ForEach(DeckID.allCases, id: \.self) { deck in
                Button { model.loadLibraryEntry(entry, deck: deck) } label: {
                    Text("Load \(deck.rawValue.uppercased())").font(.subheadline.weight(.bold))
                        .padding(.horizontal, 12).frame(minWidth: 76, minHeight: 44)
                        .bevelPanel(cornerRadius: 4)
                }.disabled(!entry.canLoad).accessibilityLabel("Load \(entry.title) on deck \(deck.rawValue.uppercased())")
            }
            LoadSlider { deck in model.loadLibraryEntry(entry, deck: deck) }.disabled(!entry.canLoad)
        }
    }

    private func handleBrowserPresentation() {
        if let destination = model.suggestionDestination {
            captureRecommendationReference(destination: destination)
            layout.selectTab(.suggestions)
        } else {
            layout.selectTab(.songs)
        }
    }

    private func captureRecommendationReference(destination: DeckID? = nil) {
        let destination = destination ?? recommendationDestination
        let deck = model.recommendationSeedDeck(destination: destination)
        recommendationDeck = deck
        recommendationDestination = destination ?? deck.map { $0 == .a ? .b : .a }
        recommendationSeed = deck.flatMap { model.recommendationSeed(deck: $0) } ?? currentSelection
        recommendationRefresh = UUID()
    }

    fileprivate var queuedEntries: [LibraryBrowserEntry] {
        guard let projection else { return [] }
        var byID: [String: LibraryBrowserEntry] = [:]
        let wanted = Set(model.queuedIDs)
        for entry in projection.allEntries + projection.entries where wanted.contains(entry.id) { byID[entry.id] = entry }
        return model.queuedIDs.compactMap { byID[$0] }
    }
    private var unavailableQueuedIDs: [String] {
        guard projection != nil else { return [] }
        let availableIDs = Set(queuedEntries.map(\.id))
        return model.queuedIDs.filter { !availableIDs.contains($0) }
    }
    /// Selection does not change the reference. Loading or explicit updates refresh the result list.
    fileprivate var recommendationKey: String {
        let decks = DeckID.allCases.map { model.loaded[$0] ?? "-" }.joined(separator: ",")
        return "\(recommendationSeed?.id ?? "-")|\(recommendationRefresh)|\(decks)|\(projectionToken)|\(collectionVersion)|\(model.browserHintsVersion)"
    }
    fileprivate func refreshRecommendations() async {
        guard let seed = recommendationSeed, let entries = projection?.allEntries else { recommendations = []; return }
        let excluded = Set(model.loaded.values)
        let matches = await Task.detached(priority: .utility) { BrowserRecommendations.matches(for: seed, in: entries, excluding: excluded) }.value
        guard !Task.isCancelled else { return }
        recommendations = matches
    }

    /// The tapped row, or the model's selection when the browser opens with one already chosen.
    fileprivate var currentSelection: LibraryBrowserEntry? {
        if let selectedEntry, selectedEntry.id == model.selectedTrackID { return selectedEntry }
        guard let id = model.selectedTrackID else { return nil }
        if let snapshotProjection { return snapshotProjection.tracks.first { $0.id == id }.map { LibraryBrowserEntry(track: $0) } }
        return projection?.allEntries.first { $0.id == id }
    }

    fileprivate var settingsPanel: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Library").font(.headline).padding(.bottom, 4)
                Button { Task { await model.openNativeMusicLibrary() } } label: { Label("Refresh Music library", systemImage: "arrow.clockwise") }
                    .disabled(model.musicLibraryRefreshing || model.importing)
                Button(action: importAudio) { Label("Import audio files", systemImage: "folder") }
                Button(action: linkCollection) { Label("Link DJ collection file", systemImage: "link") }
                Text("A linked collection is read at every launch and imported again when it changes.")
                    .font(.caption).foregroundStyle(.secondary).frame(width: 260, alignment: .leading)
                Spacer()
            }.padding(24).frame(width: 320)
            Divider()
            ScrollView { PlaybackSettings(model:model).pickerStyle(.inline).padding(24) }
        }.background(PerformancePalette.panel)
    }
}


private struct SnapshotCollectionProjectionKey: EnvironmentKey {
    static let defaultValue: CollectionProjection? = nil
}
extension EnvironmentValues {
    var snapshotCollectionProjection: CollectionProjection? {
        get { self[SnapshotCollectionProjectionKey.self] }
        set { self[SnapshotCollectionProjectionKey.self] = newValue }
    }
}

