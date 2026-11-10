import Foundation
import Darwin
import AVFoundation
import TDJCore

/// Analyse a frozen device inventory and retain each result before cloud delivery.
enum MacLibraryAnalysis {
    struct Item: Codable {
        let id: String
        let title: String
        let artist: String
        let paths: [String]
        let expected: Track?
    }
    struct Manifest: Codable {
        let items: [Item]
    }
    struct Result: Codable {
        let id: String
        let profile: DeepAnalysisProfile
        var source: String?
        var audioSHA256: String?
        var identityMatches: Bool?
        var firstPass: AudioAnalysis?
        var deep: DeepBeatAnalysis?
        var finalAnalysis: AudioAnalysis?
        var decodeSeconds: Double?
        var firstPassSeconds: Double?
        var deepSeconds: Double?
        var revisionID: String?
        var seconds: Double?
        var error: String?
    }

    static func run(manifestURL: URL, output: URL) async throws {
        let input = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(Manifest.self, from: input)
        guard !manifest.items.isEmpty, Set(manifest.items.map(\.id)).count == manifest.items.count,
            manifest.items.allSatisfy({ !$0.id.isEmpty && $0.id.allSatisfy({ $0.isNumber || $0 == "-" }) })
        else { throw CoreError.invalidWorkspace("The library inventory is empty or has invalid identifiers.") }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let lock = open(output.appendingPathComponent("run.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard lock >= 0 else { throw CoreError.invalidWorkspace("Cannot open the library run lock.") }
        defer { close(lock) }
        guard flock(lock, LOCK_EX | LOCK_NB) == 0 else {
            throw CoreError.invalidWorkspace("This library run is already active.")
        }
        let savedManifest = output.appendingPathComponent("manifest.json")
        if FileManager.default.fileExists(atPath: savedManifest.path) {
            guard try Data(contentsOf: savedManifest) == input else {
                throw CoreError.invalidWorkspace("The inventory changed. Choose a new output folder.")
            }
        } else { try input.write(to: savedManifest, options: .atomic) }
        let results = output.appendingPathComponent("results")
        try FileManager.default.createDirectory(at: results, withIntermediateDirectories: true)
        let vault = try CloudPreparationVault(root: output.appendingPathComponent("outbox"))
        let checkpointRoot = output.appendingPathComponent("checkpoints")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for (index, item) in manifest.items.enumerated() {
            try Task.checkCancellation()
            let resultURL = results.appendingPathComponent(item.id + ".json")
            if let data = try? Data(contentsOf: resultURL),
                let saved = try? JSONDecoder().decode(Result.self, from: data),
                saved.profile == DeepAnalysisProfile.current, saved.error == nil,
                let revisionID = saved.revisionID, (try? vault.read(revisionID)) != nil
            { continue }
            var result = Result(id: item.id, profile: .current)
            let started = Date()
            let audio = output.appendingPathComponent("current-" + item.id + ".caf")
            do {
                guard item.expected != nil || item.paths.count == 1 else {
                    throw CoreError.invalidAudio("The device has no saved audio identity and multiple source candidates. This track needs review.")
                }
                var selected: String?
                for path in item.paths {
                    let inputAudio = try AVAudioFile(forReading: URL(fileURLWithPath: path))
                    let decodedBytes = Double(inputAudio.length) * Double(inputAudio.processingFormat.channelCount) * 4
                    let attributes = try FileManager.default.attributesOfFileSystem(forPath: output.path)
                    let freeBytes = (attributes[.systemFreeSize] as? NSNumber)?.doubleValue ?? 0
                    guard freeBytes > decodedBytes + 5 * 1024 * 1024 * 1024 else {
                        throw CoreError.invalidWorkspace("The analysis volume has insufficient free space for this decoded track.")
                    }
                    if FileManager.default.fileExists(atPath: audio.path) {
                        try FileManager.default.removeItem(at: audio)
                    }
                    try await MusicLibraryAudio.decodeAsset(url: URL(fileURLWithPath: path), destination: audio)
                    let hash = try MacAnalysisAudit.digest(audio)
                    result.audioSHA256 = hash
                    if let expected = item.expected, hash != expected.analysis.contentSHA256 { continue }
                    selected = path
                    break
                }
                guard let selected else {
                    throw CoreError.invalidAudio("No source matches the device audio identity. This result was not queued for sharing.")
                }
                result.source = selected
                result.identityMatches = item.expected.map { $0.analysis.contentSHA256 == result.audioSHA256 }
                result.decodeSeconds = Date().timeIntervalSince(started)
                let firstStarted = Date()
                let first: AudioAnalysis
                if let data = try? Data(contentsOf: resultURL),
                    let saved = try? JSONDecoder().decode(Result.self, from: data),
                    saved.profile == .current, saved.audioSHA256 == result.audioSHA256,
                    let previous = saved.firstPass
                { first = previous } else {
                    first = try await AnalysisExecution.$foregroundLibrary.withValue(true) {
                        try await AnalysisWorker.shared.analyze(url: audio)
                    }.replacingWaveform([])
                }
                if let expected = item.expected {
                    guard first.sampleRate == expected.analysis.sampleRate,
                        first.frameCount == expected.analysis.frameCount,
                        first.channelCount == expected.analysis.channelCount
                    else { throw CoreError.invalidAudio("The decoded audio dimensions differ from the device. This result was not shared.") }
                }
                result.firstPass = first
                result.firstPassSeconds = Date().timeIntervalSince(firstStarted)
                try encoder.encode(result).write(to: resultURL, options: .atomic)
                let deepStarted = Date()
                let deep = try await AnalysisWorker.shared.deepBeatAnalysis(
                    url: audio, matching: first, root: checkpointRoot)
                result.deep = deep
                result.deepSeconds = Date().timeIntervalSince(deepStarted)
                var track = try Track(title: item.title, artist: item.artist, mediaFilename: audio.lastPathComponent, analysis: first)
                track = try track.adoptingDeepAnalysis(deep)
                result.finalAnalysis = track.analysis
                let archive = CloudPreparationArchive.analysisOnly(track: track, arrangement: nil)
                if let expected = item.expected, !archive.matches(expected) {
                    throw CoreError.invalidAudio("The archive does not match the device audio. This result was not shared.")
                }
                result.revisionID = try vault.retain(archive).id
            } catch {
                result.error = error.localizedDescription
            }
            result.seconds = Date().timeIntervalSince(started)
            try encoder.encode(result).write(to: resultURL, options: .atomic)
            if FileManager.default.fileExists(atPath: audio.path) { try FileManager.default.removeItem(at: audio) }
            let status = result.error ?? "Saved for sharing"
            FileHandle.standardOutput.write(Data("\(Date().ISO8601Format()) \(index + 1)/\(manifest.items.count) \(item.title): \(status)\n".utf8))
        }
        try Data(Date().ISO8601Format().utf8).write(to: output.appendingPathComponent("finished.txt"), options: .atomic)
    }
}
