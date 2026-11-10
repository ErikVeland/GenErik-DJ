#if os(iOS)
    import Foundation
    import TDJCore

    extension ReplicaModel {
        func startS3() {
            guard s3Connection == nil else { return }
            let connection = NIControllerAccessoryConnection(model: .s3)
            connection.onState = { [weak self, weak connection] status, _ in
                guard let self else { return }
                s3Status = status
                if connection?.isReceiving == true {
                    playback.core.setMasterMeterEnabled(true)
                    connection?.send(S3AccessoryProtocol.inputSource(line: s3EXTLine))
                }
            }
            connection.onFrame = { [weak self] frame in
                guard let self else { return }
                for event in s3Controls.consume(frame) { applyNativeTraktorEvent(event, isS3: true) }
            }
            connection.onDisconnect = { [weak self] in self?.releaseS3Controls() }
            do {
                try connection.start()
                s3Connection = connection
            } catch { s3Status = error.localizedDescription }
        }

        private func releaseS3Controls() {
            playback.core.setMasterMeterEnabled(false)
            stopS3Preview()
            s3EXTRequest?.cancel()
            try? playback.setCaptureEnabled(false, device: "S3")
            s3EXTCue = false
            for deck in s3Controls.touched { applyController(deck == .a ? .jogTouchA : .jogTouchB, value: 0) }
            for deck in s3Controls.reversing { perform(.rate, deck: deck, value: 1) }
            for deck in s3Controls.bent { resetControllerWheelJog(deck) }
            for deck in s3Controls.rolling { setNativeTraktorRoll(deck: deck, held: false, quantized: true) }
            for deck in s3Controls.gridHeld { endS2Grid(deck: deck, save: false) }
            if s2Connection?.isReceiving != true {
                s2SampleLoad?.cancel()
                for (slot, generation) in s2SampleSlots {
                    try? playback.triggerPad(slot, generation: generation, enabled: false)
                }
                s2BrowserCommands.removeAll()
            }
            for deck in s3Controls.touched { s2LastScratch[deck] = nil }
            s3Controls = .init()
            s3Takeover.removeAll()
        }

        func moveS3(deck: DeckID, detents: Int, shifted: Bool) {
            let size = s3JumpBeats[deck, default: 4]
            if shifted {
                s3JumpBeats[deck] = min(32, max(0.03125, size * pow(2, Double(detents))))
            } else if playbackSnapshot?[deck].loopEnabled == true {
                moveS3Loop(deck: deck, beats: Double(detents) * size)
            } else {
                beatJump(beats: Double(detents) * size, deck: deck)
            }
        }

        func moveS3Loop(deck: DeckID, beats: Double) {
            guard let state = playbackSnapshot?[deck], state.loopEnabled, !state.loopRolling,
                let timing = state.timing, let asset = playback.core.asset(generation: state.generation)
            else { return }
            let start = timing.frame(atBeat: timing.beat(atFrame: state.loopStart) + beats)
            let end = timing.frame(atBeat: timing.beat(atFrame: state.loopEnd) + beats)
            guard start >= 0, end <= Double(asset.frames) else { return }
            setLoop(start: start, end: end, deck: deck)
        }

        func refreshS3Lights() {
            guard let connection = s3Connection, connection.isReceiving, let snapshot = playbackSnapshot else { return }
            let frames = (
                a: playback.core.asset(generation: snapshot.a.generation)?.frames,
                b: playback.core.asset(generation: snapshot.b.generation)?.frames
            )
            func slots(_ deck: DeckID) -> Set<Int> {
                guard let track = loaded[deck], let cues = performance.cues[track] else { return [] }
                return Set(cues.keys)
            }
            let feedback = S2MK3Feedback(
                sampleSlots: Set(s2SampleSlots.keys), playingSamples: playback.core.playingPads,
                fx: Set(DeckID.allCases.map { s2FX[$0] ?? .filter }), browser: browserVisible)
            let reports = S3Lights.reports(
                snapshot: snapshot, sourceFrames: frames, cues: (slots(.a), slots(.b)),
                controls: s3Controls, feedback: feedback, enabledFX: s3FXEnabled,
                external: (playback.s3ExtEnabled, s3EXTCue), master: playback.core.masterMeter)
            for report in reports { connection.send(report) }
        }
    }
#endif
