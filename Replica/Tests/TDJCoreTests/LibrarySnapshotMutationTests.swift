import Foundation
import Testing
import TDJCore

private func mutationInput() throws -> [Track] {
    let json = """
    {"implementation":"mutation-test","configurationID":"mutation-test","contentSHA256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","sampleRate":48000,"frameCount":48000,"channelCount":2,"waveformFramesPerBin":512,"waveform":[],"bpm":120,"beatAnchorFrame":0,"tempoConfidence":1,"keyConfidence":0,"chroma":[],"timbre":[]}
    """
    let analysis = try JSONDecoder().decode(AudioAnalysis.self, from: Data(json.utf8))
    return try (0..<1024).map { number in
        try Track(title: "Mutation value \(number): " + String(repeating: "m", count: 80),
            mediaFilename: "mutation.caf", analysis: analysis)
    }
}
private func mutationMilliseconds(_ duration: Duration) -> Double {
    let value = duration.components
    return Double(value.seconds) * 1000 + Double(value.attoseconds) / 1e15
}
@Test func snapshotAppendKeepsPlainArrayScaling() throws {
    let input = try mutationInput()
    let clock = ContinuousClock()
    var plain: [Double] = [], observed: [Double] = []
    for _ in 0..<3 {
        var array: [Track] = []
        array.reserveCapacity(input.count)
        let plainStart = clock.now
        for value in input { array.append(value) }
        plain.append(mutationMilliseconds(plainStart.duration(to: clock.now)))
        #expect(array == input)
        var snapshot = LibrarySnapshot()
        snapshot.tracks.reserveCapacity(input.count)
        let observedStart = clock.now
        for value in input { snapshot.tracks.append(value) }
        observed.append(mutationMilliseconds(observedStart.duration(to: clock.now)))
        #expect(snapshot.tracks == input)
    }
    let ratio = observed.sorted()[1] / max(plain.sorted()[1], 0.001)
    print("SNAPSHOT_MUTATION append plain=\(plain) snapshot=\(observed) ratio=\(ratio) diagnosticScaling=true audioAcceptance=false")
    #expect(ratio < 50, "Snapshot append must preserve normal array scaling. This is separate from the 20 ms audio/control gate.")
}
@Test func snapshotNestedEditsKeepPlainArrayScalingAndCopyIsolation() throws {
    let input = try mutationInput()
    let clock = ContinuousClock()
    var plain: [Double] = [], observed: [Double] = []
    for _ in 0..<3 {
        var array = input
        let plainStart = clock.now
        for index in array.indices { array[index].artist = "Changed artist" }
        plain.append(mutationMilliseconds(plainStart.duration(to: clock.now)))
        var original = LibrarySnapshot()
        original.tracks = input
        var changed = original
        let observedStart = clock.now
        for index in changed.tracks.indices { changed.tracks[index].artist = "Changed artist" }
        observed.append(mutationMilliseconds(observedStart.duration(to: clock.now)))
        #expect(changed.tracks == array)
        #expect(original.tracks == input)
        #expect(original.tracks.allSatisfy { $0.artist.isEmpty })
    }
    let ratio = observed.sorted()[1] / max(plain.sorted()[1], 0.001)
    print("SNAPSHOT_MUTATION nested plain=\(plain) snapshot=\(observed) ratio=\(ratio) diagnosticScaling=true audioAcceptance=false")
    #expect(ratio < 50, "Nested edits must preserve array copy-on-write without repeated full-array copies.")
}
@Test func snapshotMutationCodecPreservesSixAAGoldenBytes() throws {
    var snapshot = LibrarySnapshot()
    snapshot.schemaVersion = 2
    snapshot.revision = 17
    snapshot.tracks = [try #require(mutationInput().first)]
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(snapshot)
    let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/LibraryMutationSnapshot.json")
    #expect(data == (try Data(contentsOf: fixture)))
    #expect(try JSONDecoder().decode(LibrarySnapshot.self, from: data) == snapshot)
}
