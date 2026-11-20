import SwiftUI
import TDJCore

struct RecordingExportButton: View {
    @Bindable var model: ReplicaModel
    let recording: URL
    @State private var showing = false
    @State private var format: RecordingExportFormat = .alac
    @State private var task: Task<Void, Never>?
    @State private var worker: Task<RecordingExportResult, Error>?
    @State private var result: RecordingExportResult?
    @State private var message = ""

    private var protected: Bool {
        model.storeAccess.hasActivePerformance || model.isRecording || model.recordingFinishing
            || model.playbackSnapshot?.anyDeckActive == true
    }
    var body: some View {
        Button {
            showing = true
        } label: {
            Image(systemName: "square.and.arrow.up").frame(width: 48, height: 38).bevelPanel(cornerRadius: 4)
        }
        .accessibilityLabel("Export recording and tracklist")
        .popover(isPresented: $showing) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Export recording").font(.headline)
                Picker("Audio format", selection: $format) {
                    ForEach(RecordingExportFormat.allCases) { format in Text(format.label).tag(format) }
                }.disabled(task != nil)
                Text(
                    "Includes the logo, metadata and timed tracklist. A separate text tracklist is shared with the audio."
                )
                .font(.caption).fixedSize(horizontal: false, vertical: true)
                if protected {
                    Text("End the performance before exporting.").font(.caption)
                }
                if task != nil {
                    ProgressView("Preparing export…")
                    Button("Cancel export") { cancel() }
                } else if let result {
                    ShareLink(items: result.files) {
                        Label("Share audio and tracklist", systemImage: "square.and.arrow.up")
                    }
                    Button("Export again") { start() }.disabled(protected)
                } else {
                    Button("Export") { start() }.disabled(protected)
                }
                if !message.isEmpty { Text(message).font(.caption).fixedSize(horizontal: false, vertical: true) }
            }.padding(20).frame(idealWidth: 340)
                .onChange(of: format) {
                    result = nil
                    message = ""
                }
        }
        .onChange(of: protected) {
            if protected, task != nil {
                cancel()
                message = RecordingExportError.performanceActive.localizedDescription
            }
        }
        .onChange(of: recording) {
            cancel()
            result = nil
            message = ""
        }
        .onDisappear { cancel() }
    }
    private func cancel() {
        worker?.cancel()
        task?.cancel()
        worker = nil
        task = nil
    }
    private func start() {
        guard task == nil, !protected else { return }
        result = nil
        message = ""
        let source = recording
        let list = model.recordingTracklist(for: source)
        let chosen = format
        let core = model.playback.core
        let resourceBundle =
            Bundle.main.resourceURL
            .flatMap { Bundle(url: $0.appendingPathComponent("GenErikDJ_TDJInterface.bundle")) } ?? .module
        let artworkURL =
            resourceBundle.url(forResource: "GenErikHeaderMark", withExtension: "png")
            ?? resourceBundle.url(forResource: "GenErikHeaderMark", withExtension: "png", subdirectory: "HeaderArtwork")
        let djName = UserDefaults.standard.string(forKey: StoreAccess.customDJNameKey) ?? "GenErik DJ"
        let work = Task.detached(priority: .background) {
            guard let artworkURL else { throw RecordingExportError.missingArtwork }
            let artwork = try Data(contentsOf: artworkURL)
            var metadata = try await RecordingExportMetadata.read(recording: source, tracklist: list, artwork: artwork)
            if metadata.fields["artist"] == nil { metadata.fields["artist"] = djName.isEmpty ? "GenErik DJ" : djName }
            let root = try FileManager.default.url(
                for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            )
            .appendingPathComponent("RecordingExports", isDirectory: true)
            return try RecordingExport.run(
                source: source, format: chosen, metadata: metadata, directory: root,
                shouldYield: {
                    guard let snapshot = core.snapshot() else { return true }
                    return core.performanceWorkGate.isProtected || snapshot.anyDeckActive
                        || DeckID.allCases.contains { snapshot[$0].touchActive }
                        || core.playingPads > 0 || core.loopRecorderState.isActive
                })
        }
        worker = work
        task = Task { @MainActor in
            do {
                let exported = try await work.value
                guard !Task.isCancelled else { return }
                result = exported
            } catch {
                guard !Task.isCancelled else { return }
                message = error is CancellationError ? "Export cancelled." : error.localizedDescription
            }
            worker = nil
            task = nil
        }
    }
}
