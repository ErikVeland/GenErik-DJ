import SwiftUI
import TDJCore

/// Unobtrusive background-import status. Never takes input and fades when finished.
struct PreparationImportPill: View {
    let progress: PreparationImportProgress
    var body: some View {
        HStack(spacing: 6) {
            Text(progress.text).font(.system(size: 10).monospacedDigit()).lineLimit(1).foregroundStyle(
                progress.message == nil ? Color(white: 0.75) : Color.orange.opacity(0.85))
            if progress.message == nil || progress.isLibraryAnalysis {
                ProgressView(value: progress.fraction).progressViewStyle(.linear).frame(width: 60).tint(
                    PerformancePalette.cyan)
            }
        }.padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Color.white.opacity(0.07)))
            .allowsHitTesting(false).accessibilityElement(children: .ignore).accessibilityLabel(progress.text)
    }
}

struct LibraryAnalysisFooter: View {
    let model: ReplicaModel
    let progress: PreparationImportProgress
    var showsProgress = true
    @State private var backgroundRequestFailed = false

    private var backgroundButtonTitle: LocalizedStringKey {
        switch model.backgroundAnalysisStatus {
        case .idle: "Analyse in Background"
        case .queued: "Background Analysis Queued"
        case .running: "Background Analysis Running"
        }
    }

    private var showsBackgroundButton: Bool {
        #if os(iOS)
            if #available(iOS 26, *) {
                return progress.isLibraryAnalysis
                    && (model.libraryAnalysisNeedsWork || model.backgroundAnalysisStatus != .idle)
            }
        #endif
        return false
    }

    var body: some View {
        if showsProgress || showsBackgroundButton {
            HStack(spacing: 8) {
                if showsProgress { PreparationImportPill(progress: progress) }
                Spacer(minLength: 0)
                #if os(iOS)
                    if #available(iOS 26, *), showsBackgroundButton {
                        Button {
                            guard model.backgroundAnalysisStatus == .idle else { return }
                            backgroundRequestFailed = !ReplicaLifecycle.continueLibraryAnalysis(model)
                        } label: {
                            Text(backgroundButtonTitle)
                                .font(.system(size: 11, weight: .semibold)).foregroundStyle(PerformancePalette.cyan)
                                .frame(minHeight: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .disabled(
                                model.backgroundAnalysisStatus != .idle || model.arrangementPlaybackActive
                                    || model.isRecording || model.recordingFinishing
                            )
                            .alert("Background analysis could not start", isPresented: $backgroundRequestFailed) {
                                Button("OK", role: .cancel) {}
                            } message: {
                                Text("Keep GenErik DJ open to continue analysis, or try again later.").lineLimit(nil)
                            }
                    }
                #endif
            }.padding(.horizontal, 22).frame(height: showsBackgroundButton ? 44 : 36).background(
                PerformancePalette.panel)
        }
    }
}

#if os(iOS)
@MainActor struct IPadLibraryAnalysisSummary: View {
    let model: ReplicaModel
    @State private var counts: Counts?

    struct Counts: Equatable {
        var analysed = 0
        var missing = 0
        var deep = 0

        nonisolated init(_ tracks: [Track]) {
            for track in tracks where track.musicLibrarySources?.contains(where: { $0.platform == .iosMusic }) == true {
                if CloudPreparationArchive.hasAudioIdentity(track) {
                    analysed += 1
                    if track.analysis.deepBeatAnalysis != nil { deep += 1 }
                } else {
                    missing += 1
                }
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            if let counts {
                Text("\(counts.analysed) analysed")
                Text("\(counts.missing) need first analysis")
                Text("\(counts.deep) with deep analysis").foregroundStyle(.secondary)
            } else {
                Text("Reading saved analysis…")
            }
            if let pause = model.nativeMusic.conditions.pauseMessage {
                Text(pause).foregroundStyle(.secondary)
            }
        }
        .font(.caption.monospacedDigit())
        .accessibilityElement(children: .combine)
        .task(id: model.library.revision) {
            let source = model.libraryReadSource()
            let updated = await model.nativeMusic.projection.run {
                source.withValue { Counts($0.tracks) }
            }
            if !Task.isCancelled { counts = updated }
        }
    }
}
#endif
