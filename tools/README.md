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

# Network bot

`net_bot.py` joins a hosted direct-IP lobby as a scripted guest, so network play
can be tested with one game instance. Host a lobby in the game, then run:

```powershell
python tools/net_bot.py            # Player 2
python tools/net_bot.py --seat 1   # Player 1; switch the host to spectator first
```

It readies automatically and, once the match starts, cycles through
`COMMAND_CYCLE` (edit it at the top of the script) while printing every
`command_commit` it receives. Use `--dump` to print raw bytes if the packet
header does not match.

`net_host_bot.py` is the reverse: it hosts, and the game joins `127.0.0.1` as the
guest, which exercises the game's client path (lobby, match restart, applying
commits). Enable debug mode in the game first. The guest then sends a
`debug_state` summary (turn, phase, active/priority player, pending choice, and
per-player CP and zone counts), which the bot prints and uses to act only on its
own priority.

```powershell
python tools/net_host_bot.py                   # bot is Player 2
python tools/net_host_bot.py --seat 1 --seed 42
```

Both bots share the packet framing in `gm_net.py`.

# Pending-choice lint

`pending_choice.kind` values are bare strings compared across the rules, input,
network, and AI modules. Check that every compared kind is actually created:

```powershell
python tools/lint_pending_choices.py
```

It exits nonzero when a comparison or `case` label names a kind that no
`pending_choice = { kind: ... }` assignment creates, or when a created kind has
no case in `execute_choice_click` (the click handler shared by local and network
input). Kinds resolved only through action buttons are listed in the script's
`ACTION_ONLY_KINDS`; update that set when adding such a choice.
