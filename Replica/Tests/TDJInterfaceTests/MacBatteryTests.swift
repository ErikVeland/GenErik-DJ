#if os(macOS)
    import IOKit.ps
    import Testing

    @testable import TDJInterface

    private func macBattery(capacity: Int = 47, maximum: Int = 100, charging: Bool = false) -> [String: Any] {
        [
            kIOPSTypeKey: kIOPSInternalBatteryType,
            kIOPSIsPresentKey: true,
            kIOPSCurrentCapacityKey: capacity,
            kIOPSMaxCapacityKey: maximum,
            kIOPSIsChargingKey: charging,
        ]
    }

    @Test func macBatteryReadsLaptopCharge() throws {
        let reading = try #require(MacBatterySource.reading(from: [macBattery(capacity: 470, maximum: 1000)]))
        #expect(reading.level == 0.47)
        #expect(!reading.isCharging)
    }

    @Test func macBatteryRemainsVisibleWhilePluggedIn() throws {
        let charging = try #require(MacBatterySource.reading(from: [macBattery(capacity: 80, charging: true)]))
        let paused = try #require(MacBatterySource.reading(from: [macBattery(capacity: 80)]))
        #expect(charging.level == 0.8 && charging.isCharging)
        #expect(paused.level == 0.8 && !paused.isCharging)
    }

    @Test func macBatteryHidesDesktopsAndExternalPowerSources() {
        var ups = macBattery()
        ups[kIOPSTypeKey] = kIOPSUPSType
        #expect(MacBatterySource.reading(from: []) == nil)
        #expect(MacBatterySource.reading(from: [ups]) == nil)
        #expect(MacBatterySource.reading(from: [ups, macBattery()])?.level == 0.47)
    }

    @Test func macBatteryRejectsMissingAndInvalidCapacity() {
        var missing = macBattery()
        missing.removeValue(forKey: kIOPSCurrentCapacityKey)
        var absent = macBattery()
        absent[kIOPSIsPresentKey] = false
        #expect(MacBatterySource.reading(from: [missing]) == nil)
        #expect(MacBatterySource.reading(from: [absent]) == nil)
        #expect(MacBatterySource.reading(from: [macBattery(maximum: 0)]) == nil)
        #expect(MacBatterySource.reading(from: [macBattery(capacity: -1)]) == nil)
        #expect(MacBatterySource.reading(from: [macBattery(capacity: 101)])?.level == 1)
    }
#endif
