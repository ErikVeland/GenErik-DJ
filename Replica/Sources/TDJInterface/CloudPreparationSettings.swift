import SwiftUI

struct CloudPreparationSettings: View {
    @Bindable var model: ReplicaModel
    @State private var selected: CloudRecoveryChoice?
    @State private var visibleCount = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("iCloud preparation").font(.headline)
            Text(
                "Deep analysis and sections are shared automatically through your private iCloud storage while the app is open and the decks are idle. Manual preparation stays unchanged. Audio files are not included."
            )
            .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Sync now") { model.startCloudSync() }.disabled(!model.canSyncCloud)
                if model.cloudBusy {
                    ProgressView()
                    Button("Stop") { model.cancelCloudSyncForPlayback() }
                }
            }
            Text(model.cloudStatus).font(.caption).accessibilityIdentifier("cloudPreparationStatus")
            Text(
                "Sync now also saves full preparation for recovery. Recovery applies after you close and reopen the app."
            )
            .font(.caption).foregroundStyle(.secondary)
            if !model.cloudVersions.isEmpty {
                DisclosureGroup("Saved preparation revisions (\(model.cloudVersions.count))") {
                    ForEach(model.cloudVersions.prefix(visibleCount)) { choice in
                        Button {
                            selected = choice
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(choice.revision.title)
                                Text(
                                    "\(choice.revision.artist) · \(choice.revision.savedAt.formatted(date: .abbreviated, time: .shortened))"
                                )
                                .font(.caption).foregroundStyle(.secondary)
                            }
                        }.disabled(!model.canSyncCloud)
                    }
                    if visibleCount < model.cloudVersions.count {
                        Button("Show more") { visibleCount += 20 }
                    }
                }
            }
        }
        .task { await model.loadCloudVersions() }
        .confirmationDialog(
            "Restore this preparation at the next launch?",
            isPresented: Binding(
                get: { selected != nil }, set: { if !$0 { selected = nil } }
            ), titleVisibility: .visible
        ) {
            if let selected {
                Button("Restore at next launch") { model.scheduleCloudRecovery(selected) }
            }
            Button("Cancel", role: .cancel) { selected = nil }
        } message: {
            Text(
                "The selected revision will replace this track’s analysis, grids and cues. Your current preparation will be retained as another recovery version."
            )
        }
    }
}
