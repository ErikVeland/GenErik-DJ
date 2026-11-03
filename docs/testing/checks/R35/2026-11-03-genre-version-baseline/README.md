# R35: First genre and version baseline

Analysed 99 of 104 selected entries. Five entries failed. The set contains 102 unique source hashes.

The first 96 entries rotate available version types across ten metadata sampling families. Eight explicit 12-inch recordings supplement the saved-device selection.

## Findings to review

| Review signal | Entries |
| --- | ---: |
| More than four sections per minute | 79 |
| Detected vocals without verse/chorus/bridge roles | 84 |
| Tempo differs from an unverified imported reference | 46 |
| Half/double-tempo relation to an unverified reference | 19 |
| Key differs from an unverified imported reference | 36 |
| No key assigned | 18 |
| Analysis failed | 5 |

These signals overlap. They are not accuracy scores. A long instrumental piece may correctly have no chorus.
The role model assigned a chorus on only one of the 99 successful entries. Vocal form remained unassigned on 84 entries.
This is evidence of limited assignment coverage. Independent annotations are needed to count true misses and false assignments.

All 99 successful analyses match the exact input hash and have ordered, in-range section timelines.
That confirms source and timeline integrity. It does not establish musical correctness.

## Sampling coverage

| Metadata family | Entries | Analysed | Vocal form unassigned | Many short sections |
| --- | ---: | ---: | ---: | ---: |
| ambient-downtempo | 10 | 10 | 9 | 8 |
| drum-bass-breaks | 10 | 8 | 5 | 8 |
| electronic-other | 10 | 10 | 8 | 4 |
| hiphop-rnb-soul | 11 | 11 | 11 | 11 |
| house-disco | 11 | 10 | 9 | 7 |
| mashup | 10 | 10 | 10 | 9 |
| pop-rock | 11 | 11 | 8 | 7 |
| reggae-latin-afro | 9 | 9 | 9 | 9 |
| techno-trance | 9 | 9 | 5 | 7 |
| unclassified | 13 | 11 | 10 | 9 |

Families are metadata hints. Several tags are missing or broad. They have not been validated from audio.
Two duplicate source hashes remain visible in the raw selection. Final scoring must deduplicate them.
Related-title split assignments are provisional. Confirm recording families before using the held-out split for accuracy claims.

## First review queue

| Recording | Review task |
| --- | --- |
| GenErik — Zombie Thumper (Die Antwoord x Kernkraft 400) | Check the musical pulse and downbeat against the imported reference. |
| Scooter — Endless Summer (Datura Instrumental Version) | Check the musical pulse and downbeat against the imported reference. |
| Twin Shadow — Shooting Holes | Check the musical pulse and downbeat against the imported reference. |
| Dan Croll — From Nowhere (Baardsen Remix) | Mark true section roles and merge internal events into phrases where appropriate. |
| Destiny's Child — Bug a Boo (A Cappella) | Mark true section roles and merge internal events into phrases where appropriate. |
| GenErik — Matt Berry - Theme From Snuff Box (GenErik EXPLICIT Extended Edit) | Mark true section roles and merge internal events into phrases where appropriate. |
| Fred again.. — Jungle (acapella) | Check whether predicted boundaries are phrases, fills or full sections. |
| Vampire Weekend — White Sky (Basement Jaxx Vamp Dub Mix) | Check whether predicted boundaries are phrases, fills or full sections. |
| Jamelia — Superstar (Tomcio & Robin Roij Remix) | Check whether predicted boundaries are phrases, fills or full sections. |

The complete timecoded prediction set and blank review fields are in `review.json`.
All entries remain unreviewed. No success or failure labels were invented.

## Failed and incomplete work

The first two batch attempts stopped after repeated failures in the new helper. It read beyond the declared audio length.
A temporary FFmpeg decode attempt did not fix that helper error and was removed. Both failed reports remain retained.
The corrected helper then ran on the original audio files with the production analyser and structure code.
Five entries still failed during production musical analysis, before the helper cache stage. Their exact errors remain in `review.json`.

## Next engine work

Review a small set of timecoded examples from each family and version type. Record true boundaries and roles separately.
Evaluate a phrase/section hierarchy and a trained role model against this baseline. Include instrumental grooves and extended mixing passages.
Count unresolved true sections as misses. Report precision, recall and coverage by genre and version.
Keep related versions together and reserve reviewed recordings for final evaluation.

The current iPad build changes label presentation only. Genre-aware recognition remains R35 work.
