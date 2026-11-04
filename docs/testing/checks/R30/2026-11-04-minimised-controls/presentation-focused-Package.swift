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
.testTarget(name:"TDJInterfaceTests",dependencies:["TDJCore","TDJInterface"],exclude:["AdaptiveDeckGeometryTests.swift", "AdaptiveGridEditorTests.swift", "ArrangementIntegrationTests.swift", "ArtworkTests.swift", "BackgroundFileWorkTests.swift", "BackgroundPreparationTests.swift", "BackgroundWorkValueTests.swift", "BrowserLayoutStateTests.swift", "BrowserPaneStackTests.swift", "ColdPlayCancellationTests.swift", "ControlMaintenanceTests.swift", "ControllerMIDIProfileTests.swift", "DeckToolsTests.swift", "EffectControlDisplayTests.swift", "EffectDelayDisplayTests.swift", "EffectPadGestureTests.swift", "EffectSelectorGestureTests.swift", "FaderLiveInputTests.swift", "FilterPadContactTests.swift", "FirstUseNativePlaybackTests.swift", "FreeRateContinuityTests.swift", "GestureWorkflowTests.swift", "GridContactTests.swift", "InstantTrackLoadTests.swift", "LibraryBrowserFixTests.swift", "LibraryBrowserPlaylistSaveTests.swift", "LibraryBrowserRequestTests.swift", "LibraryLookupPublicationTests.swift", "LibraryLookupScalabilityTests.swift", "LoadReadinessPersistenceTests.swift", "LoadSliderGestureTests.swift", "ModelLibraryStorageTests.swift", "MouseContactLifecycleTests.swift", "MusicImportCleanupTests.swift", "MusicLibraryWorkflowTests.swift", "NativeMusicLoadOwnershipTests.swift", "NativeMusicSourceRecoveryTests.swift", "OutputRouteContinuityTests.swift", "PairHistoryWorkflowTests.swift", "PaneDismissGestureTests.swift", "PanelInputGateTests.swift", "PlaybackControlDisplayTests.swift", "PreparationLoadPinTests.swift", "RecordingWorkflowTests.swift", "RecoveryIntegrationTests.swift", "RetainedMixerPaneTests.swift", "RuntimeEffectControlAccessTests.swift", "RuntimeFilterContactSessionTests.swift", "SecurityScopedFileAccessTests.swift", "StreamedPlaybackIntegrationTests.swift", "SuperSlicerGestureTests.swift", "TempoWheelResetTests.swift", "TourScreensTests.swift", "VerticalFaderGestureTests.swift", "VinylBrakeGestureTests.swift", "WarmPlaySubmissionTests.swift", "WaveformScratchContinuityTests.swift", "WorkflowTests.swift", "Z1EffectWorkflowTests.swift"],sources:["DeckSpaceRenderingTests.swift", "DeckBrowserPresentationTests.swift", "SectionColourRenderingTests.swift"])
    ],
    cxxLanguageStandard: .cxx17
)
