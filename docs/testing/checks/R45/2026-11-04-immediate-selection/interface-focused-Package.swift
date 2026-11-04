// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GenErikDJ",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products:[.library(name:"TDJInterface",targets:["TDJInterface"])],
    targets: [
        .binaryTarget(name: "whisper",
            url: "https://github.com/ggml-org/whisper.cpp/releases/download/v1.8.7/whisper-v1.8.7-xcframework.zip",
            checksum: "501076a091bf4b2d76ec92df9dd13278382dfb266b82bbd438c210a21c10b84c"),
        .target(name: "CTDJTransport", exclude: ["Vendor/signalsmith-stretch/README.md", "Vendor/signalsmith-stretch/LICENSE.txt",
            "Vendor/signalsmith-linear/README.md", "Vendor/signalsmith-linear/LICENSE.txt"],
            cSettings: [.unsafeFlags(["-O3"])],
            cxxSettings: [.headerSearchPath("Vendor"), .unsafeFlags(["-O3"])], linkerSettings: [.linkedFramework("Accelerate")]),
        .target(name: "CTDJAudioSource", dependencies: ["CTDJTransport"],
                cxxSettings: [.unsafeFlags(["-O3", "-fobjc-arc"])],
                linkerSettings: [.linkedFramework("AVFoundation"), .linkedFramework("Foundation")]),
        .target(name: "TDJCore", dependencies: ["CTDJTransport"]),
        .target(name: "TDJInterface", dependencies: ["TDJCore", "CTDJAudioSource", "whisper"],
                resources: [.process("Resources"), .copy("StemModelAssets"), .copy("VocalModelAssets")]),
.testTarget(name:"TDJInterfaceTests",dependencies:["TDJCore","TDJInterface"],exclude:["FilterPadContactTests.swift", "ModelLibraryStorageTests.swift", "FreeRateContinuityTests.swift", "DeckToolsTests.swift", "EffectPadGestureTests.swift", "BrowserPaneStackTests.swift", "RetainedMixerPaneTests.swift", "PlaybackControlDisplayTests.swift", "SecurityScopedFileAccessTests.swift", "RecordingWorkflowTests.swift", "MouseContactLifecycleTests.swift", "LoadSliderGestureTests.swift", "WorkflowTests.swift", "PanelInputGateTests.swift", "VinylBrakeGestureTests.swift", "RuntimeEffectControlAccessTests.swift", "Z1EffectWorkflowTests.swift", "StreamedPlaybackIntegrationTests.swift", "ArrangementIntegrationTests.swift", "OutputRouteContinuityTests.swift", "MusicImportCleanupTests.swift", "ControlMaintenanceTests.swift", "LibraryLookupPublicationTests.swift", "LibraryLookupScalabilityTests.swift", "AdaptiveGridEditorTests.swift", "EffectControlDisplayTests.swift", "PreparationLoadPinTests.swift", "SuperSlicerGestureTests.swift", "ColdPlayCancellationTests.swift", "RecoveryIntegrationTests.swift", "LibraryBrowserFixTests.swift", "LibraryBrowserRequestTests.swift", "EffectDelayDisplayTests.swift", "GridContactTests.swift", "BrowserLayoutStateTests.swift", "WaveformScratchContinuityTests.swift", "AdaptiveDeckGeometryTests.swift", "RuntimeFilterContactSessionTests.swift", "ControllerMIDIProfileTests.swift", "LoadReadinessPersistenceTests.swift", "WarmPlaySubmissionTests.swift", "TourScreensTests.swift", "PaneDismissGestureTests.swift", "EffectSelectorGestureTests.swift", "PairHistoryWorkflowTests.swift", "GestureWorkflowTests.swift", "NativeMusicLoadOwnershipTests.swift", "FaderLiveInputTests.swift", "BackgroundFileWorkTests.swift", "TempoWheelResetTests.swift", "NativeMusicSourceRecoveryTests.swift", "VerticalFaderGestureTests.swift", "ArtworkTests.swift", "BackgroundWorkValueTests.swift", "LibraryBrowserPlaylistSaveTests.swift", "MusicLibraryWorkflowTests.swift"],sources:["FirstUseNativePlaybackTests.swift", "InstantTrackLoadTests.swift", "BackgroundPreparationTests.swift"])
    ],
    cxxLanguageStandard: .cxx17
)
