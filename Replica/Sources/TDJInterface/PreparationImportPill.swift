import SwiftUI

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
                            .disabled(model.backgroundAnalysisStatus != .idle || model.arrangementPlaybackActive
                                || model.isRecording || model.recordingFinishing)
                            .alert("Background analysis could not start", isPresented: $backgroundRequestFailed) {
                                Button("OK", role: .cancel) {}
                            } message: {
                                Text("Keep GenErik DJ open to continue analysis, or try again later.")
                            }
                    }
                #endif
            }.padding(.horizontal, 22).frame(height: showsBackgroundButton ? 44 : 36).background(PerformancePalette.panel)
        }
    }
}
