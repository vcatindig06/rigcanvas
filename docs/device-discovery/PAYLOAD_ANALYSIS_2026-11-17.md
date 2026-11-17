# Payload-enabled Android BTSnoop analysis — 2026-11-17

## Evidence source and handling

This note analyzes the owner-provided payload-included RigCanvas JSON export for the selected BLE connection:

- Report type: RigCanvas filtered Android BTSnoop ATT analysis.
- BTSnoop v1, HCI UART/H4 data-link type 1002.
- 1,195 packets in the source capture.
- Selected connection handle: 0x0200; frames 350–1,194.
- 330 ATT events.
- The peer address is redacted and unrelated Bluetooth connections are excluded.
- ATT payload bytes are included.
- The report's advertising-name identity field is false and its deviceName is null.

The two uploaded files named Bug Report.txt and Bug Report2.txt have identical SHA-256 hashes and identical contents. They are duplicate copies of this same report, not two independent captures or two separate payload modes.

This event window matches the 330-event, frames 350–1,194 session documented in TRACE_ANALYSIS_2026-11-17.md. This is the payload-enabled companion evidence for that session. The separate short 13-event report from frames 296–339 is a different selected-connection window and must not be merged into these event counts.

## Capture totals

| Measure | Observed |
|---|---:|
| ATT events | 330 |
| Phone-to-pedal Write Request | 1 |
| Phone-to-pedal Write Commands | 157 |
| Pedal-to-phone Handle Value Notifications | 165 |
| Exchange MTU Requests | 2 |
| Exchange MTU Responses | 2 |
| Read By Type Requests | 1 |
| ATT Error Responses | 1 |
| Simple Read Requests/Responses | 0 |
| Successful service/characteristic declaration map | None in this report |

The report summary groups the one Write Request and 157 Write Commands as 158 write requests/commands. It reports 165 notifications and indications; the event list specifically identifies the observed server-to-client events as Handle Value Notifications (ATT opcode 0x1B).

## Device-identification evidence

At frame 390, the pedal sends a notification on attribute handle 0x0064 whose payload contains the ASCII string:

**KPTPRO_008**

This is direct evidence that the selected session's application payload contains that product-like identifier. It is stronger than the absent advertising name, but it is not cryptographic device authentication and does not independently establish hardware revision or firmware semantics. In particular, do not assume the suffix “008” means firmware v8 without a separate official identity field or controlled confirmation.

Owner-reported test context remains KPT Pro firmware v8 and M-EFCS Android v3.10.2311. Those versions are contextual owner reports, not fields independently decoded from this ATT report.

## ATT handle observations

### Handle 0x0065

- Frame 377: phone sends an ATT Write Request (opcode 0x12) to handle 0x0065 with value 01 00.
- Frame 380: pedal sends the ATT Write Response (opcode 0x13).

The write was acknowledged at the ATT layer. The value 01 00 is consistent with the standard Client Characteristic Configuration Descriptor value used to enable notifications. However, no successful characteristic/descriptor discovery map is present in this capture. Therefore, the descriptor identity and its relationship to handle 0x0064 remain highly plausible but unverified.

### Handle 0x0062

The phone sends 157 ATT Write Commands (opcode 0x52) to attribute handle 0x0062. ATT Write Commands do not receive an ATT Write Response, so their delivery or application-level success cannot be inferred from the absence of a response.

The observed command values contain recurring binary prefixes, including:

- 00 59 11 ...
- 00 59 23 08 ...

These are observed byte sequences only. Their fields, lengths, checksums, counters, and command meanings have not been decoded.

### Handle 0x0064

The pedal sends 165 Handle Value Notifications (opcode 0x1B) on attribute handle 0x0064. Notifications contain:

- the ASCII identifier KPTPRO_008;
- long blocks of null-padded, numbered model-name strings;
- repeating binary response-shaped values;
- at least one larger binary value with no confidently decoded field map.

The write/notification handle pairing is consistent with a write-without-response characteristic and a notify characteristic, but this capture's characteristicDiscovery object is empty. Do not mark 0x0062 as AE41 or 0x0064 as AE42 as confirmed from this session alone.

## Observed message patterns

The following sequence is visible in the supplied event list. The labels below are descriptive byte observations, not decoded operation names.

| Frame | Direction / ATT operation | Observed payload pattern | What is justified |
|---:|---|---|---|
| 377 | Phone / Write Request to 0x0065 | 01 00 | An ATT write was requested and acknowledged at frame 380 |
| 387 | Phone / Write Command to 0x0062 | 00 59 11 00 00 00 FF | A one-off short vendor-looking message was sent |
| 390 | Pedal / Notification from 0x0064 | 00 59 11 1B ... KPTPRO_008 ... | The response payload contains the identifier string |
| 391 | Phone / Write Command to 0x0062 | 00 59 23 08 ... | A different message pattern was sent |
| 394 | Pedal / Notification from 0x0064 | 00 59 23 28 ... | A notification followed; exact request correlation is not proven |
| 395 and 400 | Phone / Write Commands to 0x0062 | 00 59 23 08 ... with two recurring data tails | Two repeating write-value variants are present |
| 399 and 403 | Pedal / Notifications from 0x0064 | 00 59 23 40 ... and 00 59 23 12 ... | Two repeating notification-value variants are present |
| 413–440 | Pedal / Notifications from 0x0064 | Numbered, null-padded ASCII model names | A long speaker/cabinet-like model-name list is transferred |
| 450–477 | Pedal / Notifications from 0x0064 | Numbered CL/OD/DS and Bass-prefixed names | An amp/bass-related model-name list is transferred |
| 478 / 486 | Phone Write Command / pedal Notification | 00 59 23 08 ... followed by 00 59 23 96 ... | A larger binary response is visible; parameter field meanings remain unknown |

Two complete Write Command payload variants on handle 0x0062 each occur 76 times:

1. 00 59 23 08 00 00 04 00 00 00 20 38 00 00 A3
2. 00 59 23 08 00 00 04 00 00 60 70 0A 00 00 21

Two corresponding-looking notification payload variants on handle 0x0064 each occur 76 times:

1. 00 59 23 40 ... followed by a stable binary body.
2. 00 59 23 12 ... followed by a stable binary body.

The counts and repeated patterns support a recurring exchange between the app and pedal. They do not establish whether it is polling, status streaming, keep-alive traffic, synchronization, or a parameter exchange. No user action was time-correlated with these repeated packets in the supplied report.

## Model-name strings observed in the notification payloads

The following names are preserved as emitted by the report's ASCII payloads. Capitalization, abbreviations, and spelling are not normalized. Some names cross ATT notification boundaries; entries were reconstructed by joining the visible text across consecutive notifications. These are source strings, not a verified complete catalog for every firmware or every KPT Pro hardware revision.

### Speaker / cabinet-like model strings

These strings were transferred in notifications at frames 413, 421, 425, 433, and 440. Their classification as cabinet/speaker models is based on the names and surrounding catalog context; the report does not provide a GATT field schema that labels the category.

1. EAGLProV30s
2. Sperimental
3. Juice4x12V30
4. Mess Bog
5. FdChamp
6. FdPrJunir
7. Mar960BV30
8. DizzlV30
9. Elctrovoice
10. MessRectV30
11. TwinJensenC
12. TwedDlx1X12
13. FendShowman
14. J120Rolnd
15. AC30Silvers
16. FenDelu
17. FenBface
18. FenMnTw
19. FenBman
20. FenPrin2
21. FenProJ
22. MessOS
23. MessBRO
24. MessIM24
25. MessStdio
26. MessStito
27. MessNom
28. Mar36
29. MarMG15R
30. MarJ2000
31. MarMfour
32. MarPlx
33. MarVal4
34. MarVal2
35. ENG412
36. ENG412P
37. OgP212
38. Pey5150
39. PeyDeBlu
40. SoldHor
41. SoldSC212
42. SoldAng412
43. SoldSC412
44. Alton212
45. BogUX
46. DieV30
47. FimanVt
48. HaBtonV
49. VxAc15
50. VxAc30
51. Matchless 2x1 — the name is visible between entries 50 and 52, but its numeric prefix is not visible in the supplied event segmentation
52. BassJensn10
53. BassStdio22
54. BassAmpg410
55. BassEDN300
56. BassPeyTS
57. BassHake
58. BassPJ400
59. BassOgAD
60. BassDarkVT
61. BassBman70

The numbering from 51 onward is not fully explicit at the notification boundary: “Matchless 2x1” is unnumbered in the visible bytes, while the following Bass-prefixed strings visibly begin at 52. Keep that segmentation caveat if these strings are imported into a catalog.

### Amp model strings with CL / OD / DS prefixes

These strings were transferred in notifications at frames 450, 458, 462, 470, and 477. The prefixes correspond to the owner's known Clean (CL), Overdrive (OD), and Distortion (DS) amp block families. The report does not reveal parameter ranges or which amp models are compatible with which cabinet models.

1. CL-UweTwins
2. CL-UKC30
3. OD-MarVM410
4. OD-MarVicto
5. DS-BritPLEX
6. DS-MarsFD100
7. DS-EagleS
8. DS-DiselHgn
9. DS-PvEV5150
10. CL-FORTIN
11. CL-MessMkt
12. CL-CA-tweed
13. CL-BogSV20
14. DS-JuiceJIM
15. DS-SurSL68
16. CL-BogBlue
17. CL-BogSh20
18. DS-BogES20
19. CL-MesaStar
20. DS-MesaDR
21. CL-Fen65
22. OD-Fen65p
23. CL-FenRed
24. OD-Fenftman
25. CL-MarJ800
26. OD-MarJ900
27. DS-MarJ2000
28. DS-Mar2555
29. OD-MarSV20
30. CL-OgTB50
31. OD-OgRK30
32. DS-OgOR120
33. OD-SurSL68
34. OD-SurBr35
35. OD-EngPB2
36. DS-EngMK60
37. CL-Pey6534
38. DS-Pey6505
39. OD-Rlan120
40. OD-Sold100
41. OD-SoldH25
42. OD-DieV4C2
43. DS-DieV4C3
44. DS-VitrySK
45. CL-TwoRC
46. OD-Fman100
47. CL-GojaX
48. OD-VXac30
49. CL-FotinCa
50. CL-MatDC30

A standalone ASCII string “FNDR AMPCAB” appears after the 50th amp entry. It may be a category/group marker, but its exact role is not established by this capture. The following numbered strings begin at 52 and carry Bass-prefixed names:

52. BassAlmbic
53. BassG800K
54. BassTrTrad
55. BassMaT501
56. BassHake
57. BassPJ400
58. BassOgAD
59. BassDarkVT
60. BassBman70

Preserve these as separate observed strings; do not silently assign “FNDR AMPCAB” as model 51 or assume the following names are amp models rather than another model family.

### What this report does not reveal

No readable named FX, drive, modulation, delay, reverb, dynamics, or effect-block catalog is established by the selected payload excerpts. Do not infer that the device lacks those effects; this capture simply does not expose a decoded name list for them.

## MTU and discovery limitations

The report contains two phone-to-pedal Exchange MTU Requests (512 and 250) and two pedal responses (both 200). This repeated exchange remains anomalous for one selected connection and needs raw HCI connection/bearer lifecycle review. Do not treat the second request as a second independent connection without evidence.

The phone also sends a Read By Type Request for UUID 00002b3a-0000-1000-8000-00805f9b34fb over handles 0x0001–0xFFFF. The pedal returns ATT Error 0x0A (Attribute Not Found). This single unsuccessful query does not establish that the pedal has no proprietary service. The report contains no successful service or characteristic declaration responses, so it cannot map handles 0x0062, 0x0064, or 0x0065 to UUIDs.

## Engineering implications for RigCanvas

1. Keep the decoded strings as a hardware-evidence inventory, not yet as a guaranteed universal catalog. A catalog entry's block category, compatibility, editable parameters, and firmware range must be confirmed.
2. Preserve the exact device-provided spelling/casing in the source inventory. Display names can later have separate user-friendly labels without altering the captured source strings.
3. Use the CL / OD / DS prefixes to provisionally group the observed amp names into Clean / Overdrive / Distortion families, consistent with the owner's existing amp taxonomy. Preserve the original string as the stable evidence value.
4. Do not infer a cabinet's speaker size, mic, impedance, IR format, or compatibility from an abbreviated name alone.
5. Do not derive parameter ranges from the binary notification at frame 486. Its bytes have not been correlated with a controlled one-parameter change.
6. The current report is not enough to implement KPT Pro device-side commands, preset editing, or effect writes. Software-only DSP editing remains separate from pedal-control support.

## Next safe evidence milestones

1. Capture a fresh, read-only GATT discovery exchange and retain successful service/characteristic/descriptor declaration responses. This is needed to map handles 0x0062, 0x0064, and 0x0065 to UUIDs and properties.
2. Inspect the original HCI sequence around the two MTU exchanges, including LE connection complete/disconnection events and L2CAP channel identifiers, before changing MTU parsing.
3. To decode the repeated message pair, make a passive capture while the official app performs a clearly timestamped, single reversible change on a backed-up test preset. RigCanvas must remain a listener; do not send any writes. Compare the before/after payloads and pedal notifications.
4. Repeat catalog retrieval only if needed to check whether the names are stable across reconnects and the exact KPT Pro firmware/app combination. Keep raw payload exports private.

## Safety boundary

- No captured traffic was replayed.
- RigCanvas did not send any device commands.
- No firmware operation was performed.
- Do not replay any captured message or guess a GATT write value.
- Do not enable pedal-side effect, amp, cabinet, preset, or firmware writes until message framing, descriptor mapping, acknowledgement behavior, backup, and recovery have been independently verified on the exact device/firmware.
