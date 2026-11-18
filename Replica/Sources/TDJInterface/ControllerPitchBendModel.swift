import TDJCore

extension ReplicaModel {
    func applyControllerPitchBend(_ direction: ControllerPitchBendDirection, pressed: Bool, deck: DeckID) {
        guard let state = playbackSnapshot?[deck], state.generation != 0,
            loaded[deck] != nil, !state.touchActive
        else {
            controllerPitchBendButtons[deck] = nil
            return
        }
        guard !pressed || state.phase != .queued else { return }
        var buttons = controllerPitchBendButtons[deck, default: .init()]
        let rate = buttons.update(direction, pressed: pressed, generation: state.generation)
        controllerPitchBendButtons[deck] = buttons
        guard let rate, state.phase != .queued || rate == 1 else { return }
        resetControllerWheelJog(deck, restoreRate: false)
        let previous = controllerPitchBendCommandDeck
        controllerPitchBendCommandDeck = deck
        defer { controllerPitchBendCommandDeck = previous }
        perform(.rate, deck: deck, value: rate)
    }
}
