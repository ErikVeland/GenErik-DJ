import Testing
@testable import TDJCore

@Test func displayKeyNotationRoundTripsEveryTonicAndMode() throws {
    for tonic in 0..<12 {
        for mode in [MusicalKey.Mode.major, .minor] {
            let key = MusicalKey(tonic: tonic, mode: mode)
            for notation in [KeyNotation.camelot, .openKey, .musical] {
                #expect(try notation.parse(notation.format(key)) == key)
            }
        }
    }
    let key = MusicalKey(tonic: 9, mode: .minor)
    #expect(KeyNotation.camelot.format(key) == "8A")
    #expect(KeyNotation.openKey.format(key) == "1m")
    #expect(KeyNotation.musical.format(key) == "Am")
}
