#if os(iOS)
    import AVFoundation
    import Foundation
    import TDJCore

    extension ReplicaModel {
        func previewS3Entry(_ entry: LibraryBrowserEntry) {
            guard s3PreviewHeld, entry.canLoad, s3Connection?.isReceiving == true else { return }
            s3PreviewEntry = entry
            startS3Preview(entry, position: 0)
        }

        func stopS3Preview() {
            s3PreviewHeld = false
            s2BrowserCommands.removeAll { $0 == .previewS3 }
            s3PreviewTask?.cancel()
            s3PreviewTask = nil
            s3PreviewEntry = nil
            s3PreviewFrames = 0
            playback.core.setPreviewGeneration(0)
        }

        func seekS3Preview(detents: Int) {
            guard s3PreviewHeld, let entry = s3PreviewEntry else { return }
            let progress =
                s3PreviewFrames > 0
                ? Double(playback.core.previewConsumedFrames) / Double(s3PreviewFrames)
                : 0
            let next = min(1, max(0, s3PreviewPosition + progress + Double(detents) / 80))
            startS3Preview(entry, position: next)
        }

        private func startS3Preview(_ entry: LibraryBrowserEntry, position: Double) {
            s3PreviewTask?.cancel()
            playback.core.setPreviewGeneration(0)
            s3PreviewFrames = 0
            s3PreviewPosition = position
            s3PreviewGeneration &+= 1
            let generation = s3PreviewGeneration
            s3PreviewTask = Task { [weak self] in
                guard let self else { return }
                do {
                    let url: URL
                    if let item = entry.nativeItem, item.isOnDevice,
                        let source = try await musicLibraryProvider.playbackSource(item)
                    {
                        url = source.url
                    } else if let track = entry.track, track.nativeLibraryOnly != true {
                        url = store.mediaDirectory.appendingPathComponent(track.mediaFilename)
                    } else {
                        throw MusicLibraryError.missingAudio
                    }
                    try Task.checkCancellation()
                    guard s3PreviewHeld, s3PreviewGeneration == generation else { return }
                    try playback.startS3PreviewOutput()
                    cancelNativeMusicAnalysis()
                    let core = playback.core
                    core.setPreviewGeneration(generation)
                    let worker = Task.detached(priority: .utility) { [weak self] in
                        try await core.feedPreview(url: url, position: position, generation: generation) {
                            [weak self] frames, _ in
                            await self?.setS3PreviewFrames(frames, generation: generation)
                        }
                    }
                    try await withTaskCancellationHandler {
                        try await worker.value
                    } onCancel: {
                        worker.cancel()
                    }
                } catch is CancellationError {
                } catch {
                    guard s3PreviewGeneration == generation, s3PreviewHeld else { return }
                    playback.core.setPreviewGeneration(0)
                    status = error.localizedDescription
                }
            }
        }

        private func setS3PreviewFrames(_ frames: Int64, generation: UInt64) {
            if s3PreviewHeld, s3PreviewGeneration == generation { s3PreviewFrames = frames }
        }

        func updateS3EXTMix() {
            playback.core.setExternalInputMix(level: s3EXTLevel, cue: s3EXTCue, trim: s3EXTTrim)
        }

        func toggleS3EXT(shifted: Bool) {
            if shifted {
                s3EXTLine.toggle()
                s3Connection?.send(S3AccessoryProtocol.inputSource(line: s3EXTLine))
                return
            }
            if playback.s3ExtEnabled {
                try? playback.setCaptureEnabled(false, device: "S3")
                s3Takeover[.d] = nil
                if let choice = s3PendingFX[.d], playback.generations[.d] != nil {
                    selectS2FX(choice, deck: .d, enabled: s3FXEnabled.contains(.d))
                }
                return
            }
            if let request = s3EXTRequest {
                request.cancel()
                return
            }
            guard playbackSnapshot?[.d].phase.active != true else {
                status = "Pause deck D before opening EXT."
                return
            }
            guard automaticOutputDevice == "S3", playback.canOpenCapture(device: "S3") else {
                status = "Connect the S3 and pause playback before opening EXT."
                return
            }
            s3EXTRequest = Task { [weak self] in
                guard let self else { return }
                defer { s3EXTRequest = nil }
                let permission = AVAudioApplication.shared.recordPermission
                let granted =
                    permission == .granted
                    ? true : permission == .undetermined ? await AVAudioApplication.requestRecordPermission() : false
                guard !Task.isCancelled, s3Connection?.isReceiving == true,
                    playback.core.snapshot()?[.d].phase.active != true
                else { return }
                guard granted else {
                    status = "Allow microphone access to use the S3 EXT input."
                    return
                }
                cancelNativeMusicAnalysis()
                updateS3EXTMix()
                do { try playback.setCaptureEnabled(true, device: "S3") } catch { status = error.localizedDescription }
            }
        }
    }
#endif
