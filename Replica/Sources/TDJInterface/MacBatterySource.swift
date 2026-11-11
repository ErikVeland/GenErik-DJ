#if os(macOS)
    import Foundation
    import IOKit.ps

    /**
     * Reads only the Mac's internal battery, excluding UPS and accessory power sources.
     */
    struct MacBatterySource: Equatable, Sendable {
        let level: Float
        let isCharging: Bool

        static func current() -> Self? {
            guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
                let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
            else { return nil }
            return reading(
                from: sources.compactMap {
                    IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any]
                })
        }

        static func reading(from sources: [[String: Any]]) -> Self? {
            for source in sources {
                guard source[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                    source[kIOPSIsPresentKey] as? Bool == true,
                    let capacity = source[kIOPSCurrentCapacityKey] as? Int,
                    let maximum = source[kIOPSMaxCapacityKey] as? Int,
                    capacity >= 0, maximum > 0
                else { continue }
                return Self(
                    level: Float(min(capacity, maximum)) / Float(maximum),
                    isCharging: source[kIOPSIsChargingKey] as? Bool ?? false)
            }
            return nil
        }
    }

    /**
     * Delivers power changes on the main run loop and removes the source when the view closes.
     */
    final class MacBatteryObservation {
        private let source: CFRunLoopSource
        private let callback: Unmanaged<Callback>

        @MainActor init?(_ change: @escaping @MainActor @Sendable () -> Void) {
            let callback = Unmanaged.passRetained(Callback(change))
            guard
                let source = IOPSNotificationCreateRunLoopSource(
                    { context in
                        guard let context else { return }
                        let callback = Unmanaged<Callback>.fromOpaque(context).takeUnretainedValue()
                        MainActor.assumeIsolated { callback.action() }
                    }, callback.toOpaque())?.takeRetainedValue()
            else {
                callback.release()
                return nil
            }
            self.callback = callback
            self.source = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }

        deinit {
            CFRunLoopSourceInvalidate(source)
            callback.release()
        }

        private final class Callback: Sendable {
            let action: @MainActor @Sendable () -> Void
            init(_ action: @escaping @MainActor @Sendable () -> Void) { self.action = action }
        }
    }
#endif
