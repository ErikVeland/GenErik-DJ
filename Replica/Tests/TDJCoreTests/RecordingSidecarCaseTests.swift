import Foundation
import Testing
import TDJCore

@Test(arguments: ["CaseMix.TXT", "casemix.txt"])
func savedRecordingTracklistsFollowFilesystemCaseRules(sidecarName: String) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let audio = root.appendingPathComponent("CaseMix.aiff")
    try Data().write(to: audio)
    try Data().write(to: root.appendingPathComponent(sidecarName))
    let derived = audio.deletingPathExtension().appendingPathExtension("txt")
    let resolved = (try? derived.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    let snapshot = SetRecorder.savedRecordingSnapshot(in: root)
    let listed = try #require(snapshot.recordings.first)
    #expect((snapshot.tracklists[listed] != nil) == resolved)
}
