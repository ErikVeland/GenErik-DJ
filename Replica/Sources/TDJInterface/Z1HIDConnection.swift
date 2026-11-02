#if os(macOS)
import Foundation
import IOKit.hid
import TDJCore

/// Opt-in Mac HID transport. Never opened by app startup, tests or preview rendering.
final class Z1HIDConnection: @unchecked Sendable {
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private let input = UnsafeMutablePointer<UInt8>.allocate(capacity: 128)
    @MainActor var onReport: ((Z1InputReport) -> Void)?
    @MainActor var onState: ((String, Z1CrossfaderCalibration?) -> Void)?
    private var lastOutput: [UInt8] = []
    @MainActor init() {}
    deinit { close(); input.deallocate() }

    @MainActor func start() throws {
        guard manager == nil else { return }
        let manager=IOHIDManagerCreate(kCFAllocatorDefault,IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager=manager
        IOHIDManagerSetDeviceMatching(manager,[kIOHIDVendorIDKey:0x17cc,kIOHIDProductIDKey:0x1210] as CFDictionary)
        let context=Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager,{ context,result,_,device in
            guard result == kIOReturnSuccess, let context else { return }
            MainActor.assumeIsolated {
                Unmanaged<Z1HIDConnection>.fromOpaque(context).takeUnretainedValue().attach(device)
            }
        },context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager,{ context,_,_,device in
            guard let context else { return }
            MainActor.assumeIsolated {
                let connection=Unmanaged<Z1HIDConnection>.fromOpaque(context).takeUnretainedValue()
                if connection.device == device {
                    connection.device=nil; connection.lastOutput=[]
                    connection.onState?("Z1 disconnected",nil)
                }
            }
        },context)
        IOHIDManagerScheduleWithRunLoop(manager,CFRunLoopGetMain(),CFRunLoopMode.commonModes.rawValue)
        let result=IOHIDManagerOpen(manager,IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            close(); throw NSError(domain:NSOSStatusErrorDomain,code:Int(result))
        }
        onState?("Waiting for original Z1",nil)
    }
    private func close() {
        if let device { IOHIDDeviceRegisterInputReportCallback(device,input,128,nil,nil) }
        if let manager {
            IOHIDManagerRegisterDeviceMatchingCallback(manager,nil,nil)
            IOHIDManagerRegisterDeviceRemovalCallback(manager,nil,nil)
            IOHIDManagerUnscheduleFromRunLoop(manager,CFRunLoopGetMain(),CFRunLoopMode.commonModes.rawValue)
            IOHIDManagerClose(manager,IOOptionBits(kIOHIDOptionsTypeNone))
        }
        device=nil; manager=nil; lastOutput=[]
    }
    @MainActor func stop() { close(); onState?("Z1 disabled",nil) }
    @MainActor private func attach(_ candidate: IOHIDDevice) {
        guard device == nil else { return }
        device=candidate
        var feature=[UInt8](repeating:0,count:33); feature[0]=0xd2
        var length=feature.count
        let result=feature.withUnsafeMutableBufferPointer {
            IOHIDDeviceGetReport(candidate,kIOHIDReportTypeFeature,0xd2,$0.baseAddress!,&length)
        }
        let payload: [UInt8]
        if length == 33 && feature[0] == 0xd2 { payload=Array(feature[1..<33]) }
        else if length == 32 { payload=Array(feature.prefix(32)) }
        else { payload=[] }
        let calibration=result == kIOReturnSuccess ? try? Z1CrossfaderCalibration(featureD2:payload) : nil
        onState?(calibration == nil ? "Z1 connected; crossfader calibration unavailable" : "Z1 connected · hardware validation pending",calibration)
        IOHIDDeviceRegisterInputReportCallback(candidate,input,128,{ context,result,_,_,reportID,bytes,length in
            guard result == kIOReturnSuccess,reportID == 1,let context else { return }
            let data=Array(UnsafeBufferPointer(start:bytes,count:length))
            let complete=data.count == 29 ? [UInt8(1)]+data : data
            guard let report=try? Z1InputReport(bytes:complete) else { return }
            MainActor.assumeIsolated {
                Unmanaged<Z1HIDConnection>.fromOpaque(context).takeUnretainedValue().onReport?(report)
            }
        },Unmanaged.passUnretained(self).toOpaque())
    }
    @MainActor func send(_ bytes: [UInt8]) {
        guard let device,bytes.count == 22,bytes != lastOutput else { return }
        let result=bytes.withUnsafeBufferPointer {
            IOHIDDeviceSetReport(device,kIOHIDReportTypeOutput,0x80,$0.baseAddress!,bytes.count)
        }
        if result == kIOReturnSuccess { lastOutput=bytes }
    }
}
#endif
