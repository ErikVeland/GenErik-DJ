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
    private var hasSearchQuery: Bool { query.contains { !$0.isWhitespace } }
    @State private var sort: CollectionSort? = .title
    private var displayedSort: CollectionSort? { hasSearchQuery ? sort ?? .title : sort }
    @State private var panes = BrowserPaneStack()
    private var category: CollectionCategory { panes.category }
    private var group: String? { panes.group }
    @State private var selectedEntry: LibraryBrowserEntry?
    @State private var recommendations: [BrowserRecommendations.Match] = []
    @State private var recommendationSeed: LibraryBrowserEntry?
    @State private var layout = BrowserLayoutState(categoriesHidden: true)
    @State private var section = BrowserSection.songs
    private var displayedSection: BrowserSection { hasSearchQuery ? .songs : section }
    private var showingSuggestions: Bool { !hasSearchQuery && model.suggestionDestination != nil }
    @State private var newPlaylistPresented = false
    @State private var detailTab = DetailTab.match
    enum DetailTab { case match, queue }
    private var displayedDetailTab: DetailTab { model.queuedIDs.isEmpty ? .match : detailTab }
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
    @State private var dismissOffset: CGFloat = 0
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
    var body: some View {
        content.offset(y: dismissOffset)
    }
    /// Global coordinates keep the pull 1:1 while the pane itself moves under the finger.
    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in dismissOffset = PaneDismissGesture.offset(translation: value.translation.height) }
            .onEnded { value in
                if PaneDismissGesture.dismisses(translation: value.translation.height, velocity: value.velocity.height) {
                    model.browserVisible = false
                    dismissOffset = 0
                } else {
                    withAnimation(.spring(duration: 0.25)) { dismissOffset = 0 }
                }
            }
    }
    private var content: some View {
        VStack(spacing: 0) {
            searchBar
            GeometryReader { geometry in
              let available = max(0, geometry.size.width - 64)
              let categoryWidth = min(180, available * 0.3)
              let categoryVisible = hasSearchQuery ? 0 : max(0, min(categoryWidth, layout.categoriesHidden ? layout.categoryOffset : categoryWidth + layout.categoryOffset))
              let remaining = max(0, available - categoryVisible)
              let detailWidth = remaining / 2
              let detailVisible = max(0, min(detailWidth, layout.detailHidden ? -layout.detailOffset : detailWidth - layout.detailOffset))
              HStack(spacing: 0) {
                iconRail.frame(width: 64)
                if displayedSection == .settings {
                    SettingsBrowser(model: model, importAudio: importAudio, linkCollection: linkCollection)
                } else if displayedSection == .recordings {
                    RecordingsBrowser(model: model)
                } else if displayedSection == .history {
                    HistoryBrowser(model: model)
                } else if displayedSection == .playlists {
                    playlistColumn.frame(width: available / 2).clipped()
                    listColumn.frame(width: available / 2).clipped()
                } else {
                    if !hasSearchQuery && (!layout.categoriesHidden || layout.categoryOffset > 0) {
                        categoryColumn.frame(width: categoryWidth)
                            .offset(x: layout.categoriesHidden ? -categoryWidth + categoryVisible : categoryVisible - categoryWidth)
                            .frame(width: categoryVisible, alignment: .leading)
                            .clipped()
                            .simultaneousGesture(horizontalDrag(changed: { layout.dragCategories(translation: $0) },
                                ended: { t, v in withAnimation(.smooth(duration: 0.22)) { _ = layout.endCategories(translation: t, velocity: v, width: categoryWidth) } }))
                    }
                    listColumn.frame(width: max(0, remaining - detailVisible)).clipped()
                        .overlay(alignment: .leading) {
                            if !hasSearchQuery && layout.categoriesHidden {
                                Color.clear.frame(width: 18).contentShape(Rectangle())
                                    .gesture(horizontalDrag(changed: { layout.dragCategories(translation: $0) },
                                        ended: { t, v in withAnimation(.smooth(duration: 0.22)) { _ = layout.endCategories(translation: t, velocity: v, width: categoryWidth) } }))
                            }
                        }
                        .overlay(alignment: .trailing) {
                            if layout.detailHidden {
                                Color.clear.frame(width: 18).contentShape(Rectangle())
                                    .gesture(horizontalDrag(changed: { layout.dragDetail(translation: $0) },
                                        ended: { t, v in withAnimation(.smooth(duration: 0.22)) { _ = layout.endDetail(translation: t, velocity: v, width: detailWidth) } }))
                            }
                        }
                    if !layout.detailHidden || layout.detailOffset < 0 {
                        detailPane.frame(width: detailWidth)
                            .offset(x: detailWidth - detailVisible)
                            .frame(width: detailVisible, alignment: .leading)
                            .clipped()
                            .overlay(alignment: .trailing) {
                                Color.clear.frame(width: 18).contentShape(Rectangle())
                                    .gesture(horizontalDrag(changed: { layout.dragDetail(translation: $0) },
                                        ended: { t, v in withAnimation(.smooth(duration: 0.22)) { _ = layout.endDetail(translation: t, velocity: v, width: detailWidth) } }))
                                    .accessibilityLabel("Swipe to hide recommendations")
                            }
                    }
                }
              }.frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading).clipped()
            }
        }.background(PerformancePalette.stage)
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
    private func songRow(_ entry:LibraryBrowserEntry) -> some View {
        HStack(spacing: 12) {
            if selecting {
                Button {
                    if !selection.insert(entry.membershipID).inserted { selection.remove(entry.membershipID) }
                } label: { Image(systemName:selection.contains(entry.membershipID) ? "checkmark.circle.fill":"circle") }
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
                            Text(entry.title).font(.system(size:17,weight:.semibold)).foregroundStyle(PerformancePalette.text).lineLimit(1)
                            if entry.isMix { MixBadge(size: 12) }
                        }
                        Text(entry.artist).font(.system(size:15)).foregroundStyle(PerformancePalette.secondaryText).lineLimit(1)
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
        }.padding(.horizontal,12).frame(height:57)
            .background(model.selectedTrackID == entry.id ? selectedTeal.opacity(0.45) : Color.white.opacity(0.02))
            .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.6)).frame(height: 1) }
    }
    private func select(_ entry: LibraryBrowserEntry) {
        model.selectedTrackID=entry.id
        selectedEntry=entry
        if layout.detailHidden { withAnimation(.smooth(duration: 0.22)) { layout.showDetail() } }
    }
    /// Horizontal-only drag in global space, so the moving pane does not change the finger's reading.
    private func horizontalDrag(changed: @escaping (Double) -> Void, ended: @escaping (Double, Double) -> Void) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                changed(value.translation.width)
            }
            .onEnded { value in ended(value.translation.width, value.velocity.width) }
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
    fileprivate var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(PerformancePalette.secondaryText)
                TextField("", text: $query, prompt: Text("Search full library").foregroundStyle(PerformancePalette.secondaryText))
                    .textFieldStyle(.plain).foregroundStyle(PerformancePalette.text)
                    .accessibilityLabel("Search full library by song, artist, album or genre")
            }.padding(.horizontal, 14).frame(maxWidth: 380).frame(height: 36)
            .background(Capsule().fill(PerformancePalette.sunken)).overlay(Capsule().strokeBorder(Color.black.opacity(0.7)))
            if let destination = model.suggestionDestination {
                Text("\(hasSearchQuery ? "All songs" : "Suggestions") → \(destination.rawValue.uppercased())").foregroundStyle(deckBlue)
                if !hasSearchQuery { Button("Songs") { model.showLibrary() } }
            } else if hasSearchQuery {
                Text("All songs").foregroundStyle(PerformancePalette.secondaryText)
            }
            Spacer()
            if !showingSuggestions {
                Button(selecting ? "Done" : "Edit") { selecting.toggle(); selection=[] }
                if selecting { Button("Add to Playlist") { adding=true }.disabled(selection.isEmpty) }
            }
            Button { model.browserVisible = false } label: { Image(systemName: "chevron.down") }
                .accessibilityLabel("Close songs")
        }
        .font(.system(size: 15, weight: .semibold)).foregroundStyle(PerformancePalette.text)
        .padding(.horizontal, 14).frame(height: 56)
        .background(LinearGradient(colors: [PerformancePalette.frame, PerformancePalette.panel], startPoint: .top, endPoint: .bottom))
        .overlay(alignment: .top) {
            Capsule().fill(Color.white.opacity(0.25)).frame(width: 36, height: 4).padding(.top, 4).allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .gesture(dismissDrag)
        .accessibilityAction(named: "Close songs") { model.browserVisible = false }
    }

    fileprivate var iconRail: some View {
        VStack(spacing: 14) {
            railButton("music.note", "Songs", active: displayedSection == .songs) { open(.songs) }
            railButton("music.note.list", "Playlists", active: displayedSection == .playlists) { open(.playlists) }
            railButton("recordingtape", "Recordings", active: displayedSection == .recordings) { open(.recordings) }
            railButton("clock.fill", "History", active: displayedSection == .history) { open(.history) }
            Spacer()
            railButton("gearshape.fill", "Settings", active: displayedSection == .settings) { open(.settings) }
        }.padding(.vertical, 14).frame(maxHeight: .infinity).background(PerformancePalette.panel)
    }
    private func open(_ target: BrowserSection) {
        query = ""
        if model.suggestionDestination != nil { model.showLibrary() }
        section = target
        if target == .songs { select(category: .songs) }
        if target == .playlists { select(category: .playlists) }
    }
    fileprivate var playlistColumn: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { newPlaylistPresented = true } label: {
                    Image(systemName: "plus").font(.system(size: 17, weight: .semibold)).frame(width: 46, height: 36).bevelPanel(cornerRadius: 4)
                }.accessibilityLabel("New playlist")
            }.padding(.horizontal, 14).frame(height: 56).background(PerformancePalette.panel)
            LibraryGroupList(title: "Playlists", source: groupSource, selectedID: group, includesAll: false,
                             loading: groupSourceLoading, counts: playlistCounts) { chosen in
                guard let chosen else { return }
                panes.open(group: chosen.id); sort = nil
            }.padding(.horizontal, 10).padding(.top, 8)
        }
        .background(PerformancePalette.frame.opacity(0.6))
        .alert("New playlist", isPresented: $newPlaylistPresented) {
            TextField("Name", text: $playlistName)
            Button("Create") { createEmptyPlaylist() }
            Button("Cancel", role: .cancel) { playlistName = "" }
        }
    }
    private func createEmptyPlaylist() {
        let name = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var changed = playlists
        do { try changed.add(trackIDs: [], to: nil, name: name); model.persistCollectionPlaylists(changed); playlists = changed }
        catch { model.status = error.localizedDescription }
        playlistName = ""
    }
    private func railButton(_ symbol: String, _ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 22, weight: .semibold))
                .foregroundStyle(active ? Color.black : PerformancePalette.secondaryText)
                .frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 6).fill(active ? deckBlue : Color.clear))
        }.accessibilityLabel(label)
    }
    private func select(category: CollectionCategory) {
        if model.suggestionDestination != nil { model.showLibrary() }
        withAnimation(.smooth(duration: 0.25)) { panes.select(category) }
        if category == .playlists && sort == nil { } else if sort == nil { sort = .title }
    }

    fileprivate var categoryColumn: some View {
        VStack(spacing: 0) {
            ForEach(CollectionCategory.allCases, id: \.self) { item in
                Button { select(category: item) } label: {
                    Text(item.rawValue).font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(PerformancePalette.text)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 22).frame(height: 66)
                        .background(category == item ? selectedTeal : Color.clear)
                        .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.5)).frame(height: 1) }
                }.accessibilityAddTraits(category == item ? .isSelected : [])
            }
            Spacer()
        }.background(PerformancePalette.frame.opacity(0.6))
    }

    fileprivate var listColumn: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                if !hasSearchQuery && panes.depth > 0 {
                    Button { withAnimation(.smooth(duration: 0.25)) { panes.back() } } label: {
                        Label(category.rawValue, systemImage: "chevron.left").font(.system(size: 15, weight: .semibold))
                    }.foregroundStyle(deckBlue)
                }
                if !hasSearchQuery && category == .playlists {
                    Button { sort = nil } label: {
                        Image(systemName: "music.note.list").font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(sort == nil ? Color.black : PerformancePalette.secondaryText).frame(width: 42, height: 38)
                            .background(RoundedRectangle(cornerRadius: 5).fill(sort == nil ? deckBlue : Color.clear))
                    }.accessibilityLabel("Sort by playlist order")
                }
                sortTab("record.circle", "All", .title)
                sortTab("person.fill", "Artist", .artist)
                sortTab("music.note", "Key", .key)
                sortTab("waveform.path.ecg", "BPM", .bpm)
                Spacer()
                Menu {
                    ForEach(CollectionSort.allCases, id: \.self) { item in
                        Button { sort = item } label: { if displayedSort == item { Label(item.rawValue, systemImage: "checkmark") } else { Text(item.rawValue) } }
                    }
                } label: {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("SORTED BY").font(.system(size: 10, weight: .semibold)).foregroundStyle(PerformancePalette.secondaryText)
                        HStack(spacing: 4) { Text(displayedSort?.rawValue ?? "Playlist order"); Image(systemName: "chevron.down") }
                            .font(.system(size: 15, weight: .medium)).foregroundStyle(PerformancePalette.text)
                    }
                }.accessibilityLabel("Sorted by \(displayedSort?.rawValue ?? "playlist order")")
                if layout.listShowsTempoAndKey {
                    Button(selecting ? "Done" : "Edit") { selecting.toggle(); selection=[] }
                        .font(.system(size: 15, weight: .semibold)).padding(.horizontal, 12).frame(height: 36).bevelPanel(cornerRadius: 4)
                }
            }.padding(.horizontal, 10).frame(height: 56).background(PerformancePalette.panel)
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    let drilled = !hasSearchQuery && panes.depth > 0 && section != .playlists
                    rootPane
                        .offset(x: drilled ? -geometry.size.width * 0.3 + panes.dragOffset * 0.3 : 0)
                        .allowsHitTesting(!drilled)
                    if drilled {
                        songPane
                            .background(PerformancePalette.stage)
                            .shadow(color: .black.opacity(0.6), radius: 8, x: -4)
                            .offset(x: panes.dragOffset)
                            .transition(.move(edge: .trailing))
                            .simultaneousGesture(DragGesture(minimumDistance: 12, coordinateSpace: .global)
                                .onChanged { value in
                                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                                    panes.dragChanged(translation: value.translation.width)
                                }
                                .onEnded { value in
                                    withAnimation(.smooth(duration: 0.22)) {
                                        _ = panes.dragEnded(translation: value.translation.width, velocity: value.velocity.width,
                                                            width: geometry.size.width)
                                    }
                                })
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
    private func sortTab(_ symbol: String, _ label: String, _ value: CollectionSort) -> some View {
        Button { sort = value } label: {
            Image(systemName: symbol).font(.system(size: 20, weight: .semibold))
                .foregroundStyle(displayedSort == value ? Color.black : PerformancePalette.secondaryText)
                .frame(width: 42, height: 38)
                .background(RoundedRectangle(cornerRadius: 5).fill(displayedSort == value ? deckBlue : Color.clear))
        }.accessibilityLabel("Sort by \(label)")
    }

    @ViewBuilder fileprivate var rootPane: some View {
        if hasSearchQuery {
            songPane
        } else if section == .playlists {
            if group == nil { Text("Choose a playlist").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity) }
            else { songPane }
        } else if category == .songs || model.suggestionDestination != nil { songPane }
        else {
            LibraryGroupList(title: category.rawValue, source: groupSource, selectedID: group, includesAll: false,
                             loading: groupSourceLoading, counts: category == .playlists ? playlistCounts : [:]) { chosen in
                guard let chosen else { return }
                withAnimation(.smooth(duration: 0.25)) { panes.open(group: chosen.id) }
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
        if showingSuggestions {
            ScrollView { LazyVStack(spacing: 0) {
                if recommendations.isEmpty {
                    Text(recommendationSeed == nil ? "Load a track on the other deck to see matches." : "No matching tracks yet.")
                        .font(.system(size: 13)).foregroundStyle(.secondary).padding(24)
                }
                ForEach(recommendations) { match in songRow(match.entry).padding(.bottom, 1) }
            } }
        } else if !hasSearchQuery, let message = model.suggestionMessage {
            VStack { Spacer(); Text(message).font(.system(size: 13)).foregroundStyle(.secondary).padding(24); Spacer() }.frame(maxWidth: .infinity)
        } else if entryCount == 0 {
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
        VStack(alignment: .leading, spacing: 0) {
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
                        Image(systemName: "text.badge.plus").font(.system(size: 20)).frame(width: 56, height: 40).bevelPanel(cornerRadius: 4)
                            .foregroundStyle(entry.map { model.queuedIDs.contains($0.id) } == true ? deckBlue : PerformancePalette.text)
                    }.disabled(entry == nil).accessibilityLabel("Add to prep list")
                }
                Spacer(minLength: 0)
                LoadSlider(tall: true) { deck in if let entry { model.loadLibraryEntry(entry, deck: deck) } }
                    .disabled(entry?.canLoad != true)
            }.padding(14).frame(height: TallLoadSliderMetrics.height + 8 + 28)
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1).padding(.horizontal, 14)
            HStack(spacing: 8) {
                detailTabButton(recommendationSeed.map { "Rec for \($0.title)" } ?? "Recommendations", .match)
                if !model.queuedIDs.isEmpty { detailTabButton("Prep list \(model.queuedIDs.count)", .queue) }
                Spacer()
                if displayedDetailTab == .match, let seed = recommendationSeed {
                    HStack(spacing: 3) { Image(systemName: "music.note"); Text(seed.key?.openKeyName ?? "—") }.foregroundStyle(KeyColour.colour(seed.key))
                    HStack(spacing: 3) { Image(systemName: "waveform.path.ecg"); Text(seed.bpm.map { String(format: "%.1f", $0) } ?? "—") }
                }
            }.font(.system(size: 15).monospacedDigit()).foregroundStyle(PerformancePalette.secondaryText)
            .padding(.horizontal, 14).frame(height: 50)
            ScrollView {
                LazyVStack(spacing: 0) {
                    if displayedDetailTab == .match {
                        if recommendations.isEmpty {
                            Text(recommendationSeed == nil ? "Load or play a track to see recommendations." : "No matching tracks yet.")
                                .font(.system(size: 13)).foregroundStyle(.secondary).padding(14)
                        }
                        ForEach(recommendations) { match in recommendationRow(match.entry, keyOK: match.keyCompatible, tempoOK: match.tempoCompatible) }
                    } else {
                        ForEach(queuedEntries, id: \.id) { entry in
                            recommendationRow(entry, keyOK: false, tempoOK: false)
                                .contextMenu { Button("Remove from prep list", role: .destructive) { model.dequeue(entry.id) } }
                        }
                        ForEach(unavailableQueuedIDs, id: \.self) { queuedID in
                            HStack {
                                Image(systemName: "exclamationmark.triangle").foregroundStyle(PerformancePalette.secondaryText)
                                Text("Track unavailable in library").font(.system(size: 14)).foregroundStyle(PerformancePalette.secondaryText)
                                Spacer()
                                Button("Remove") { model.dequeue(queuedID) }
                                    .font(.system(size: 14, weight: .semibold))
                                    .accessibilityLabel("Remove unavailable track from prep list")
                            }.padding(.horizontal, 14).frame(height: 56)
                        }
                    }
                }
            }
        }
        .background(PerformancePalette.panel)
        .task(id: recommendationKey) { await refreshRecommendations() }
    }

    private func detailTabButton(_ title: String, _ tab: DetailTab) -> some View {
        Button { detailTab = tab } label: {
            Text(title).font(.system(size: tab == .match ? 18 : 15, weight: .bold))
                .foregroundStyle(displayedDetailTab == tab ? PerformancePalette.text : PerformancePalette.secondaryText)
                .lineLimit(1).truncationMode(.tail)
        }.accessibilityLabel(title)
    }
    private func recommendationRow(_ entry: LibraryBrowserEntry, keyOK: Bool, tempoOK: Bool) -> some View {
        Button { select(entry) } label: {
            HStack(spacing: 10) {
                DeckArtwork(source: ArtworkSource.track(entry.track, item: entry.nativeItem, media: model.store.mediaDirectory), placeholderSize: 12)
                    .frame(width: 44, height: 44).background(PerformancePalette.sunken).clipShape(RoundedRectangle(cornerRadius: 3))
                    .overlay { TrackHeadphoneIndicator(model:model,trackID:entry.track?.id) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(PerformancePalette.text).lineLimit(1)
                    Text(entry.artist).font(.system(size: 14)).foregroundStyle(PerformancePalette.secondaryText).lineLimit(1)
                }
                Spacer()
                HStack(spacing: 2) { Image(systemName: "music.note"); Text(entry.key?.openKeyName ?? "—") }
                    .foregroundStyle(keyOK ? PerformancePalette.syncGreen : KeyColour.colour(entry.key))
                HStack(spacing: 2) { Image(systemName: "waveform.path.ecg"); Text(entry.bpm.map { String(format: "%.1f", $0) } ?? "—") }
                    .foregroundStyle(tempoOK ? PerformancePalette.syncGreen : PerformancePalette.secondaryText)
            }.font(.system(size: 14).monospacedDigit()).padding(.horizontal, 14).frame(height: 56).contentShape(Rectangle())
        }
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
    /// Recomputes when a deck loads or starts playing, the destination changes, or the list or hints change.
    fileprivate var recommendationKey: String {
        let decks = DeckID.allCases.map { "\(model.loaded[$0] ?? "-"):\(model.controlDisplay[$0].phase.active)" }.joined(separator: ",")
        return "\(decks)|\(model.suggestionDestination?.rawValue ?? "-")|\(model.selectedTrackID ?? "")|\(projectionToken)|\(collectionVersion)|\(model.browserHintsVersion)"
    }
    fileprivate func refreshRecommendations() async {
        let seedDeck = model.recommendationSeedDeck(destination: model.suggestionDestination)
        let seed = seedDeck.flatMap { model.recommendationSeed(deck: $0) } ?? (model.suggestionDestination == nil ? currentSelection : nil)
        recommendationSeed = seed
        guard let seed, let entries = projection?.entries else { recommendations = []; return }
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
        return projection?.entries.first { $0.id == id }
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

