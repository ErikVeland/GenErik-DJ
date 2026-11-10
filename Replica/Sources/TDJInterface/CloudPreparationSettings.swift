import SwiftUI

struct CloudPreparationSettings: View {
    @Bindable var model: ReplicaModel
    var body: some View {
        SettingsGroup("Sharing & backup") {
            Text(model.cloudStatus).accessibilityIdentifier("cloudPreparationStatus")
            Text(
                "Analysis and sections share through private iCloud storage while the app is open and the decks are idle. Audio files are not included."
            )
            .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Sync now") { model.startCloudSync() }.disabled(!model.canSyncCloud)
                if model.cloudBusy {
                    ProgressView()
                    Button("Stop sync") { model.cancelCloudSyncForPlayback() }
                }
            }.frame(minHeight: 44)
            if !model.canSyncCloud && !model.cloudBusy {
                Text("Stop playback before starting a manual sync.").font(.caption).foregroundStyle(.secondary)
            }
            Text(
                "Sync now also saves preparation for recovery. Manual preparation stays unchanged during automatic sharing."
            )
            .font(.caption).foregroundStyle(.secondary)
        }
        SettingsGroup("Recovery") {
            SettingsPageLink("Saved versions", detail: "Restore a track’s grids, cues and analysis at the next launch")
            {
                SettingsDetailPage("Saved versions") { PreparationVersionsView(model: model) }
            }
        }
    }
}

struct PreparationVersionsView: View {
    @Bindable var model: ReplicaModel
    @State private var selected: CloudRecoveryChoice?
    @State private var visibleCount = 20
    @State private var loading = true
    @State private var search = ""
    private var choices: [CloudRecoveryChoice] {
        model.cloudVersions.filter {
            search.isEmpty || $0.revision.title.localizedCaseInsensitiveContains(search)
                || $0.revision.artist.localizedCaseInsensitiveContains(search)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(
                "Restore preparation between sets. The selected version takes effect after you close and reopen the app."
            )
            .font(.subheadline)
            if !model.canSyncCloud {
                Text("Stop playback and wait for sync to finish before restoring a version.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            TextField("Find a track or artist", text: $search).textFieldStyle(.roundedBorder)
                .onChange(of: search) { _, _ in visibleCount = 20 }
            if loading {
                ProgressView("Reading saved versions…")
            } else if choices.isEmpty {
                Text(
                    search.isEmpty
                        ? "No saved versions. Use Sync now to save preparation for recovery."
                        : "No matching saved versions."
                )
                .foregroundStyle(.secondary)
            }
            ForEach(choices.prefix(visibleCount)) { choice in
                Button {
                    selected = choice
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(choice.revision.title).font(.body.weight(.semibold))
                            Text(choice.revision.artist).font(.caption)
                            Text(choice.revision.savedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                        }
                        Spacer()
                        Image(systemName: "clock.arrow.circlepath")
                    }.frame(minHeight: 52).contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(!model.canSyncCloud)
                Divider()
            }
            if visibleCount < choices.count { Button("Show more") { visibleCount += 20 } }
        }
        .task {
            await model.loadCloudVersions()
            loading = false
        }
        .confirmationDialog(
            "Restore this preparation at the next launch?",
            isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } }),
            titleVisibility: .visible
        ) {
            if let selected {
                Button("Restore at next launch") { model.scheduleCloudRecovery(selected) }
            }
            Button("Cancel", role: .cancel) { selected = nil }
        } message: {
            Text(
                "The selected version will replace this track’s analysis, grids and cues. Your current preparation will remain as another saved version."
            )
        }
    }
}
