import AppKit
import SwiftUI
import TDJCore
import TDJInterface

@main struct PreviewMain {
    @MainActor static func main() async {
        if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--analysis-audit" {
            do {
                try await MacAnalysisAudit.run(
                    manifestURL: URL(fileURLWithPath: CommandLine.arguments[2]),
                    output: URL(fileURLWithPath: CommandLine.arguments[3], isDirectory: true))
            } catch {
                FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
                exit(1)
            }
            return
        }
        if CommandLine.arguments.count == 3,
            [
                "--snapshot", "--snapshot-browser", "--snapshot-help", "--snapshot-fx", "--snapshot-panels",
                "--snapshot-superslicer", "--snapshot-slicer-loop",
            ].contains(CommandLine.arguments[1])
        {
            do {
                let model = try ReplicaModel(root: workspaceRoot, discoverSyncedTraktor: true)
                if let first = model.library.tracks.first {
                    model.loaded[.a] = first.id
                    model.editing.insert(.a)
                }
                if model.library.tracks.count > 1 { model.loaded[.b] = model.library.tracks[1].id }
                if CommandLine.arguments[1] == "--snapshot-help" { model.helpVisible = true }
                if CommandLine.arguments[1] == "--snapshot-browser" {
                    model.showLibrary()
                    model.selectedTrackID = model.library.tracks.first?.id
                }
                let panels = CommandLine.arguments[1] == "--snapshot-panels"
                if panels || CommandLine.arguments[1] == "--snapshot-fx" {
                    for deck in DeckID.allCases {
                        if let track = model.track(deck) {
                            model.viewport[deck] = Double(track.analysis.frameCount) / 2
                        }
                    }
                }
                if ["--snapshot-superslicer", "--snapshot-slicer-loop"].contains(CommandLine.arguments[1]) {
                    model.editing.removeAll()
                    for deck in DeckID.allCases {
                        model.frozen.insert(deck)
                        if let track = model.track(deck) {
                            model.viewport[deck] = Double(track.analysis.frameCount) / 2
                        }
                    }
                    model.superSlicerFamilies[.a] =
                        CommandLine.arguments[1] == "--snapshot-slicer-loop" ? .loopStutter : .turntablism
                    model.superSlicerFamilies[.b] = .pitch
                }
                let content = try await ReplicaView(
                    model: model,
                    snapshotEffectsDeck: panels ? .b : CommandLine.arguments[1] == "--snapshot-fx" ? .a : nil,
                    snapshotMixerDecks: panels ? [.a, .b] : [], snapshotFilterDecks: panels ? [.a] : []
                ).preparedForSnapshot()
                let renderer = ImageRenderer(content: content.frame(width: 1024, height: 768))
                renderer.scale = 1
                guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                    let bitmap = NSBitmapImageRep(data: tiff),
                    let data = bitmap.representation(using: .png, properties: [:])
                else { throw CocoaError(.fileWriteUnknown) }
                try data.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
            } catch {
                FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
                exit(1)
            }
        } else {
            PreviewApp.main()
        }
    }
    static var workspaceRoot: URL {
        DevelopmentWorkspace.resolve(
            override: ProcessInfo.processInfo.environment["TDJ_WORKSPACE"], bundleURL: Bundle.main.bundleURL,
            currentDirectory: FileManager.default.currentDirectoryPath)
    }
}

struct PreviewApp: App {
    @NSApplicationDelegateAdaptor(ReplicaLifecycle.self) private var lifecycle
    var body: some Scene {
        WindowGroup("GenErik DJ · Development") {
            Group {
                if let model = try? ReplicaModel(root: PreviewMain.workspaceRoot, discoverSyncedTraktor: true) {
                    ReplicaView(model: model)
                } else {
                    Text("Cannot open the development workspace. Its original files were retained.").padding(30)
                }
            }.frame(minWidth: 800, minHeight: 600)
        }.defaultSize(width: 1024, height: 768)
    }
}
