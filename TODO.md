# TODO

## Network testing without multiple instances

**Problem:** Network features can only be tested by compiling the game and
running two instances (host + join `127.0.0.1`). The test build can only run
one instance at a time, so network behavior is effectively untested between
full builds. Two network-only softlocks (Teleport Station destination and
Queen/SA-X special containment Ship selection) went unnoticed this way.

**Goal:** Exercise the host/guest command path inside a single running
instance, ideally from the in-game Regression Tests runner, so network
regressions show up without a second process.

**Constraints discovered so far:**

- All game state lives on the single `obj_bootstrap` instance, so a second
  "peer" cannot simply exist alongside the first. A loopback test would need
  to snapshot/swap `game_state`, `pending_choice`, and related fields (the
  regression runner already does this save/restore) or run the peer as a
  replay against a rebuilt deterministic match from the same seed.
- Today's guest packets carry UI hover data (`kind`, `index`,
  `selected_index`) rather than self-contained actions, which makes them hard
  to generate from a test. This depends on the action dispatcher work: once
  actions are plain data, a test can serialize them with `json_stringify` /
  `json_parse` and feed them through the same host path a real socket uses.

**Candidate approach (to be designed):**

1. Separate packet transport from packet handling in `Other_68.gml`, so
   `command_request` / `command_commit` handling can be called with a struct
   instead of only from the Async Networking event.
2. Add a loopback transport: `network_send_message` enqueues JSON strings into
   an in-memory queue instead of a socket when a test flag is set.
3. Regression cases that drive choice and action sequences for both seats
   through that loopback (including every `pending_choice` kind) and assert
   the resulting state, optionally replaying the command log into a second
   deterministic rebuild from the same seed and comparing state checksums to
   detect desyncs.
Already done: `tools/net_bot.py` (scripted guest) and `tools/net_host_bot.py`
(scripted host, reading the guest's debug-mode `debug_state` summary) test real
connection, lobby, match start, and command sequencing from one instance. They
do not detect desyncs, since neither bot simulates the game. Choice clicks for local and network input share
`execute_choice_click`, and `tools/lint_pending_choices.py` fails when a
`pending_choice` kind has no handler there. That covers missing handlers but not
network-specific behavior (sequencing, priority checks, packet round-trips).
