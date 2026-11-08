import SwiftUI

/// The known lesson topics are available beside the decks. Original discovery rules remain unverified.
struct GestureHelp: View {
    let close: () -> Void
    @State private var selected: GestureLesson?
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Gesture guide").font(.headline)
                Spacer()
                Button(action: close) { Image(systemName: "xmark") }.accessibilityLabel("Close help")
            }.padding(12)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let selected {
                        Button {
                            self.selected = nil
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                        Text(selected.title).font(.headline)
                        ForEach(Array(selected.steps.enumerated()), id: \.offset) { index, step in
                            Text("\(index+1). \(step)").frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        ForEach(GestureLesson.allCases) { lesson in
                            Button {
                                selected = lesson
                            } label: {
                                HStack {
                                    Text(lesson.title).multilineTextAlignment(.leading)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption)
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
                            }
                        }
                    }
                }.font(.callout).padding(12)
            }
        }.frame(maxHeight: .infinity).background(Color(white: 0.09)).foregroundStyle(Color(white: 0.9))
    }
}

private enum GestureLesson: String, CaseIterable, Identifiable {
    case browse, recommended, tempo, navigate, loop, grid, freeze, cues, effects, lock, record
    var id: Self { self }
    var title: String {
        switch self {
        case .browse: "Swipe-open the Browser"
        case .recommended: "Get Track Recommendations"
        case .tempo: "Change the Tempo"
        case .navigate: "Navigate around the Track"
        case .loop: "Unlock a Loop"
        case .grid: "Fix a BeatGrid"
        case .freeze: "Trigger Beats in Freeze Mode"
        case .cues: "Set a Cue Point"
        case .effects: "Select an Effect"
        case .lock: "Lock an Effect or Filter"
        case .record: "Record Your Mix"
        }
    }
    var steps: [String] {
        switch self {
        case .browse:
            ["Swipe upward on a waveform to open Songs.", "Select a song, then drag LOAD up for A or down for B."]
        case .recommended:
            [
                "Open Songs and select a track.",
                "Choose Suggestions → A or Suggestions → B from the recommendations menu.",
                "The other deck must have a loaded track to provide a reference.",
            ]
        case .tempo:
            [
                "Open the master tempo wheel.",
                "Turn around its edge to change the tempo of synced decks. Lift before starting another turn.",
            ]
        case .navigate:
            [
                "Drag the overview stripe to inspect another passage. Pinch it to change the visible scale.",
                "Tap a beat in the main waveform to schedule a jump there.",
            ]
        case .loop:
            [
                "Place two fingers on the waveform to create a loop. Move both fingers to move it; pinch or spread to resize it.",
                "Swipe down with both fingers and release, or tap LOOP, to leave the loop.",
            ]
        case .grid:
            [
                "Open the grid editor with the flag. Drag the waveform against the grid.",
                "Use half, double, TAP and the downbeat selector to correct the grid. Grid marker cues are white.",
            ]
        case .freeze:
            [
                "Tap the snowflake to hold the displayed region while playback continues.",
                "Press and hold slices to repeat them. Enable Freeze inside a loop for Loop Slicer.",
                "Use the three selectors beside the slices to choose Loop Stutter, Turntablism or Pitch. Turntablism has Brake, Scratch and Reverse regions; Pitch has Pitch Up, Slice and Pitch Down regions. Tap the snowflake again to leave.",
            ]
        case .cues:
            [
                "Open Hotcues with the flag below the waveform. Tap an empty slot to save a position or the active loop; tap an occupied slot to recall it.",
                "Turn on the trash control, then tap a slot to remove it. Removing a grid cue preserves the track’s beat grid.",
            ]
        case .effects:
            [
                "Open FX and tap one of the three effect tabs to select the effect controlled by the shared pad.",
                "Tap the selected tab again, or hold and drag downward, to choose an effect. Move horizontally on the pad for its parameter and vertically for the mix.",
            ]
        case .lock:
            [
                "Lock a filter or effect to retain it after lifting your finger.",
                "For EQ, hold one position and add a second contact for a temporary change. Lift the extra contact to restore the first value.",
            ]
        case .record:
            [
                "Choose Record to capture the master output. Choose Stop recording to finish the AIFF file.",
                "Open Recordings to share a saved set or load it into a stopped deck.",
            ]
        }
    }
}
