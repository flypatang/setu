# Dialogue data format (consumed by M16 `narrative/dialogue_runner.gd`)

One file per conversation: `data/dialogue/<id>.json`.

```json
{
  "id": "pro_jambavan",
  "start": "n1",
  "nodes": {
    "n1": { "speaker": "jambavan", "text_key": "DLG_PRO_JAM_001", "next": "n2" },
    "n2": { "speaker": "hanuman", "text_key": "DLG_PRO_JAM_002",
            "choices": [ { "text_key": "CH_PRO_JAM_A", "next": "n3", "flags": {"humble": true}, "smarana": 15 },
                         { "text_key": "CH_PRO_JAM_B", "next": "n2_retry", "flags": {}, "smarana": 0 } ] },
    "n3": { "shloka": "sk_leap_vow", "next": "n4" },
    "n4": { "speaker": "narrator", "text_key": "DLG_PRO_JAM_010", "next": null, "set_flags": {"grow_unlocked": true} }
  }
}
```

Rules
- A node has **either** `speaker` + `text_key` (a line), **or** `shloka` (an id in `data/shlokas.json`, shown with M34b).
- A line has **either** `next` (a node id, or `null` to end) **or** `choices` (1–4 items).
- `set_flags` (optional, on any node) is merged into `GameState.flags` when the node is shown; choice `flags` are merged when chosen.
- `smarana` on a choice is added to the Smarana meter (DESIGN §4.2).
- Speaker display names are translation keys `SPK_<SPEAKER_ID_UPPER>`.
- Every `text_key` must exist in `i18n/strings.csv` with non-empty `en` and `hi` values.
