import SwiftUI
import UniformTypeIdentifiers
import TDJCore

/// Reviews a governed key manifest before applying it to the local library.
struct KeyImportReviewView: View {
    @Bindable var model: ReplicaModel
    @State private var importing = false
    @State private var showingReview = false
    @State private var preview: (manifest: KeyImportManifest, plan: KeyImportPlan)?
    @State private var errorMessage: String?

    private var protectedTrackIDs: Set<String> { Set(model.loaded.values) }
    private var hasPreview: Bool {
        if case .some = preview { return true }
        return false
    }
    private var hasProtectedChanges: Bool {
        preview?.plan.changes.contains { protectedTrackIDs.contains($0.trackID) } ?? false
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Key review file").font(.headline)
            Text("Import GenErik’s governed JSON interchange. Native Mixed In Key files are not supported here.")
                .font(.caption).foregroundStyle(.secondary)
            Button { importing = true } label: { Label("Review key import…", systemImage: "key.horizontal") }
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    do {
                        preview = try await model.previewKeyImport(from: url)
                        errorMessage = nil
                        showingReview = true
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $showingReview, onDismiss: { preview = nil }) {
            reviewSheet
        }
    }

    private var reviewSheet: some View {
        NavigationStack {
            Group {
                if let preview {
                    let entriesByTrackID = Dictionary(uniqueKeysWithValues: preview.manifest.entries.map { ($0.contentSHA256, $0) })
                    List {
                        Section("Source") {
                            LabeledContent("Producer", value: preview.manifest.source.rawValue)
                            LabeledContent("Attribution", value: preview.manifest.attribution.rawValue)
                            LabeledContent("Description", value: preview.manifest.sourceDescription)
                            Text("Attribution is a declaration. It does not verify the vendor or key accuracy.")
                                .font(.caption).foregroundStyle(.secondary)
                            if let version = preview.manifest.producerVersion {
                                LabeledContent("Producer version", value: version)
                            }
                            LabeledContent("Manifest SHA256", value: preview.plan.manifestSHA256)
                                .font(.caption.monospaced())
                        }
                        Section("Track changes · \(preview.plan.changes.count)") {
                            ForEach(preview.plan.changes, id: \.trackID) { change in
                                changeRow(change, importedEntry: entriesByTrackID[change.trackID])
                            }
                        }
                        if hasProtectedChanges {
                            Section {
                                Label("This import includes a track loaded on a deck. Eject it before applying.", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                } else {
                    ProgressView("Preparing review…")
                }
            }
            .navigationTitle("Review key import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingReview = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { applyPreview() }
                        .disabled(!hasPreview || hasProtectedChanges)
                }
            }
        }
    }

    @ViewBuilder private func changeRow(_ change: KeyImportPlan.Change,
                                        importedEntry: KeyImportManifest.Entry?) -> some View {
        let track = model.library.track(id: change.trackID)
        VStack(alignment: .leading, spacing: 5) {
            Text(track?.title ?? "Unknown track").font(.headline)
            Text(track?.artist ?? change.trackID).font(.subheadline).foregroundStyle(.secondary)
            HStack {
                Text(change.before.key?.openKeyName ?? "No key")
                Image(systemName: "arrow.right")
                Text(change.after.key?.openKeyName ?? "No key")
                Spacer()
                Text(change.after.authority?.rawValue ?? "unselected")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let entry = importedEntry {
                Text("Imported value: \(entry.rawKey) · \(entry.notation.rawValue)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if change.after.needsReview {
                Label("Conflicting key evidence: \(change.after.conflictingAuthorities.map(\.rawValue).joined(separator: ", "))", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
            if !change.addsEvidence {
                Text("Already imported; no new evidence will be added.").font(.caption).foregroundStyle(.secondary)
            }
            if protectedTrackIDs.contains(change.trackID) {
                Text("Loaded on a deck").font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    private func applyPreview() {
        guard let plan = preview?.plan else { return }
        Task {
            do {
                try await model.applyKeyImport(plan)
                showingReview = false
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
                showingReview = false
            }
        }
    }
}
