import CTDJTransport
import Foundation

private struct OutputSourceGeometry: Equatable {
    let asset: ObjectIdentifier
    let generation: UInt64
    let targets: [PCMSourceTarget]
}

extension SampleTransport {
    @MainActor private func outputSourceGeometry(_ state: PlaybackSnapshot) throws -> [DeckID: OutputSourceGeometry] {
        var result: [DeckID: OutputSourceGeometry] = [:]
        for deck in state.deckIDs where state[deck].phase.active {
            let generation = state[deck].generation
            guard let asset = asset(generation: generation) else { throw TransportError.stale }
            guard asset.isStreamed else { continue }
            let targets = SourceControl.tempo(state.masterBPM).preparationTargets(
                snapshot: state, deck: deck, frames: asset.frames)
            guard !targets.isEmpty else { throw TransportError.invalid }
            result[deck] = .init(asset: ObjectIdentifier(asset), generation: generation, targets: targets)
        }
        return result
    }

    /// Output must remain stopped throughout this operation. All reads run on source workers.
    @MainActor public func prepareActiveSourcesForOutput() async throws {
        while true {
            try Task.checkCancellation()
            guard processControlsWhileIdle(), let before = snapshot() else { throw TransportError.protectedDeck }
            let bound = configuredMaximumOutputFrames
            let geometry = try outputSourceGeometry(before)
            var groups: [ObjectIdentifier: (asset: PCMAsset, generation: UInt64, targets: [PCMSourceTarget])] = [:]
            for deck in before.deckIDs {
                guard let source = geometry[deck], let asset = asset(generation: source.generation) else { continue }
                if groups[source.asset] == nil { groups[source.asset] = (asset, source.generation, []) }
                groups[source.asset]?.targets.append(contentsOf: source.targets)
            }
            var preparations: [(PCMAsset, UInt64)] = []
            defer { for (asset, ticket) in preparations { asset.releaseSourcePreparation(ticket) } }
            for group in groups.values {
                let ticket = try await group.asset.prepareSources(
                    group.targets, generation: group.generation, requireReserve: false
                ) { guard self.processControlsWhileIdle() else { throw TransportError.protectedDeck } }
                preparations.append((group.asset, ticket))
            }
            while true {
                try Task.checkCancellation()
                // READY preparation may still be in an unpublished or withdrawn table.
                guard processControlsWhileIdle(), let after = snapshot() else { throw TransportError.protectedDeck }
                guard bound == configuredMaximumOutputFrames, try geometry == outputSourceGeometry(after) else { break }
                if try outputSourcesAreReady() { return }
                for (asset, ticket) in preparations {
                    try PCMStreamingError.check(tdj_asset_prepare_status(asset.pointer, ticket))
                }
                try await Task.sleep(for: .milliseconds(5))
            }// Reprepare changed source geometry. Mixer and FX controls do not delay startup.
        }
    }
}
