# Card Data Validation

- Status: **PASSED**
- Source: `boardgamefiles/chozoreference.xlsx`
- Errors: 0
- Warnings: 1

## Exported pools

| Pool | Worksheet | Unique definitions | Copies | File |
|---|---|---:|---:|---|
| loc | Cards | 40 | 105 | `cards_loc.json` |
| lop | Set2 | 9 | 22 | `cards_lop.json` |
| starter | Starter | 8 | 10 | `cards_starter.json` |
| metroids | Metroids | 6 | 60 | `metroids.json` |

## Issues

| Severity | Location | Code | Message |
|---|---|---|---|
| warning | Starter!1 (count) | `recovered_header` | Starter!A1 is blank; column A was interpreted as count. |
