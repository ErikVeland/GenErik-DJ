#if os(iOS)
    import CoreAudioKit
    import SwiftUI

    /**
     * Uses the system browser to connect Bluetooth MIDI peripherals through Core MIDI.
     */
    struct ControllerBluetoothMIDIView: UIViewControllerRepresentable {
        func makeUIViewController(context: Context) -> CABTMIDICentralViewController {
            CABTMIDICentralViewController()
        }

        func updateUIViewController(_ controller: CABTMIDICentralViewController, context: Context) {}
    }
#endif
