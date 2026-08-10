# Card data export

`chozoreference.xlsx` in the repository root is the canonical source for playable card data. Run:

```powershell
python tools/export_card_data.py
```

The exporter writes GameMaker-friendly files to `datafiles/generated/`:

- `cards_loc.json` from the `Cards` worksheet
- `cards_lop.json` from the `Set2` worksheet
- `cards_starter.json` from the `Starter` worksheet
- `metroids.json` from the `Metroids` worksheet
- `card_validation.json` and `card_validation.md`

The command returns a nonzero exit code when validation finds an error. Warnings are exported for review but do not prevent generation.

Install the only development dependency if it is not already available:

```powershell
python -m pip install -r tools/requirements.txt
```

Generated records contain stable IDs, parsed faction arrays, normalized effect text, typed costs and stats, and their original worksheet row for traceability.

Run the regression checks after changing the exporter or workbook structure:

```powershell
python -m unittest tools/test_card_export.py
```
