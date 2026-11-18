"""Separate manual SEVENTY subsets from independently pinned owner exports."""
from curated import add, profile

SEVENTY_DISCUSSION = "https://community.algoriddim.com/t/rane-seventy-mapping-ideas-and-problems/33289"
ATRAK_DISCUSSION = "https://community.algoriddim.com/t/rane-seventy-a-trak-signature-edition-midi-mapping/17493"
SEVENTY_SOURCES = [
    ("Rane SEVENTY", "Rane-Seventy-owner.djayMidiMapping",
     "https://community.algoriddim.com/uploads/short-url/f1nlupY4MmdavUHDCL24CsgTphF.djayMidiMa",
     "9dce98328dc0e80de99f6a21dafc5d5793db2c100aa30ad9255a55d9351d7748"),
    ("Rane SEVENTY A-Trak Edition", "Rane-Seventy-A-Trak-4.0.10.djayMidiMapping",
     "https://drive.google.com/file/d/1iwbUvILPV4mcrKTN--qtOQNNYEEo8Sni/view",
     "9deebda7d70995c5d21ed5a41c8fc83053fbe044faf6b55d516fd05e0096bc74"),
]
SEVENTY_REFERENCES = {}
SEVENTY_AUDITS = {}
for index, (name, filename, url, digest) in enumerate(SEVENTY_SOURCES):
    SEVENTY_REFERENCES[name] = {
        "url":url,"sha256":digest,
        "relatedSources":[{"url":ATRAK_DISCUSSION if index else SEVENTY_DISCUSSION}],
        "review":"The standard owner export is version8/djay Pro5.2.6 with621 rows, one heading and323 non-empty output dictionaries. The A-Trak author export is version6/djay4.0.10 with488 rows and298 non-empty output dictionaries. Both declare USB1CC5:0020/0021, endpoint names Rane Seventy MIDI/Seventy A-Trak MIDI and absent RaneSeventy custom code. Each profile uses its own pinned export. Common unconditional controls are Load2/3 on channel15, Sync2 on channels0/1, loop-channel4/5 On64/Reloop65/Half52/Double53/In54/Out55 and global15 flipped rotary64 BrowseCC0/GroupsCC1 with BackNote7. Standard owner alone adds yellow Transport-sub-mode Play103/Sync101/held bends96/97 on channels4/5. This custom layout requires that hardware sub-mode; it is not factory normal transport. Numbered cuePositionOrJumpConsideringPlayState1 is not assumed to mean held main Cue. Shared-pad/modifier translation, external line-volume/hardware mixer ownership and external deck/FX audio remain unqualified. Conditional placeholder outputs and custom pad colours do not establish complete feedback. No class, downloaded map, setup, output or audio-route packet runs in the app. Automatic selection stays off. Normal Cue/transport, full modes, lifecycle, routing and physical acceptance remain open.",
    }
    SEVENTY_AUDITS[name] = {
        "source":{"url":url,"sha256":digest},
        "discussion":ATRAK_DISCUSSION if index else SEVENTY_DISCUSSION,
        "format":"Apple property list","mappingVersion":6 if index else 8,
        "inputRows":488 if index else 621,"headingRows":0 if index else 1,
        "nonEmptyOutputRows":298 if index else 323,"declaredCustomClass":"RaneSeventy",
        "automaticSupportAdded":False,
        "gaps":["The RaneSeventy class is absent. Modifier/shared-pad translation, cold-start setup, hardware mixer ownership and external deck/FX audio routing remain unqualified. Independent manual subsets do not establish automatic selection or complete theoretical support."],
    }


def seventy_profiles():
    results = []
    for index, (name, _, url, _) in enumerate(SEVENTY_SOURCES):
        result = profile(name,url)
        result["autoSelect"] = False
        result["definition"] = "reviewed:rane-seventy-a-trak" if index else "reviewed:rane-seventy"
        result["aliases"].append("Seventy A-Trak MIDI" if index else "Rane Seventy MIDI")
        result["excludedAliases"] = ["RANE SEVENTY-TWO","RANE SEVENTY-TWO MKII",SEVENTY_SOURCES[1-index][0]]
        result["hardwareMode"] = "Manual subset. Enable input separately and select the connected USB A/B source. Missing class/setup and external mixer audio remain open."
        result["scope"] = "Manual Load, Sync, loop controls and flipped browsing. " + (
            "Shared pads, transport, feedback, setup and audio routing remain open." if index else
            "Owner yellow Transport sub-mode adds Play/Sync/held bends. Shared pads, Cue, feedback, setup and audio routing remain open.")
        for side, deck in enumerate("ab"):
            add(result,"load",15,2+side,deck=deck)
            add(result,"sync",side,2,deck=deck)
            for action,number in [("loop",64),("reloop",65),("loopDown",52),("loopUp",53),("loopIn",54),("loopOut",55)]:
                add(result,action,side+4,number,deck=deck)
            if not index:
                for action,number in [("play",103),("sync",101),("pitchBendDown",96),("pitchBendUp",97)]:
                    add(result,action,side+4,number,deck=deck)
        for action,number in [("browse",0),("browseGroups",1)]:
            add(result,action,15,number,"control","binaryOffset")
            result["inputs"][-1]["inverted"] = True
        add(result,"openGroup",15,7)
        result["gaps"] = ["Manual subset requires separate input enabling and the connected USB A/B source. Missing RaneSeventy code leaves modifier/shared-pad dispatch and cold-start lifecycle unqualified. Standard-owner yellow Transport sub-mode actions are not inherited by the A-Trak profile. Main Cue, other pads, external line-volume/mixer ownership, external deck/FX audio, feedback, complete theoretical support and physical acceptance remain open."]
        results.append(result)
    return results
