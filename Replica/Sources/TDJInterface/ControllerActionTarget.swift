import TDJCore

struct ControllerActionTarget: Hashable, Sendable {
    let action: ControllerAction
    let deck: DeckID?

    init(_ action: ControllerAction, deck: DeckID? = nil) {
        self.action = action
        self.deck = deck
    }
}
