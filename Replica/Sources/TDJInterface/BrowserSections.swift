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
            Image(systemName: symbol).font(.system(size: 17)).foregroundStyle(PerformancePalette.secondaryText).frame(
                width: 28)
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(PerformancePalette.text).lineLimit(1)
            Spacer()
            if chevron { Image(systemName: "chevron.right").foregroundStyle(PerformancePalette.secondaryText) }
        }.padding(.horizontal, 16).frame(height: 52).background(selected ? rowTeal : Color.white.opacity(0.02)).overlay(
            alignment: .bottom
        ) { Rectangle().fill(Color.black.opacity(0.55)).frame(height: 1) }.contentShape(Rectangle())
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
            ScrollView {
                LazyVStack(spacing: 0) {
                    if model.recordings.isEmpty {
                        Text(model.recordingsRefreshing ? "Reading recordings…" : "No saved recordings")
                            .foregroundStyle(.secondary).padding(24)
                    }
                    ForEach(model.recordings, id: \.self) { url in
                        Button {
                            selected = url
                        } label: {
                            SectionRow(symbol: "recordingtape", title: Self.title(url), selected: selected == url)
                        }
                    }
                }
            }.frame(maxWidth: .infinity).background(PerformancePalette.frame.opacity(0.6))
            VStack(alignment: .leading, spacing: 0) {
                if let url = selected {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "recordingtape").font(.system(size: 54)).foregroundStyle(
                            PerformancePalette.secondaryText
                        ).frame(width: 120, height: 120).bevelPanel(cornerRadius: 3, sunken: true)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Self.title(url)).font(.system(size: 18, weight: .bold)).lineLimit(2)
                            Text(length.map { String(format: "%d:%02d", Int($0) / 60, Int($0) % 60) } ?? "—")
                                .foregroundStyle(PerformancePalette.secondaryText).monospacedDigit()
                            ShareLink(item: url) {
                                Image(systemName: "square.and.arrow.up").frame(width: 48, height: 38).bevelPanel(
                                    cornerRadius: 4)
                            }.accessibilityLabel("Share recording")
                        }
                        Spacer(minLength: 0)
                        LoadSlider(tall: true) { deck in Task { await model.loadRecording(url, deck: deck) } }.disabled(
                            model.importing)
                    }.padding(14).frame(height: 190)
                    Text("Featured Tracks").font(.system(size: 18, weight: .bold)).padding(.horizontal, 14).frame(
                        height: 44)
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if lines.isEmpty {
                                Text("No tracklist was saved with this recording.").foregroundStyle(.secondary).padding(
                                    14)
                            }
                            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(line.title).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                                        Text(line.artist).font(.system(size: 14)).foregroundStyle(
                                            PerformancePalette.secondaryText
                                        ).lineLimit(1)
                                    }
                                    Spacer()
                                    Text(String(format: "%d:%02d", line.seconds / 60, line.seconds % 60))
                                        .monospacedDigit().foregroundStyle(PerformancePalette.secondaryText)
                                }.padding(.horizontal, 14).frame(height: 52)
                            }
                        }
                    }
                } else {
                    Text("Choose a recording").foregroundStyle(.secondary).frame(
                        maxWidth: .infinity, maxHeight: .infinity)
                }
            }.frame(width: 440).background(PerformancePalette.panel).foregroundStyle(PerformancePalette.text)
        }.task { model.refreshRecordings() }.task(id: selected) {
            length = nil
            lines = []
            guard let url = selected else { return }
            let tracklist = model.recordingTracklist(for: url)
            let (seconds, text) = await Task.detached(priority: .utility) { () -> (Double?, String) in
                let file = try? AVAudioFile(forReading: url)
                let seconds = file.map { Double($0.length) / $0.processingFormat.sampleRate }
                return (seconds, tracklist.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "")
            }.value
            length = seconds
            lines = RecordingTracklist.parse(text)
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
            ScrollView {
                LazyVStack(spacing: 0) {
                    if layout.latest == nil {
                        Text("Sessions appear here after you load tracks.").foregroundStyle(.secondary).padding(24)
                    }
                    if let latest = layout.latest {
                        Button {
                            selected = latest
                        } label: {
                            SectionRow(
                                symbol: "music.note.list", title: Self.title(latest),
                                selected: selected?.id == latest.id)
                        }
                    }
                    ForEach(layout.months) { month in
                        Button {
                            openMonth = openMonth == month.id ? nil : month.id
                        } label: {
                            SectionRow(symbol: "folder.fill", title: month.title, chevron: true)
                        }.accessibilityLabel("\(month.title), \(month.sessions.count) sessions")
                        if openMonth == month.id {
                            ForEach(month.sessions) { session in
                                Button {
                                    selected = session
                                } label: {
                                    SectionRow(
                                        symbol: "music.note.list", title: Self.title(session),
                                        selected: selected?.id == session.id
                                    ).padding(.leading, 24)
                                }
                            }
                        }
                    }
                }
            }.frame(maxWidth: .infinity).background(PerformancePalette.frame.opacity(0.6))
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        for id in selected?.trackIDs ?? [] { model.enqueue(id) }
                    } label: {
                        Image(systemName: "text.badge.plus").frame(width: 52, height: 36).bevelPanel(cornerRadius: 4)
                    }.disabled(selected == nil).accessibilityLabel("Add session to prep list")
                }.padding(.horizontal, 14).frame(height: 52)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(selected?.trackIDs ?? [], id: \.self) { id in
                            if let track = model.library.tracks.first(where: { $0.id == id }) {
                                HStack(spacing: 10) {
                                    DeckArtwork(
                                        source: ArtworkSource.track(track, media: model.store.mediaDirectory),
                                        placeholderSize: 12
                                    ).frame(width: 44, height: 44).background(PerformancePalette.sunken).clipShape(
                                        RoundedRectangle(cornerRadius: 3))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(track.title).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                                        Text(track.artist).font(.system(size: 14)).foregroundStyle(
                                            PerformancePalette.secondaryText
                                        ).lineLimit(1)
                                    }
                                    Spacer()
                                    Text(track.key?.openKeyName ?? "—").foregroundStyle(KeyColour.colour(track.key))
                                    Text(track.bpm.map { String(format: "%.1f", $0) } ?? "—").foregroundStyle(
                                        PerformancePalette.secondaryText)
                                }.font(.system(size: 14).monospacedDigit()).padding(.horizontal, 14).frame(height: 56)
                            }
                        }
                    }
                }
            }.frame(width: 440).background(PerformancePalette.panel).foregroundStyle(PerformancePalette.text)
        }
    }
    static func title(_ session: HistorySession) -> String {
        session.started.formatted(.dateTime.weekday(.wide).day().month(.wide).year().hour().minute())
    }
}

/// Settings adapt to the available pane width.
struct SettingsBrowser: View {
    enum Page: String, CaseIterable {
        case sound = "Sound & Headphones"
        case playback = "Decks & Playback"
        case layout = "Layout & Touch"
        case library = "Library & Preparation"
        case controllers = "Controllers"
        case about = "Help & About"
        var symbol: String {
            switch self {
            case .sound: "headphones"
            case .playback: "play.circle"
            case .layout: "rectangle.3.group"
            case .library: "music.note.list"
            case .controllers: "slider.horizontal.3"
            case .about: "questionmark.circle"
            }
        }
        var summary: String {
            switch self {
            case .sound: "Output, routing and cue mix"
            case .playback: "Loading, loops and track endings"
            case .layout: "Visible controls, waveforms and touch"
            case .library: "Music sources, keys and iCloud"
            case .controllers: "Connected devices, lights and MIDI"
            case .about: "Gestures, test features and version"
            }
        }
    }
    @Bindable var model: ReplicaModel
    var importAudio: () -> Void = {}
    var linkCollection: () -> Void = {}
    @State private var page = Page.playback
    @State private var showingDetail = false
    @AppStorage(FourDeckTrial.preferenceKey) private var fourDecks = false

    var body: some View {
        GeometryReader { geometry in
            let narrow = geometry.size.width < 680
            HStack(spacing: 0) {
                if !narrow || !showingDetail {
                    categories.frame(width: narrow ? nil : 250)
                }
                if !narrow || showingDetail {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            if narrow {
                                Button {
                                    showingDetail = false
                                } label: {
                                    Label("Settings", systemImage: "chevron.left")
                                }
                            }
                            Text(page.rawValue).font(.title3.bold())
                            Spacer(minLength: 0)
                        }.frame(minHeight: 52).padding(.horizontal, 20)
                        Divider()
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) { content }
                                .frame(maxWidth: 700, alignment: .leading).padding(20)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }.id(page)
                    }.frame(maxWidth: .infinity).background(PerformancePalette.panel)
                }
            }
        }.foregroundStyle(PerformancePalette.text).tint(PerformancePalette.cyan)
    }

    private var categories: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings").font(.title2.bold()).padding(16)
                ForEach(Page.allCases, id: \.self) { item in
                    Button {
                        page = item
                        showingDetail = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.symbol).frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.rawValue).font(.system(size: 16, weight: .semibold))
                                Text(item.summary).font(.caption).foregroundStyle(PerformancePalette.secondaryText)
                            }
                            Spacer(minLength: 0)
                        }.padding(14).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                            .background(page == item ? rowTeal : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityAddTraits(page == item ? .isSelected : [])
                }
            }.padding(8)
        }.background(PerformancePalette.frame.opacity(0.6))
    }

    @ViewBuilder private var content: some View {
        switch page {
        case .sound:
            SettingsGroup("Output & headphone cue") { OutputSettingsView(model: model) }
            Text("Use the speaker button during a set for master level, headphone mix and recording.")
                .font(.caption).foregroundStyle(.secondary)
        case .playback:
            PlaybackSettings(model: model)
        case .layout:
            LayoutSettings()
        case .library:
            SettingsGroup("Music sources") {
                Button {
                    Task { await model.openNativeMusicLibrary() }
                } label: {
                    Label("Refresh Music library", systemImage: "arrow.clockwise")
                }.disabled(model.musicLibraryRefreshing || model.importing)
                Button(action: importAudio) { Label("Import audio files", systemImage: "folder") }
                Button(action: linkCollection) { Label("Link DJ collection", systemImage: "link") }
                Text("A linked collection is read at launch and imported again when it changes.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            SettingsGroup("Keys from other tools") { KeyImportReviewView(model: model) }
            SettingsGroup("Preparation backup & sharing") { CloudPreparationSettings(model: model) }
        case .controllers:
            SettingsGroup("Devices & controls") { ControllerSettingsView(model: model) }
        case .about:
            SettingsGroup("Learn the controls") {
                Button("Open gesture guide") { model.helpVisible = true }
                Text("Share saved sets from Recordings using the share button.").font(.caption).foregroundStyle(
                    .secondary)
            }
            if FourDeckTrial.isAvailable {
                SettingsGroup("Test features") {
                    Toggle("Four decks", isOn: $fourDecks)
                        .disabled(fourDecks && [.c, .d].contains { model.playbackSnapshot?[$0].phase.active == true })
                    Text("A10X trial. Stop decks C and D before switching back to two decks.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            SettingsGroup("GenErik DJ") {
                GenErikBrandLockup()
                Text(
                    "Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))"
                )
                Text("An independent performance app. Third-party notices ship with the app.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
