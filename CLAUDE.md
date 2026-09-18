# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Legacy of the Chozo: a GameMaker (GML) digital rules engine for a two-player Metroid-themed shared-market deck-builder (Star Realms style). It is a playable prototype with hotseat, human-vs-AI, AI-vs-AI, direct-IP network play with spectators, a regression harness, and an AI batch balance runner.

`PROJECT_REFERENCE.md` is the design and implementation authority: settled rules, UI decisions, AI brain design, batch/regression behavior, and the module layout. Read the relevant section before changing rules, AI, or presentation. Update it when you change settled behavior, since it is maintained as the living checkpoint.

## Source-of-truth priority (when files disagree)

1. Settled clarifications in `PROJECT_REFERENCE.md`
2. `chozoreference.xlsx`: canonical card database (names, counts, costs, stats, factions, effect text)
3. `datafiles/generated/*.json`: runtime cache exported from the workbook. **Never hand-edit it.** Edit the workbook and regenerate.
4. `boardgamefiles/Legacy of Chozo rules-2.pdf` (gitignored, local only)

## Commands

The game has no command-line build. Open `LegacyofChozo.yyp` in the GameMaker IDE and run it there (single room `RM_MAIN`). GML changes can't be compiled or verified from the shell. Tell the user when a change needs an in-IDE run to confirm.

Card data pipeline (Python, requires `openpyxl` via `tools/requirements.txt`):

```powershell
python tools/export_card_data.py              # workbook -> datafiles/generated/*.json + card_validation.{json,md}; nonzero exit on validation errors
python -m unittest tools/test_card_export.py  # exporter tests
python -m unittest tools.test_card_export.<TestClass>.<test_name>  # single test
python tools/lint_pending_choices.py          # static check: every compared pending_choice.kind string is actually created
```

The user's test build runs only one game instance at a time, so network play cannot be verified by running two instances. `tools/net_bot.py` (scripted guest) and `tools/net_host_bot.py` (scripted host, needs debug mode on in the game) cover connection, lobby and command flow from one instance. See `TODO.md` for the planned replay/desync harness.

Run the lint after adding or renaming a `pending_choice` kind. It is the only automated check on GML available from the shell.

In-game verification is run from the title menu. Batch Tests and Regression Tests only appear when debug mode is enabled in Settings:
- **Regression Tests**: deterministic rules scenarios (`scr_loc_regression`). Writes `loc_regression_*.txt`.
- **Batch Tests**: paired-seed AI-vs-AI matrices (`scr_loc_batch`). Writes CSV, report, and `loc_batch_checkpoint.json` (resumable). `tools/build_batch_checkpoint.ps1` rebuilds a checkpoint from a results CSV.
- Match journals `loc_balance_*.txt` and settings `loc_settings.ini` live in `%LOCALAPPDATA%\LegacyofChozo`.

## Architecture

Everything runs inside one object, `obj_bootstrap`, placed in `RM_MAIN`:

- `Create_0.gml` defines the faction color macros, then calls module initializers **in a fixed order**: `loc_bootstrap_data`, `loc_bootstrap_state`, `loc_rules`, `loc_actions`, `loc_abilities`, `loc_raids`, `loc_modes_testing`, `loc_batch`, `loc_network`, `loc_ai`, `loc_regression`, `loc_developer_ui`.
- `Step_0` calls `loc_step()`, `Draw_0` calls `loc_draw()`, and `Other_68` (Async Networking) handles TCP lobby/packets. `CleanUp_0` frees dynamic sprites.

Each `scripts/scr_loc_*/scr_loc_*.gml` holds **one** top-level function, `loc_<module>()`. Its body assigns instance-scoped method variables (`name = function(...) {...};`) and state onto `obj_bootstrap`. As a result:
- All "functions" are instance variables shared across modules. Any module can call any other module's function by bare name, so grep for `name = function` to find definitions.
- Initializer order matters for anything evaluated at init time (not for calls made later from Step/Draw).
- The files are very large (`scr_loc_draw` ~9.7k lines, `scr_loc_ai` ~4.8k). Use Grep with targeted reads, not full reads.

Module responsibilities are listed in `PROJECT_REFERENCE.md` §16 "Runtime module layout". Key model concepts:
- Immutable card **definitions** (from generated JSON, ids like `loc.gf_marine`, `lop.aurora_unit_217`) are separate from mutable card **instances** (owner/controller/zone/ready/attachments/Phazon/modifiers). Many card-specific rules check `definition_id` directly in rules code.
- Decisions that need player input go through `pending_choice`. Input authority follows `priority_player`, not card ownership.
- Rules resolution happens immediately. Presentation (card movement, evolution, destruction, Lab intake) runs through separate queues that gameplay may wait on locally. Batch/headless mode bypasses those waits.
- Rules events are auditable log records (used by the event rail, balance journals, and telemetry). Instances such as raid participants are tracked by immutable instance IDs, never array indices.
- All randomness uses the shared seeded RNG, so matches (and network peers, which rebuild the same deterministic match from the host's seed) must stay deterministic. Guests send action intents that the host validates and commits in sequence, so any new player action needs network replication handling.
- Hit-region kinds and `ui_selected_kind` (`character` vs `opponent_character`) are relative to the **viewing** player. Rules helpers (`get_ability_source`, `get_ability_target_card`, `can_*`) read kinds relative to the **active** player. Convert with `get_rules_kind` when passing a UI kind into rules, and `get_view_kind` when storing a rules kind as UI selection. They only differ when `view_player != active_player` (vs-AI and network off-turn play), so hotseat testing won't reveal mistakes. All pending-choice clicks go through `execute_choice_click`, and all gameplay buttons through `execute_ui_action` (both in `scr_loc_network`, used by local and network input). Add new choice kinds and gameplay actions there. Step's own action `switch` is only for local controls (camera, test tools, title, handoff).
- The board is drawn in a fixed 1531×1080 world viewed through a camera. HUD, sidebar, hand, and Lab drawers live in window space. Hit regions are converted world→window after drawing.
- AI utility is measured in capture value (CV). The planner is a bounded beam search, and per-leader brains are `commander`/`pirate`/`elder`/`warrior`/`neutral`. Regression and batch modes always use the Commander difficulty so results stay comparable.

## Conventions

- Workbook card-pool worksheets: `Cards` (LOC core), `Set2` (LOP Phazon), `Starter`, `Metroids`. `*_defines` sheets are generator substitutions, not cards. Effect markup: `@[cost,n]`, `@[ex]`, `@[des]`.
- Phazon-variant Bounty Hunter sprites prefix `p` (`CARD_prundas.png`).
- Never use `id` as a struct field. It's a read-only GameMaker built-in. Card and Metroid definitions use `definition_id` (the same name instances use), lobby participants use `participant_id`, and guidance lessons use `lesson_id`.
- Local variables use a `_` prefix. Follow the existing GML style (explicit index loops, `variable_struct_*`).
- `boardgamefiles/`, `.codex-tmp`, and `*.resource_order` are gitignored.
