import AVFoundation
import Foundation
import TDJCore

struct MacAnalysisSourceRequest: Codable, Sendable {
    let version: Int
    let id: UUID
    let sourceID: String?

    var valid: Bool { version == 1 && (sourceID == nil || sourceID.flatMap(UInt64.init) != nil) }
    var filename: String { id.uuidString + ".caf" }
}

struct MacAnalysisSourceResponse: Codable, Sendable {
    let id: UUID
    let state: String
    var filename: String?
    var sha256: String?
    var sampleRate: Double?
    var frameCount: Int64?
    var channelCount: Int?
    var error: String?
}

extension ReplicaModel {
    /// Keep one requested device audio copy for the Mac. Playback cancels preparation.
    func startMacAnalysisSourceTransfer() {
        #if os(iOS)
        guard macSourceTransferLoop == nil, !nativeMusic.closed else { return }
        macSourceTransferLoop = Task { [weak self] in
            while !Task.isCancelled {
                if let self, !self.nativeMusic.backgrounded, !self.nativeMusic.closed,
                    self.nativeMusic.conditions.pauseMessage == nil,
                    self.canSyncCloud, self.macSourceTransferWork == nil {
                    await self.checkMacAnalysisSourceRequest()
                }
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
            }
        }
        #endif
    }

    func stopMacAnalysisSourceTransfer() {
        macSourceTransferLoop?.cancel()
        macSourceTransferLoop = nil
        macSourceTransferWork?.cancel()
    }

    private func checkMacAnalysisSourceRequest() async {
        let root = store.root.appendingPathComponent("MacAnalysisTransfer", isDirectory: true)
        let files = nativeMusic.files
        let request = await files.run { () -> MacAnalysisSourceRequest? in
            guard let data = try? Data(contentsOf: root.appendingPathComponent("request.json")),
                data.count < 4096,
                let request = try? JSONDecoder().decode(MacAnalysisSourceRequest.self, from: data), request.valid
            else { return nil }
            if let data = try? Data(contentsOf: root.appendingPathComponent("response.json")),
                let response = try? JSONDecoder().decode(MacAnalysisSourceResponse.self, from: data),
                response.id == request.id {
                if request.sourceID == nil, response.state == "released" { return nil }
                if request.sourceID != nil, response.state == "failed" { return nil }
                if request.sourceID != nil, response.state == "ready",
                    FileManager.default.fileExists(atPath: root.appendingPathComponent(request.filename).path) { return nil }
            }
            return request
        }
        guard let request, canSyncCloud, !nativeMusic.backgrounded, !nativeMusic.closed else { return }
        let item = request.sourceID.flatMap { source in
            musicLibraryCatalog?.items.first { $0.source.platform == .iosMusic && $0.source.persistentID == source && $0.isOnDevice }
        }
        guard request.sourceID == nil || musicLibraryCatalog != nil else { return }
        macSourceTransferActive = true
        cancelNativeMusicAnalysis()
        let work = Task { [self] in
            defer {
                macSourceTransferActive = false
                macSourceTransferWork = nil
                startNativeMusicAnalysis()
            }
            await flushNativeMusicAnalysis()
            do {
                try Task.checkCancellation()
                guard cloudPlaybackIsIdle, !nativeMusic.backgrounded else { throw CancellationError() }
                try await files.run {
                    Result {
                        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                        for file in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
                        where file.pathExtension == "caf" && UUID(uuidString: file.deletingPathExtension().lastPathComponent) != nil {
                            try FileManager.default.removeItem(at: file)
                        }
                    }
                }.get()
                let response: MacAnalysisSourceResponse
                if let item {
                    let destination = root.appendingPathComponent(request.filename)
                    let free = try await files.run {
                        Result { (try FileManager.default.attributesOfFileSystem(forPath: root.path)[.systemFreeSize] as? NSNumber)?.doubleValue ?? 0 }
                    }.get()
                    guard free > max(0, item.duration) * 192_000 * 2 * 4 + 512 * 1024 * 1024 else {
                        throw CoreError.invalidWorkspace("The iPad has insufficient free space for this audio copy.")
                    }
                    response = try await withNativeAudio(item) { prepared in
                        try Task.checkCancellation()
                        if prepared.temporary {
                            try await files.run { Result { try FileManager.default.moveItem(at: prepared.url, to: destination) } }.get()
                        } else {
                            try await MusicLibraryAudio.decodeAsset(url: prepared.url, destination: destination)
                        }
                        let identity = try await AnalysisWorker.shared.audioIdentity(url: destination)
                        return MacAnalysisSourceResponse(id: request.id, state: "ready", filename: request.filename,
                            sha256: identity.sha256, sampleRate: identity.sampleRate,
                            frameCount: identity.frameCount, channelCount: identity.channels)
                    }
                } else if request.sourceID == nil {
                    response = MacAnalysisSourceResponse(id: request.id, state: "released")
                } else {
                    throw MusicLibraryError.missingAudio
                }
                try Task.checkCancellation()
                try await files.run {
                    Result { try JSONEncoder().encode(response).write(to: root.appendingPathComponent("response.json"), options: .atomic) }
                }.get()
            } catch is CancellationError {
                // The same request resumes when the performance controls become idle.
            } catch {
                let response = MacAnalysisSourceResponse(id: request.id, state: "failed", error: error.localizedDescription)
                await files.run {
                    try? JSONEncoder().encode(response).write(to: root.appendingPathComponent("response.json"), options: .atomic)
                }
            }
        }
        macSourceTransferWork = work
        await work.value
    }
}
