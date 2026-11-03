import SwiftUI
import TDJCore

@MainActor
struct MusicLibraryView: View {
    @Bindable var model: ReplicaModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var playlistID: String?
    @State private var selected: Set<String> = []

    @State private var songs: [MusicLibraryItem] = []
    @State private var preparedIDs = Set<String>()
    @State private var selectable = Set<String>()
    @State private var catalogVersion = UUID()
    @State private var searching = true
    private struct Request: Hashable {
        let catalog: UUID
        let revision: Int
        let playlistID: String?
        let search: String
    }
    private var request: Request {
        .init(catalog: catalogVersion, revision: model.library.revision, playlistID: playlistID, search: search)
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("This list shows songs stored on this device.")
                    .font(.subheadline).foregroundStyle(.secondary)
                if let catalog = model.musicLibraryCatalog {
                    Picker("Playlist", selection: $playlistID) {
                        Text("All songs (\(catalog.items.filter(\.isOnDevice).count))").tag(String?.none)
                        ForEach(catalog.playlists) { playlist in
                            Text(playlist.name).tag(Optional(playlist.id))
                        }
                    }
                    TextField("Search title, artist or album", text: $search)
                        .textFieldStyle(.roundedBorder).accessibilityLabel("Search music library")
                }
                if model.musicLibraryRefreshing {
                    ProgressView("Reading your music library…").frame(maxHeight: .infinity)
                } else if let error = model.musicLibraryError {
                    ContentUnavailableView("Music library access", systemImage: "music.note.list",
                        description: Text(error)).frame(maxHeight: .infinity)
                } else if searching && songs.isEmpty {
                    ProgressView("Searching music library…").frame(maxHeight: .infinity)
                } else if songs.isEmpty {
                    ContentUnavailableView("No songs", systemImage: "music.note.list",
                        description: Text("Check the playlist or search. Sync local music in Music, then refresh."))
                        .frame(maxHeight: .infinity)
                } else {
                    List(songs) { item in
                        let prepared = preparedIDs.contains(item.id)
                        Button {
                            if selected.contains(item.id) { selected.remove(item.id) }
                            else { selected.insert(item.id) }
                        } label: {
                            HStack {
                                Image(systemName: prepared ? "checkmark.circle.fill" : selected.contains(item.id) ? "checkmark.circle" : "circle")
                                    .foregroundStyle(prepared ? .green : .primary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title).lineLimit(1)
                                    Text([item.artist, item.album].filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    if let failure = model.musicLibraryFailures[item.id] {
                                        Text(failure).font(.caption).foregroundStyle(.orange)
                                    } else if !item.isOnDevice {
                                        Text(item.availability.message).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if prepared { Text("Added").font(.caption).foregroundStyle(.secondary) }
                            }.contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(prepared || !item.isOnDevice || model.importing)
                        .accessibilityLabel("\(item.title), \(item.artist), \(prepared ? "Added" : item.availability.message)")
                    }
                }
                if !model.musicLibraryProgress.isEmpty {
                    Text(model.musicLibraryProgress).font(.caption).foregroundStyle(.secondary)
                        .accessibilityLabel(model.musicLibraryProgress)
                }
                HStack {
                    Button("Select available") { selected.formUnion(selectable) }
                        .disabled(selectable.isEmpty || model.importing)
                    Button("Clear") { selected = [] }.disabled(selected.isEmpty || model.importing)
                    Spacer()
                    if model.importing {
                        ProgressView().controlSize(.small)
                        if model.musicLibraryPreparing { Button("Stop") { model.cancelMusicLibraryImport() } }
                    } else {
                        Button("Add selected (\(selected.count))") {
                            model.startMusicLibraryImport(selected)
                        }.disabled(selected.isEmpty || model.musicLibraryRefreshing)
                    }
                }
            }
            .padding(16)
            .navigationTitle("Music library")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { model.showLibrary(); dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Refresh") {
                        selected = []; playlistID = nil
                        Task { await model.refreshMusicLibrary() }
                    }.disabled(model.importing || model.musicLibraryRefreshing)
                }
            }
        }
        .frame(minWidth: 600, idealWidth: 760, minHeight: 450, idealHeight: 600)
        .task {
            if model.musicLibraryCatalog == nil { await model.refreshMusicLibrary() }
        }
        .onChange(of: model.musicLibraryCatalogVersion) { _, _ in catalogVersion = UUID() }
        .task(id: request) {
            let current = request
            searching = true
            do {
                let result = try await MusicLibraryProjection.build(catalog: model.musicLibraryCatalog,
                    tracks: model.library.tracks, playlistID: current.playlistID, search: current.search)
                guard !Task.isCancelled, current == request else { return }
                songs = result.songs; preparedIDs = result.preparedIDs
                selectable = result.selectableIDs; searching = false
            } catch is CancellationError { }
            catch { searching = false; model.musicLibraryError = error.localizedDescription }
        }
        .onChange(of: preparedIDs) { _, ids in selected.subtract(ids) }
    }
}
