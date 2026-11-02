private final class OwnedValuePayload<Value: Sendable>: Sendable {
    let value: Value
    init(_ value: consuming Value) { self.value = consume value }
}

package struct BackgroundOwnedValue<Value: Sendable>: Sendable {
    private let owner: BackgroundOwnedResource<OwnedValuePayload<Value>>

    package init(_ value: consuming Value) {
        let payload = OwnedValuePayload(consume value)
        owner = BackgroundOwnedResource { payload }
    }

    // Returned value copies can retain data independently of this owner.
    package func withValue<Result>(_ operation: (Value) -> Result) -> Result {
        owner.withResource { operation($0.value) }
    }
}
