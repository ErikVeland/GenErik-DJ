import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AudioCheckView: View {
    @Bindable var model: AudioCheckModel
    @State private var sharing=false
    var body: some View {
        NavigationStack {
            ScrollView { AudioCheckContents(model:model,share:{ sharing=true }) }
                .navigationTitle("GenErik Audio Check")
                .sheet(isPresented:$sharing) { AudioCheckShareSheet(urls:model.shareURLs) }
        }
    }
}

struct AudioCheckContents: View {
    @Bindable var model: AudioCheckModel
    var share: () -> Void
    private var title: String {
        switch model.phase {
        case .ready: "Ready"
        case .running: "Check running"
        case .stopping: "Stopping"
        case .passed: "Passed"
        case .failed: "Check failed"
        case .cancelled: "Cancelled"
        }
    }
    var body: some View {
    VStack(alignment:.leading,spacing:24) {
        Text("Synthetic audio diagnostic").font(.title2.bold())
        Text("Uses the production audio and recording paths with background analysis and a synthetic catalog of 115,219 songs. Hardware audio output stays silent.")
        VStack(alignment:.leading,spacing:14) {
            Button("60-second loop check") { model.start(preset:.loop60) }
            Button("5-minute loop and cue check") { model.start(preset:.loop300) }
            Button("5-minute continuous check") { model.start(preset:.sequential300) }
            Button("60-second live interface check") { model.start(preset:.ui60) }
            Button("5-minute live loop and panel check") { model.start(preset:.uiLoop300Panels) }
            Button("5-minute live continuous and panel check") { model.start(preset:.uiSequential300Panels) }
            Button("5-minute near-2× Keylock loop check") { model.start(preset:.loop300Near2x) }
            Button("5-minute near-2× Keylock loop and panel check") { model.start(preset:.uiLoop300PanelsNear2x) }
            Button("60-second 44.1 kHz near-2× Keylock loop check") { model.start(preset:.loop60Near2x44100) }
            Button("5-minute 44.1 kHz near-2× Keylock loop check") { model.start(preset:.loop300Near2x44100) }
        }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.busy)
        HStack(spacing:16) {
            if model.busy { ProgressView() }
            Text(title).font(.headline)
                .foregroundStyle(model.phase == .passed ? Color.green : .primary)
            Spacer()
            Button("Cancel",role:.destructive) { model.cancel() }
                .buttonStyle(.bordered).controlSize(.large)
                .disabled(model.phase != .running)
        }
        Text(model.progress).textSelection(.enabled)
        Button("Share results",action:share)
            .buttonStyle(.bordered).controlSize(.large).disabled(model.busy || model.shareURLs.isEmpty)
        if !model.shareURLs.isEmpty {
            Text(model.shareURLs.map(\.lastPathComponent).joined(separator:" · "))
                .font(.caption).foregroundStyle(.secondary)
        }
        Divider()
        Text("Keep this app in the foreground. Leaving it cancels the check. Preparation and result saving take additional time.")
        Text("This check does not establish listening quality, DJ gesture behavior, full interface smoothness, or fidelity to the original app.")
        #if targetEnvironment(simulator)
        Text("Simulator results do not establish physical iPad performance.").fontWeight(.semibold)
        #endif
        Text("Runs are kept in this app’s Documents/GenErikDJ-AudioChecks folder. Share results before removing a run in Files. Long checks can use substantial storage.")
            .font(.footnote).foregroundStyle(.secondary)
    }.padding(28).frame(maxWidth:760,alignment:.leading).frame(maxWidth:.infinity)
    }
}

#if canImport(UIKit)
private struct AudioCheckShareSheet: UIViewControllerRepresentable {
    let urls: [URL]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems:urls,applicationActivities:nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController,context: Context) {}
}

#else
private struct AudioCheckShareSheet: View {
    let urls: [URL]
    var body: some View { Text("Sharing is available in the iPad app.").padding() }
}
#endif
