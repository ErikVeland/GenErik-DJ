import TDJCore

struct ControllerActionTarget: Hashable, Sendable {
    let action: ControllerAction
    let deck: DeckID?
    let argument: Double?

    init(_ action: ControllerAction, deck: DeckID? = nil, argument: Double? = nil) {
        self.action = action
        self.deck = deck
        self.argument = argument
    }
}
