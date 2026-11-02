import Testing
import TDJRuntimeChecks

@Test func diagnosticLaunchRequiresAnExplicitSingleSupportedPreset() throws {
    #expect(try AudioRuntimeCheckLaunch.parse(arguments:["app","-ApplePersistenceIgnoreState","YES"]) == nil)
    #expect(try AudioRuntimeCheckLaunch.parse(arguments:["app","--audio-check=loop60"]) == .loop60)
    let longLoop=try AudioRuntimeCheckLaunch.parse(arguments:["app","--audio-check=loop300"])
    #expect(longLoop == .loop300 && longLoop?.durationSeconds == 300)
    #expect(longLoop?.sequential == false && longLoop?.liveInterface == false)
    #expect(AudioRuntimeCheckLaunch.loop60.durationSeconds == 60 && AudioRuntimeCheckLaunch.ui60.durationSeconds == 60)
    #expect(AudioRuntimeCheckLaunch.sequential300.durationSeconds == 300)
    #expect(try AudioRuntimeCheckLaunch.parse(arguments:["app","--audio-check=sequential300"])?.sequential == true)
    #expect(try AudioRuntimeCheckLaunch.parse(arguments:["app","--audio-check=ui60"])?.liveInterface == true)
    for argument in ["--audio-check","--audio-check=","--audio-check=3600","--audio-check=loop60-extra"] {
        #expect(throws:AudioRuntimeCheckLaunch.InvalidArgument.self) {
            try AudioRuntimeCheckLaunch.parse(arguments:["app",argument])
        }
    }
    #expect(throws:AudioRuntimeCheckLaunch.InvalidArgument.self) {
        try AudioRuntimeCheckLaunch.parse(arguments:["app","--audio-check=loop60","--audio-check=sequential300"])
    }
}
