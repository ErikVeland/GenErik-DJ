#if os(iOS)
    import Foundation
    import TDJCore

    extension ReplicaModel {
        func startS2MK3() {
            guard s2Connection == nil else { return }
            let connection = NIControllerAccessoryConnection(model: .s2MK3)
            connection.onState = { [weak self] status, _ in self?.s2Status = status }
            connection.onFrame = { [weak self] frame in self?.receiveS2Frame(frame) }
            connection.onDisconnect = { [weak self] in self?.releaseS2Controls() }
            do {
                try connection.start()
                s2Connection = connection
            } catch { s2Status = error.localizedDescription }
        }

        private func receiveS2Frame(_ frame: Z1AccessoryProtocol.Frame) {
            for event in s2Controls.consume(frame) {
                switch event {
                case .action(let action, let value):
                    if action == .jogA || action == .jogB {
                        s2LastScratch[action.deck] = ProcessInfo.processInfo.systemUptime
                    } else if action.isMomentary && value == 0 {
                        s2LastScratch[action.deck] = nil
                    }
                    applyController(action, value: value)
                case .pot(let action, let value):
                    if s2Takeover[action, default: .init()].shouldApply(input: value, target: controllerValue(action)) {
                        applyController(action, value: value, refreshMixer: false)
                    }
                case .deleteCue(let deck, let slot):
                    cue(slot: slot, deck: deck, delete: true)
                case .flux(let deck):
                    perform(.flux, deck: deck, enabled: playbackSnapshot?[deck].fluxEnabled != true)
                case .reverse(let deck, let held):
                    resetControllerWheelJog(deck, restoreRate: false)
                    perform(.rate, deck: deck, value: held ? -1 : 1)
                }
            }
        }

        func settleS2Scratch() {
            guard !s2LastScratch.isEmpty else { return }
            let now = ProcessInfo.processInfo.systemUptime
            for deck in DeckID.allCases {
                guard let last = s2LastScratch[deck], now - last >= 0.06 else { continue }
                s2LastScratch[deck] = nil
                applyController(deck == .a ? .jogA : .jogB, value: 0.5)
            }
        }

        private func releaseS2Controls() {
            for deck in s2Controls.touched { applyController(deck == .a ? .jogTouchA : .jogTouchB, value: 0) }
            for deck in s2Controls.reversing { perform(.rate, deck: deck, value: 1) }
            for deck in DeckID.allCases { resetControllerWheelJog(deck) }
            s2Controls = .init()
            s2Takeover.removeAll()
            s2LastScratch.removeAll()
        }

        func refreshS2Lights() {
            guard let connection = s2Connection, connection.isReceiving, let snapshot = playbackSnapshot else { return }
            let frames = (
                a: playback.core.asset(generation: snapshot.a.generation)?.frames,
                b: playback.core.asset(generation: snapshot.b.generation)?.frames
            )
            func slots(_ deck: DeckID) -> Set<Int> {
                guard let track = loaded[deck], let cues = performance.cues[track] else { return [] }
                return Set(cues.keys)
            }
            connection.send(S2MK3Lights.report(snapshot: snapshot, sourceFrames: frames, cues: (slots(.a), slots(.b))))
        }
    }
#endif
