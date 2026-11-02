import AVFoundation
import SwiftUI
import TDJCore

enum BrowserSection: CaseIterable { case songs, playlists, recordings, history, settings }

private let rowTeal = Color(red: 0.17, green: 0.45, blue: 0.5)

private struct SectionRow: View {
    let symbol: String
    let title: String
    var selected = false
    var chevron = false
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 17)).foregroundStyle(PerformancePalette.secondaryText).frame(width: 28)
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(PerformancePalette.text).lineLimit(1)
            Spacer()
            if chevron { Image(systemName: "chevron.right").foregroundStyle(PerformancePalette.secondaryText) }
        }.padding(.horizontal, 16).frame(height: 52)
            .background(selected ? rowTeal : Color.white.opacity(0.02))
            .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.55)).frame(height: 1) }
            .contentShape(Rectangle())
    }
}

/// Saved sets named by date. The pane shows length, share, LOAD A/B and the set's tracklist.
struct RecordingsBrowser: View {
    @Bindable var model: ReplicaModel
    @State private var selected: URL?
    @State private var length: Double?
    @State private var lines: [RecordingTracklist.Line] = []
    var body: some View {
        HStack(spacing: 0) {
            ScrollView { LazyVStack(spacing: 0) {
                if model.recordings.isEmpty {
                    Text(model.recordingsRefreshing ? "Reading recordings…" : "No saved recordings").foregroundStyle(.secondary).padding(24)
                }
                ForEach(model.recordings, id: \.self) { url in
                    Button { selected = url } label: { SectionRow(symbol: "recordingtape", title: Self.title(url), selected: selected == url) }
                }
            } }.frame(maxWidth: .infinity).background(PerformancePalette.frame.opacity(0.6))
            VStack(alignment: .leading, spacing: 0) {
                if let url = selected {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "recordingtape").font(.system(size: 54)).foregroundStyle(PerformancePalette.secondaryText)
                            .frame(width: 120, height: 120).bevelPanel(cornerRadius: 3, sunken: true)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Self.title(url)).font(.system(size: 18, weight: .bold)).lineLimit(2)
                            Text(length.map { String(format: "%d:%02d", Int($0) / 60, Int($0) % 60) } ?? "—")
                                .foregroundStyle(PerformancePalette.secondaryText).monospacedDigit()
                            ShareLink(item: url) { Image(systemName: "square.and.arrow.up").frame(width: 48, height: 38).bevelPanel(cornerRadius: 4) }
                                .accessibilityLabel("Share recording")
                        }
                        Spacer(minLength: 0)
                        LoadSlider(tall: true) { deck in Task { await model.loadRecording(url, deck: deck) } }
                            .disabled(model.importing)
                    }.padding(14).frame(height: 190)
                    Text("Featured Tracks").font(.system(size: 18, weight: .bold)).padding(.horizontal, 14).frame(height: 44)
                    ScrollView { LazyVStack(alignment: .leading, spacing: 0) {
                        if lines.isEmpty { Text("No tracklist was saved with this recording.").foregroundStyle(.secondary).padding(14) }
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(line.title).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                                    Text(line.artist).font(.system(size: 14)).foregroundStyle(PerformancePalette.secondaryText).lineLimit(1)
                                }
                                Spacer()
                                Text(String(format: "%d:%02d", line.seconds / 60, line.seconds % 60)).monospacedDigit()
                                    .foregroundStyle(PerformancePalette.secondaryText)
                            }.padding(.horizontal, 14).frame(height: 52)
                        }
                    } }
                } else {
                    Text("Choose a recording").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }.frame(width: 440).background(PerformancePalette.panel).foregroundStyle(PerformancePalette.text)
        }
        .task { model.refreshRecordings() }
        .task(id: selected) {
            length = nil; lines = []
            guard let url = selected else { return }
            let tracklist = model.recordingTracklist(for: url)
            let (seconds, text) = await Task.detached(priority: .utility) { () -> (Double?, String) in
                let file = try? AVAudioFile(forReading: url)
                let seconds = file.map { Double($0.length) / $0.processingFormat.sampleRate }
                return (seconds, tracklist.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "")
            }.value
            length = seconds; lines = RecordingTracklist.parse(text)
        }
    }
    static func title(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.creationDateKey])
        guard let date = values?.creationDate else { return url.deletingPathExtension().lastPathComponent }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide).year().hour().minute())
    }
}

/// Play history: the newest session on top, earlier sessions in month folders.
struct HistoryBrowser: View {
    @Bindable var model: ReplicaModel
    @State private var selected: HistorySession?
    @State private var openMonth: String?
    var body: some View {
        let layout = HistorySessions.layout(HistorySessions.sessions(from: model.library.events))
        HStack(spacing: 0) {
            ScrollView { LazyVStack(spacing: 0) {
                if layout.latest == nil { Text("Sessions appear here after you load tracks.").foregroundStyle(.secondary).padding(24) }
                if let latest = layout.latest {
                    Button { selected = latest } label: { SectionRow(symbol: "music.note.list", title: Self.title(latest), selected: selected?.id == latest.id) }
                }
                ForEach(layout.months) { month in
                    Button { openMonth = openMonth == month.id ? nil : month.id } label: {
                        SectionRow(symbol: "folder.fill", title: month.title, chevron: true)
                    }.accessibilityLabel("\(month.title), \(month.sessions.count) sessions")
                    if openMonth == month.id {
                        ForEach(month.sessions) { session in
                            Button { selected = session } label: { SectionRow(symbol: "music.note.list", title: Self.title(session), selected: selected?.id == session.id).padding(.leading, 24) }
                        }
                    }
                }
            } }.frame(maxWidth: .infinity).background(PerformancePalette.frame.opacity(0.6))
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button { for id in selected?.trackIDs ?? [] { model.enqueue(id) } } label: {
                        Image(systemName: "text.badge.plus").frame(width: 52, height: 36).bevelPanel(cornerRadius: 4)
                    }.disabled(selected == nil).accessibilityLabel("Add session to prep list")
                }.padding(.horizontal, 14).frame(height: 52)
                ScrollView { LazyVStack(spacing: 0) {
                    ForEach(selected?.trackIDs ?? [], id: \.self) { id in
                        if let track = model.library.tracks.first(where: { $0.id == id }) {
                            HStack(spacing: 10) {
                                DeckArtwork(source: ArtworkSource.track(track, media: model.store.mediaDirectory), placeholderSize: 12)
                                    .frame(width: 44, height: 44).background(PerformancePalette.sunken).clipShape(RoundedRectangle(cornerRadius: 3))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                                    Text(track.artist).font(.system(size: 14)).foregroundStyle(PerformancePalette.secondaryText).lineLimit(1)
                                }
                                Spacer()
                                Text(track.key?.openKeyName ?? "—").foregroundStyle(KeyColour.colour(track.key))
                                Text(track.bpm.map { String(format: "%.1f", $0) } ?? "—").foregroundStyle(PerformancePalette.secondaryText)
                            }.font(.system(size: 14).monospacedDigit()).padding(.horizontal, 14).frame(height: 56)
                        }
                    }
                } }
            }.frame(width: 440).background(PerformancePalette.panel).foregroundStyle(PerformancePalette.text)
        }
    }
    static func title(_ session: HistorySession) -> String {
        session.started.formatted(.dateTime.weekday(.wide).day().month(.wide).year().hour().minute())
    }
}

/// Settings in two columns: a category list and its options.
struct SettingsBrowser: View {
    enum Page: String, CaseIterable { case playback = "Playback", extras = "Extra Controls", library = "Library", notifications = "Notifications",
                                      browser = "Browser", controllers = "Controllers", mixcloud = "Mixcloud", features = "Features", about = "About" }
    @Bindable var model: ReplicaModel
    var importAudio: () -> Void = {}
    var linkCollection: () -> Void = {}
    @State private var page = Page.playback
    @AppStorage(BrowserSettings.notificationCenterKey) private var notificationCenter = true
    @AppStorage(BrowserSettings.onlyLoadToOffAirDecksKey) private var offAir = false
    @AppStorage(BrowserSettings.fluxModeKey) private var fluxMode = true
    @AppStorage(BrowserSettings.superSlicerKey) private var superSlicer = true
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(Page.allCases, id: \.self) { item in
                    Button { page = item } label: {
                        Text(item.rawValue).font(.system(size: 16, weight: .semibold)).foregroundStyle(PerformancePalette.text)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).frame(height: 46)
                            .background(page == item ? rowTeal : Color.clear)
                    }
                }
                Spacer()
            }.frame(width: 300).background(PerformancePalette.frame.opacity(0.6))
            ScrollView { VStack(alignment: .leading, spacing: 18) { content }.padding(30).frame(maxWidth: 520, alignment: .leading) }
                .frame(maxWidth: .infinity).background(PerformancePalette.panel)
        }.foregroundStyle(PerformancePalette.text)
    }
    @ViewBuilder private var content: some View {
        switch page {
        case .playback:
            RecoverySettingsView(model: model)
            choiceGroup("Default Loop Size", [4.0, 8, 16, 32].map { ("\(Int($0)) Beats", $0) }, selected: model.performance.defaultLoopBeats) {
                model.performance.defaultLoopBeats = $0; model.savePerformance()
            }
            choiceGroup("Quantize Size", [("1/4 Beat", 0.25), ("1/2 Beat", 0.5), ("1 Beat", 1.0), ("1 Bar", 4.0)], selected: model.performance.quantize) {
                model.performance.quantize = $0; model.savePerformance()
            }
            Toggle("Slicer Quantize", isOn: Binding(get: { model.performance.slicerQuantize }, set: { model.performance.slicerQuantize = $0; model.savePerformance() }))
            Toggle("Freeze on Load", isOn: Binding(get: { model.performance.freezeOnLoad }, set: { model.performance.freezeOnLoad = $0; model.savePerformance() }))
        case .extras:
            Text("Controls from the later app. Each is off by default.").foregroundStyle(.secondary)
            PlaybackSettings(model: model).extrasOnly()
        case .library:
            Button { Task { await model.openNativeMusicLibrary() } } label: { Label("Refresh Music library", systemImage: "arrow.clockwise") }
            Button(action: importAudio) { Label("Import audio files", systemImage: "folder") }
            Button(action: linkCollection) { Label("Link DJ collection file", systemImage: "link") }
            Text("A linked collection is read at every launch and imported again when it changes.").font(.caption).foregroundStyle(.secondary)
        case .notifications:
            Toggle("Notification Center", isOn: $notificationCenter)
            Button("Reset Undiscovered Features") { model.helpVisible = true }
        case .browser:
            Toggle("Only load to off-air Decks", isOn: $offAir)
            Text("A playing deck refuses new tracks while this is on.").font(.caption).foregroundStyle(.secondary)
        case .controllers:
            ControllerSettingsView(model: model)
        case .mixcloud:
            Text("Mixcloud upload").font(.headline)
            Text("Recordings share from the Recordings section with the system share sheet, which includes any installed upload app. This build has no Mixcloud sign-in.")
                .foregroundStyle(.secondary)
        case .features:
            Toggle("Flux Mode", isOn: $fluxMode)
            Toggle("SuperSlicer", isOn: $superSlicer)
        case .about:
            GenErikBrandLockup()
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))")
                .foregroundStyle(.secondary)
            Text("An independent performance app. Third-party notices ship with the app.").foregroundStyle(.secondary)
        }
    }
    private func choiceGroup<Value: Equatable>(_ title: String, _ options: [(String, Value)], selected: Value, choose: @escaping (Value) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(PerformancePalette.secondaryText)
            VStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    Button { choose(option.1) } label: {
                        HStack {
                            Text(option.0).foregroundStyle(option.1 == selected ? PerformancePalette.cyan : PerformancePalette.text)
                            Spacer()
                            if option.1 == selected { Image(systemName: "checkmark").foregroundStyle(PerformancePalette.cyan) }
                        }.padding(.horizontal, 14).frame(height: 44).contentShape(Rectangle())
                    }.accessibilityAddTraits(option.1 == selected ? .isSelected : [])
                    Divider()
                }
            }.bevelPanel(cornerRadius: 6, sunken: true)
        }
    }
}
