# Legacy of the Chozo - Project Reference

Status: playable digital rules-engine prototype  
Players: 2, competitive  
Theme: Metroid factions competing to capture and study Metroids  
Current implementation: complete first-pass rules engine, board interface, AI,
hotseat, and direct-IP network play

## 1. Purpose and source of truth

This document records both the settled tabletop rules and the current digital
implementation. It is the working checkpoint for rules, interface decisions,
AI behavior, networking, and balance instrumentation.

Use this source priority when files disagree:

1. Settled clarifications recorded in this document.
2. `boardgamefiles/chozoreference.xlsx` as the canonical card database for
   card names, set membership, quantities, costs, values, faction/type tags,
   and effect text.
3. `boardgamefiles/Legacy of Chozo rules-2.pdf` for core rules not superseded
   by this reference.
4. Rendered cards and boards for presentation and icon interpretation.
5. `.xcf`, `.cmp`, and other work-in-progress files as design sources, not
   rules authority.

Items under **Remaining design work** are planned content rather than settled rules.

## 2. Game objective

Players represent competing factions in a Metroid arms race. They capture evolving Metroids from SR388 aboard Ships and contain them in their laboratories.

The game ends when the Mutation Track reaches its eighth and final space. Shop exhaustion does not end the game.

Each player totals the Research Value of the Metroids in their Lab and rounds the final total down. The higher total wins. A tie is broken by unspent Command Points (CP). If Research Value and CP are both tied, the game is a draw.

## 3. Factions

| Faction | Code | Stated identity |
|---|---:|---|
| Galactic Federation | GF | Control and CP generation |
| Space Pirates | SP | Raiding, attacking, and stealing |
| Chozo | CZ | Thoha control Metroids; Mawkin specialize in destruction |
| Bounty Hunter | BH | Flexible abilities that support other strategies |
| Neutral | NA | Science and research |
| Phazon | PZ | Corruption through card interaction and accumulating Phazon tokens |

Phazon-infected Bounty Hunter variants reuse their original character artwork,
but their card sprite asset names add a leading `p`: Corrupt Rundas uses
`CARD_prundas.png` and Corrupt Gandrayda uses `CARD_pgandrayda.png`, rather than
the uninfected `CARD_rundas.png` and `CARD_gandrayda.png` assets.

Cards may have multiple factions, such as `BHCZ`, `NACZ`, or `GFPZ`. The rules explicitly say the selected starter faction does not restrict cards a player may acquire.

This is a shared-market deck-builder in the style of Star Realms, not a constructed-deck trading card game. There are no deck-size, faction, or copy-count restrictions during play.

## 4. Card types

| Type | Role |
|---|---|
| Character | Supplies Strength for containment and may have active or passive effects |
| Ship | Captures and carries Metroids, contributes Security, and conducts raids |
| Event | One-shot effect; must first be reserved into a player's deck |
| Location | Persistent passive or activated ability |
| Metroid | Cannot be played normally; supplies Research Value and Hazard |

Relevant card fields in the workbook are: count, set, faction, type, image, name, tags, effect, strength/security, deploy cost, reserve cost, flavor, dual-faction marker, and allowed layout.

The workbook separates its card pools by worksheet:

| Logical pool | Current worksheet | Contents |
|---|---|---|
| LOC core set | `Cards` | Core Shop cards |
| LOP Phazon set | `Set2` | Phazon Shop cards |
| Starter cards | `Starter` | Cards used to assemble starter decks |
| Metroids | `Metroids` | Standard stages and special Metroid definitions |

The accompanying `Cards_defines`, `Set2_defines`, and `Starter_defines` worksheets contain generator substitutions and totals rather than playable card definitions.

Effect markup used by the card generator:

- `@[cost,n]`: pay `n` CP
- `@[ex]`: exhaust
- `@[des]`: destroy

## 5. Shared and player zones

### Shared zones

- Shop deck
- Five-card Shop row
- Shop discard pile
- SR388, with four numbered surface slots
- Separate supply deck/pile for each standard Metroid stage
- Omega cavern area/deck
- Mutation Track

### Per-player zones

- Draw deck
- Hand (normally five cards)
- Discard pile
- Removed-from-game zone
- Board/field for Characters, Ships, and Locations
- Lab for contained Metroids
- Metroids currently aboard each Ship
- Command Point pool

## 6. Setup

1. Separate the Metroid cards by stage in this order: Larva, Alpha, Gamma, Zeta, Omega.
2. Place four Larvae into the four SR388 slots.
3. For the current first pass, each player takes a copy of the 10-card Neutral starter, shuffles it, and draws five cards.
4. Shuffle every core-set card not used in the starters into the Shop deck and reveal five cards.
5. During setup only, if Queen Metroid Awakens is revealed, put it on the bottom, continue until the Shop has five cards, then shuffle the Shop deck again.
6. Set the Mutation Track to 0.
7. Flip a coin to choose the first player.

Only one starter deck is currently defined: a 10-card Neutral starter. Faction starters are planned for testing, with these intended identities:

- Galactic Federation: economy
- Space Pirates: raids
- Chozo: Metroids and removal
- Bounty Hunters: game-state manipulation
- Phazon: corruption

## 7. Turn structure

### Start of turn

Resolve these steps in order:

1. Perform a Containment Check.
2. Gain CP based on the Mutation Track:
   - Mutation 0-2: gain 4 CP.
   - Mutation 3-4: gain 5 CP.
   - Mutation 5-6: gain 6 CP.
   - Mutation 7-8: gain 7 CP.
3. Move all Metroids aboard the active player's Ships to that player's Lab.
4. Ready all exhausted cards, except:
   - a Ship exhausted to help with this turn's containment.

During the Containment Check, the active player retains priority and may activate
card abilities before resolving the check. They may then include up to one ready
Ship. CP gain, automatic Ship-to-Lab movement, and readying resolve without
additional input.

### Action phase

The active player may take actions in any order and may repeat them while able to pay their costs:

| Action | Cost and result |
|---|---|
| Deploy from Shop | Pay Deploy cost; put the card directly into play ready |
| Reserve from Shop | Pay Reserve cost; put the card into the player's discard pile |
| Play from hand | For a non-Event, pay its Reserve cost again and put it into play |
| Play an Event | Once per turn; play it from hand for no CP cost |
| Capture | Pay 1 CP and exhaust a Ship; move an eligible Metroid from SR388 onto it |
| Raid | Pay 2 CP and resolve a Ship-versus-Ship raid |
| Salvage | Discard any number of your ready Characters, Ships, or Locations one at a time; gain CP equal to half that card's printed Reserve cost, rounded down |
| Refresh hand | Pay 1 CP; discard any number of cards, then draw until holding five |
| Refresh Shop | Pay 1 CP; discard all five Shop cards and refill the row |
| Activate a card | Pay and resolve the costs printed on the card |

After any card is played from hand, immediately draw a replacement. Cards enter play ready unless an effect says otherwise. A resolved Event goes to its owner's discard pile.

Five is the natural maximum hand size under the current rules: normal draw effects only draw when the player has fewer than five cards. It is not a separately enforced state-based limit, so a future effect could explicitly raise or bypass it.

When a player's deck is empty and a draw is required, shuffle that player's discard pile to form a new deck. If both are empty, the draw simply cannot be completed; this does not end the game.

Whenever a Shop card is bought by Deploying or Reserving it, immediately refill its slot.

### Priority and effect timing

- A player may activate abilities while they have priority.
- The active player normally has priority during their own turn.
- Structured procedures can grant priority at other times; for example, attacker and defender each receive an opportunity to use effects during a raid.
- Card text that triggers at the end of every turn triggers at the end of each of that card controller's turns, not at the end of both players' turns.
- The design intentionally avoids general reactions and interrupts. None are currently known in the card pool.
- Passive abilities function while their source is exhausted unless the ability is conditional or another effect explicitly disables it.
- Simultaneous effects cannot be controlled by different players because priority determines whose effects are resolving. When one controller has simultaneous effects, that controller chooses their order.
- A copied Event effect counts toward the once-per-turn Event limit if the copying source is itself an Event. A non-Event that uses or copies an Event's ability does not count as playing an Event.

### Leaving play and attachments

- Discarding a card moves it to its owner's discard pile.
- Destroying a card removes it from the game permanently.
- Attachments remain separate permanents in the shared in-play zone.
- When a host leaves play, all cards attached to it are discarded.

### End of turn

1. Roll a d4 and evolve the Metroid in the corresponding SR388 slot.
   - An empty slot produces no evolution.
   - If the selected Metroid is an Omega, move it to the cavern and put a Larva in that slot.
2. Fill any remaining empty SR388 slots with Larvae.

Then the opposing player begins their turn.

## 8. Capturing Metroids

To capture from SR388:

1. Pay 1 CP.
2. Exhaust a Ship.
3. Choose a Metroid whose Hazard is less than or equal to that Ship's Security.
4. Move the Metroid onto the Ship if it has cargo capacity.

At the start of that Ship controller's next turn, after containment and CP gain, all Metroids aboard their Ships automatically move to their Lab.

This automatic movement does not exhaust or ready a Ship. Ships using the
normal capture action exhaust as part of that action; effects such as Quiet
Robe can place cargo onto a ready Ship specifically to bypass that capture
exhaustion. Frigate Orpheon's older "does not exhaust when transporting"
wording means that it does not exhaust when using the normal capture action.

Every Ship has a base capacity of one Metroid. Effects may bypass or increase this limit. Effects that capture multiple Metroids normally require their combined Hazard to be less than or equal to the Ship's Security, in addition to whatever capacity exception the effect supplies.

Cavern Omegas are always available for direct selection as though the cavern were a fifth SR388 slot.

## 9. Containment

At the start of a player's turn:

1. Total the Strength of all ready Characters that player controls.
2. The player may choose one Ship and exhaust it to add that Ship's Security.
3. Total the Hazard of all Metroids in that player's Lab.
4. If Hazard is greater than containment Strength, a breach occurs:
   - the Lab owner returns one of their highest-stage Metroids to its matching supply;
   - the Lab owner chooses and discards one of their Characters, if they control any;
   - check containment again.
5. Repeat until Hazard no longer exceeds containment Strength.

An equal total passes. Metroids of the same stage are mechanically identical, so choosing among tied highest-stage Metroids has no gameplay consequence. Escaping does not cause an SR388 evolution.

If no Ship contributes Security to the check, every Omega in the Lab breaches simultaneously regardless of Character Strength. Each Omega is a separate breach instance and causes its owner to discard one Character if able. After resolving those Omegas, continue the normal cascading containment process. Adam Malkovich can destroy himself to avoid a breach.

## 10. Raids

1. The attacker pays 2 CP, chooses one of their ready Ships, and exhausts it. Apply any ready-card raid-cost modifiers before payment; for example, each ready Chozo Warrior reduces this cost by 1 CP.
2. The attacker chooses an opposing Ship. The defending Ship does not exhaust merely for defending.
3. The attacker may exhaust Characters and activate effects to raise their Ship's Security.
4. The defender may then do the same.
5. The side with the lower final Security loses. On a tie, both sides lose.
6. If the attacker wins, cargo transfers from the defending Ship to the attacking Ship:
   - the winner chooses which Metroids to take if the attacking Ship cannot hold them all;
   - the attacker must take as many Metroids as the attacking Ship can hold;
   - any untaken cargo returns to its matching stage supply;
   - the attacker cannot decline cargo that fits.
7. Discard every losing Ship. Any cargo still aboard a discarded Ship returns to its matching stage supply.
8. On a tied raid, both Ships lose, no cargo transfers, and all cargo aboard both Ships returns to its matching stage supply.

A Ship without cargo is a legal raid target, although raiding it normally provides no benefit. Discard choices are made by the owner of the cards unless an effect explicitly says otherwise.

During either side's Raid priority window, hovering one of the priority player's permanents exposes its normal card-anchored context menu without requiring selection. A ready Character has an `EXHAUST: +X SECURITY` contribution button alongside any otherwise-legal activated abilities and Salvage. Abilities use their normal targets and follow-up choices; after an action finishes, play returns to the same attacker or defender Raid window. Only Lock Attackers / Resolve Raid remains in the sidebar.

## 11. SR388 and Metroid evolution

SR388 normally has four numbered surface slots. Empty slots are filled with Larvae at end of turn.

Evolution order:

`Larva -> Alpha -> Gamma -> Zeta -> Omega`

The Mutation Track has eight spaces. Whenever a Zeta is born, advance the
Mutation Track one space. Whenever an Omega is born while Mutation is 0-3,
advance it one space; if Mutation is already 4 or higher, advance it two
spaces instead. In the normal evolution chain, these occur when a Gamma
becomes a Zeta or a Zeta becomes an Omega. Mutation cannot advance beyond 8.

Two alternate conditions start a final round rather than ending immediately:
either player reaching 10 Metroids in their Lab, or the match reaching turn 50.
The active player finishes the current turn, the opponent receives one final
turn, and Research is then scored. Mutation reaching 8 remains an immediate
ending, including during those final turns.

When a Metroid evolves, return the old stage to its supply and replace it with the next stage. For the rules engine, each stage supply is infinite; physical supply limits may be added later.

When an Omega is selected for another evolution, it moves to the cavern. The cavern functions as a fifth, directly selectable SR388 area containing a pile of Omegas. A cavern Omega follows the same 1 CP capture cost, Security requirement, cargo rules, and other rules as a surface Omega. Moving Omegas into the cavern prevents surface mutation from stalling.

### Current Metroid data

| Stage | Hazard | Research Value | Workbook design count | Special rule |
|---|---:|---:|---:|---|
| Larva | 1 | 0.5 | 10 | None |
| Alpha | 2 | 1.5 | 10 | None |
| Gamma | 3 | 2 | 10 | Advances the Mutation Track when it evolves into Zeta |
| Zeta | 4 | 4 | 10 | Advances the Mutation Track when it evolves into Omega |
| Omega | 5 | 6 | 10 | All Omegas breach simultaneously if no Ship contributes to containment |
| Hunter (LOP) | 1 | 1 | 10 | Breaches before other stages; gives all controlled Characters a Phazon token when it breaches |

## 12. Phazon and attachments

Phazon is included in the first implementation pass.

### Gaining Phazon tokens

A card gains a Phazon token when:

- an effect explicitly gives it one; or
- it is one of two cards linked by a selection in a card effect and the other card has the Phazon faction tag.

In rules text, interaction is specifically created when one card's effect instructs its controller to select another Character, Location, or Vehicle/Ship. The non-Phazon participant gains a Phazon token:

- if a Phazon card's effect selects another card, the selected card gains a token;
- if a non-Phazon card's effect selects a Phazon card, the selecting card gains a token.

Broad, non-selecting effects do not create this interaction merely because they affect a Phazon card.

### Corruption threshold

There is no upper limit on Phazon tokens. Whenever a card exhausts, if it has at least three Phazon tokens, discard it. If it exhausted to pay an ability cost, the card is discarded first but its paid ability still resolves. Some effects can use totals above three. Dark Samus is explicitly immune to this accumulation discard and may exhaust to move one Phazon token from another permanent she controls onto herself.

Phazon tokens exist only while their card remains on the board. Remove all of its Phazon tokens whenever it is discarded, returned to hand, or destroyed.

### Hunter Metroids

Hunter Metroids:

- are a special Metroid stage that does not occur naturally on SR388;
- are created by Phazon Ships that transform Metroids they carry;
- have Hazard 1 and Research Value 1, making them more point-efficient than Larvae;
- breach before all other Metroid stages whenever a breach is possible; and
- give every Character controlled by the breaching player a Phazon token when one breaches.

## 13. Shop rules

- The Shop row normally contains five face-up cards.
- Buying means either Deploying or Reserving.
- Refill a purchased card immediately from the Shop deck.
- Refreshing the Shop costs 1 CP. Discard all five current Shop cards first, then draw five replacements.
- Whenever a Shop draw is required and its deck is empty, shuffle the Shop discard pile to form a new Shop deck.
- Shop slots never remain empty if a recyclable Shop card is available.
- Failure to complete a Shop draw does not end the game.

Queen Metroid Awakens behaves as a game-state event rather than a normal purchase:

1. Queen occupies the Shop slot into which it was drawn.
2. Finish filling every other open Shop slot before Queen activates.
3. Its global effect then resolves immediately.
4. As part of the same resolution, Queen is shuffled back into the Shop deck
   without requiring a second confirmation and without being bought or discarded.
5. Its Shop slot is immediately refilled.

## 14. Current content inventory

### Workbook content

All counts below come from the card-count field in `chozoreference.xlsx`; duplicate copies are intentional parts of their respective sets.

- Core set (`LOC`): 40 unique non-Metroid designs, 105 printed copies
  - 19 Characters
  - 12 Ships
  - 5 Locations
  - 4 Events
- Phazon set (`LOP`): 9 populated designs, 22 printed copies
  - 6 Characters
  - 2 Ships
  - 1 Event
- Starter: 8 unique designs forming a 10-card Neutral starter
- Metroids: 5 standard stages plus the LOP Hunter Metroid

### Asset content

The `boardgamefiles/` tree contains approximately:

- 199 PNG files and 33 JPG files
- rendered decks and screen-top/compressed variants
- blank card frames for factions and card types
- character and setting source art
- 14 GIMP `.xcf` working files
- 2 CardMaker `.cmp` projects
- font archives and SVG icons
- board, Shop board, SR388 board, rules tablet, tokens, logos, and ship/card concepts

The active GameMaker project now contains a playable rules-engine prototype in
`RM_MAIN`, driven by `obj_bootstrap`. Card data, card art, turn flow, card
effects, containment, mutation, raids, Phazon, board presentation, and game-end
handling are implemented.

The title menu offers two-player hotseat, human-versus-AI, direct-IP hosting,
and direct-IP joining. In AI mode, Player 1 remains the visible human board and
the AI hand is hidden. The AI is a deliberately readable utility-based
opponent. It resolves mandatory choices, containment, card play, Shop
purchases, Metroid captures, activated abilities, raid initiation, raid
contributions, raid abilities, and raid defense with short visible pauses
between decisions.

The title menu also offers direct-IP network hosting and joining. Network
play uses host-authoritative TCP command replication on port `6510`. The host
chooses a random seed, both peers rebuild the same deterministic match, and
the guest sends action intentions which the host validates and commits in
sequence. Each installation keeps its local player's board and hand view fixed.
Local test mutations and unsynchronized keyboard shortcuts are disabled during
network matches. The main-menu player-name field supplies Player 1's name in
solo, hotseat, and hosted games. Joining players may edit their name alongside
the host address; both names are exchanged during the network handshake and
used throughout the event log.

For local testing, run two game instances, host on the first, and join
`127.0.0.1` on the second. For LAN testing, join the host's LAN IPv4 address.
Internet direct-IP testing requires TCP port `6510` to reach the host, normally
through router port forwarding or a VPN-style virtual LAN.

## 15. Remaining design work

The initial rules review has no unresolved core cases. The full current card
pool has a first-pass implementation. Test games may still expose wording,
timing, or unusual state combinations that need clarification.

Hyper Mode removes one Phazon token from every card the player controls,
including attached cards, then places the complete removed total onto one chosen
Character that player controls. If no tokens are removed, no choice is created;
if no Character exists, the tokens remain removed with no recipient.

Identity-tinted starter substitutions are implemented as an optional setup rule
for human-vs-AI, AI-vs-AI, and batch profiles. These are focused substitutions
inside the shared Neutral starter rather than complete faction-specific starter
decks; fully distinct faction starter lists remain possible future content.

Additional non-testing work still planned:

- faction-specific starter decks;
- a player-facing rules/reference screen and optional guided onboarding;
- continued board, font, menu, prompt, and animation polish;
- a later Shop presentation redesign, intentionally deferred until its visual
  identity is settled;
- network disconnect, compatibility, and graceful-failure handling;
- distributable build configuration and long-term decomposition of
  `obj_bootstrap`.

### Deterministic regression harness

The title menu includes an isolated regression runner. It temporarily replaces
the live game state, runs focused rules scenarios, restores the original state,
and writes a timestamped `loc_regression_*.txt` report. Current checks cover
live Gray Voice Capture cost, source/target index shifts when activation costs
remove a card, doubled effects whose target vanishes, attachment cleanup, and
special Omega containment advancing after its breach casualty. The suite also
checks all seven concrete identity-starter substitutions (both Chozo branches),
ten-card deck preservation, duplicate-card replacement counts, and the disabled
starter path. Additional
checks cover corrupted exhaustion costs and Queen waiting for the full Shop row,
declining Adam during special containment, sequential Omega breaches, Hunter
breach priority, and hosts carrying multiple attachments. Raid checks cover
tied Ship destruction, automatic single-cargo transfer, full-winner overflow,
partial-capacity cargo choice, and contributor exhaustion affecting totals.
Timing checks also cover attacker-only Ship exhaustion, corrupted raid
contributors, defensive abilities modifying unlocked totals, Pirate Destroyer
readying after a win, and Queen and SA-X special containment completing across
both players.

### Working implementation checkpoint — August 10, 2026

The prototype is currently playable in hotseat, human-versus-AI, and direct-IP
host/guest modes. The implemented rules include the complete current card pool,
attachments, Phazon corruption, capture and Lab movement, containment and
sequential breaches, mutation and scaling CP income, raids, Queen and SA-X
game-state events, scoring, turn handoffs, and game-end presentation.

Current interface decisions:

- Title-screen settings persist in `loc_settings.ini`. They currently cover the
  default close/far camera framing, default free/locked camera behavior, separate
  Player 1 and Player 2 hard-light UI accents, the most recently entered player
  name, and whether developer/test controls are visible. These custom accents
  replace generic interface palettes only; faction identity palettes remain
  independent. Sidebar and menu surfaces derive a restrained dark tint from the
  selected accent, calibrated so cyan retains its original blue-gray appearance
  while every other choice receives the same color relationship. Debug-off hides
  the in-match Test Tools/SIM controls and
  title-screen batch/regression entries.

- Hotseat changes the full palette to identify the active player.
- The Shop tray reserves a taller header band above its fixed card grid so the
  `SHOP` label remains visually separate from the first row at every camera scale.
- The in-match Pause menu includes an Options screen matching the title-menu
  settings. UI palettes, contextual help, debug visibility, and camera defaults
  can be edited and persisted without leaving the match; camera changes also
  apply immediately to the current board view.
- A Help / Rules reference is available from both the title and Pause menus. It
  uses a two-column layout with selectable concept sections on the left and a
  scrollable plain-language summary on the right. Initial topics cover the game
  overview, turn structure, cards and zones, CP/actions, Capture, Containment,
  Raids, Metroids, Research, and Factions. Longer secondary concepts remain in
  the summaries rather than shrinking the navigation labels.
  Summary copy uses native-scale `FNT_METROID` typography matching its section
  header, with wrapping and scrolling handling narrower layouts.
  Selected Help topics and main-menu sections invert their accent fill and text
  colors instead of adding a width-changing text marker.
- Optional first-game guidance is persisted separately from contextual hover
  help. One short modal lesson is queued at a time and waits for card/camera
  presentation to finish before appearing. The first lesson explains locked and
  unlocked camera controls; later triggers cover the first Action phase, hand
  and Shop inspection, activated abilities, Capture, ending a
  turn, Containment, Breaches, attacking and defending Raids, a Metroid entering
  the Lab, Larva-to-Alpha evolution, the first Mutation advance, final-round
  timing, Attachments, Phazon, Salvage, and hand/Shop refreshes. Lessons use
  `GOT IT` and `DISABLE GUIDANCE`; acknowledged lesson IDs persist in
  `loc_settings.ini` so they do not repeat in later matches. Both Options pages
  include `RESTORE FIRST-TIME HINTS`, which clears that history and re-enables
  guidance.
- Corrupt Rundas uses its current Phazon token count as its dynamic Strength.
  Chozo Ghosts now resolves as a mandatory sequence at the end of its controller's
  own turn: its controller
  moves one Phazon token from another controlled permanent, then discards the
  Ghosts at three or more tokens and assigns all of those tokens to an opposing
  Character. Multiple copies queue independently before Mutation begins.
- The Recent Events rail is a scrollable chronological message feed: older entries
  appear above newer entries and the live edge is anchored at the bottom. Setup and
  loader errors remain pinned above the history in red with their full diagnostic
  text.
- Rules logging records named state changes at their resolution site, including
  individual discards, attachments leaving with hosts, Phazon gains and resulting
  token levels, corruption-triggered discards, Event outcomes, Raid initiation,
  Capture, containment, and other scripted effects. Aggregate effects retain a
  summary entry after their individual card entries.
- A full-width text-chat field sits at the bottom of the event rail. Enter sends
  `<player name>: <message>` in local, hotseat, AI, and direct-IP games; only the
  player-name prefix is colored with that player's primary deck/faction color.
  Direct-IP chat travels independently of gameplay priority and command sequencing.
  Chat entries are structured records, so rules telemetry ignores their contents
  when counting gameplay events. Faint horizontal rules separate feed entries;
  system events use a desaturated straw-gray treatment while player chat bodies
  remain bright for quick visual distinction.
- Optional contextual help is enabled by default and persisted in settings.
  Hovering core action controls shows a compact upper-left explanation with a
  short, interaction-specific reason when unavailable, such as `(not enough
  CP)` or `(no valid targets)`. Activated card effects use their structured
  ability data for plain-language help. Target-specific failures stay on the
  affected target; during Capture selection, an under-secured Metroid reports
  `(not enough Security)` rather than placing that reason on the Capture button.
- Mandatory pending-choice prompts now use a stronger top-center `TRANSMISSION
  RECEIVED // ACTION REQUIRED` panel. They are spatially independent from
  contextual hover help, so both may remain visible at once.
  The normal Containment phase also presents an explicit mandatory prompt to
  select a ready Ship to contribute its Security or choose `NO SHIP`.
- AI and network modes keep the local player's palette and board view fixed.
- Network input authority follows `priority_player`, including effects that hand
  a decision to the opponent; source ownership metadata never overrides the
  responder. During ordinary remote priority, the action rail displays a disabled
  `OPPONENT'S TURN` panel instead of dimming any portion of the playfield.
- Targeted abilities resolve immediately; the game has no general reaction
  or targeted-effect response window.
- Raid attacker/defender priority remains because contribution and raid
  abilities are part of the raid procedure.
- Every in-play card with Strength or Security has a live stat badge.
  Modified values are also shown in Details.
- Both play areas are uninterrupted, unfilled space surfaces rather than boxed
  type lanes. Ships occupy the front rows nearest SR388, Characters occupy the
  rear rows, and both formations span the full play area and center on SR388.
  This makes opposing Ships read as contesting control of the planet.
- Locations form independent, non-overlapping side clusters. They no longer
  reserve horizontal width or squeeze the Ship and Character formations.
  Their adaptive shape follows the number in play: one card, a vertical pair,
  triangle, square, two-over-three, 2-by-3, then compact centered near-square
  rows for higher counts. The opponent cluster is rotationally mirrored.
- Gameplay now uses two coordinate systems. The board is a fixed authored
  1531-by-1080 world viewed through an interpolated camera, while the header, right
  dashboard, contextual controls, and modal overlays remain in window-space.
  The application surface follows the resizable window at one logical pixel
  per client pixel, so a larger window reveals more world at the same zoom
  instead of stretching the board.
- Native resize, maximize, and restore verify the application-surface
  dimensions every frame because GameMaker may recreate that surface after the
  window transition. Free-camera resizing preserves the world point at the
  viewport center; locked framing recomputes its selected preset. Ship,
  Character, Location, Shop, and SR388 geometry never reflow with window size.
- Mouse wheel zooms the board around the pointer and right-drag pans it. Camera
  targets allow controlled overscroll until the board is mostly outside the
  viewport, then ease into place. Keyboard presets remain `1` local board, `2`
  center systems, `3` opponent board, and `0` fit the complete table.
- The header separates framing from control mode. `CENTER: CLOSE/FAR` selects
  the desired preset and immediately recenters once whenever it changes.
  Close derives its zoom from the current board viewport while retaining the
  authored 1080p composition, so a larger window enlarges the relevant player
  surface instead of merely revealing more of the table.
  `CAMERA: FREE/LOCKED` controls subsequent behavior. Free camera never follows
  turns, raids, or other game state and stops any in-progress automatic motion
  when unlocked. Locked camera automatically follows the relevant local,
  opponent, or cross-table interaction framing.
- Board hit regions are converted from world coordinates to window coordinates
  after drawing and clipped to the board viewport. This keeps card selection,
  Lab drawers, contextual buttons, and raid targeting aligned under pan and
  zoom without allowing the board to intercept dashboard input.
- The local hand and both Lab drawers are viewport HUD elements rather than
  board-world elements. They remain attached to the bottom and top edges while
  the table pans or zooms, and their hit regions bypass camera conversion.
  Cards leaving the hand convert their presentation position back into world
  coordinates before deployment or discard animations begin; Metroid intake
  similarly converts its fixed Lab destination into world space in flight.
- The closed opponent Lab tab sits flush against the bottom of the top header.
- `Back_Space` is drawn behind the full interface at a proportional scale with
  14% horizontal overscan. Excess height is center-cropped rather than
  stretching the square source artwork. It follows only a small fraction of
  camera movement, creating restrained parallax behind the fixed board world.
- Standard interface panels use bright, translucent cyan holographic bodies
  over the space background, with luminous cyan borders and headings. The
  center panels and full right interface rail use the same transparency so the
  rail does not visually overpower the board. The active play surface remains
  completely unfilled.
- Unlit Mutation tracker spaces use opaque black for contrast against the
  holographic panel and starfield; completed spaces retain the mutation color.
- SR388 is a large centered world-space planet rather than a rectangular
  panel. Its four surface Metroid slots form one centered row wholly within the
  planet. The planet crosses the old center-strip boundary and sits behind both
  players' cards.
- The Omega cavern is no longer rendered as a permanent fifth surface slot.
  When at least one cavern Omega exists, a low-opacity hard-light `CAVERNS`
  sensor panel fades in beyond the planet's right edge. A cyan diagonal leader
  connects it to the planet surface so it reads as a magnified underground
  contact. It fades away when the cavern becomes empty.
- The Shop is a subdued hard-light tray wholly left of SR388. Its five stable
  offer slots form a three-card upper row and centered two-card lower row.
  The Shop deck and discard are stacked outside the tray to its left and are
  normally outside Close framing; panning left reveals them. The discard shows
  a darkened copy of its current top card.
- Visible card positions belong to card instances across zones and interpolate
  toward their current layout targets. Hand plays and Shop deployments begin
  at their actual source card, newly drawn cards emerge from the relevant deck,
  and board reflow does not transfer motion to a replacement array slot.
- Interactive matches open with a short staged deal: the Shop populates first,
  followed by SR388 and then the viewing player's hand. Shop and hand refills
  briefly hold at their source pile before moving into the vacated space. Cards
  dealt from a deck remain face-down during that hold and reveal on their first
  frame of movement, rather than revealing while still resting atop the deck.
- Ship cards retain a presentation angle and rotate continuously while moving
  between portrait zones and their horizontal in-play orientation.
- Hand refreshes use separate visual beats without delaying rules resolution:
  every selected card travels to the discard together, the hand remains empty
  briefly, and replacement cards then leave the deck. When a player must
  recycle their discard, a temporary visible stack moves from discard to deck
  before the resulting draw animation begins.
- Shop refills are visually serialized after the departing card. A reserved
  card completes its trip to its owner's discard before the replacement leaves
  the Shop deck; deployments receive the same ordering. Refreshing the entire
  Shop moves all five old cards away together, pauses, and then releases the
  five replacements in a short stagger.
- Shop cards retain stable slot identities. Removing a card leaves a visible
  hole; neighboring cards do not compact, and the replacement is dealt directly
  into the vacated slot.
- Playing from hand uses the same departure-first ordering. Events reach the
  discard before their replacement leaves the deck, while permanents reach
  their in-play position before the replacement draw begins.
- While a new card is travelling to a discard pile, the prior top card remains
  visible beneath it until the arrival completes. Hovering a discard shows its
  total count above the pile while Details continues to inspect the visible top
  card. Hovering a deck instead shows an alphabetized ID-and-count manifest of
  its remaining cards; this inventory view never reveals deck order.
- Metroid instances also retain presentation positions. Capturing one animates
  that specific Metroid from its SR388 or Cavern slot into the selected Ship;
  later cargo-to-Lab movement continues from the same instance position.
- Evolution uses a deliberately slow 1.4-second white transition: the old stage
  washes to white, holds briefly, and the new stage is revealed as the white
  fades away. Local and AI automatic progression pauses for the transition so
  end-of-turn evolution remains readable. Batch and network timing is unchanged.
- Whenever a card's Phazon total increases, the card flashes blue twice over
  roughly 0.7 seconds. The newly added token icons remain visible above the
  flash, and gaining additional Phazon restarts the pulse.
- Contextual card controls include an invisible hover bridge across the visual
  gap above their source card and behind all gaps in the button cluster. A
  short anti-flicker grace period preserves both the controls and the hand card's raised
  position while the pointer moves among the card, bridge, and buttons. This
  timed grace applies only to hand cards; Shop controls close immediately when
  the pointer leaves the card, its top bridge, and its buttons.
- When a played hand card leaves its zone, both direct selection and temporary
  hover context clear with that instance. Its replacement never inherits the
  departed card's hand-slot selection.
- Clicking any enabled action button consumes and clears the current card
  selection after the action has read it. Follow-up prompts retain their source
  through `pending_choice`, so exhausted or moved cards do not leave contextual
  controls open after phase and action transitions.
- The Actions pane remains reserved for global turn controls. Refresh Hand and
  Refresh Shop stay visible when contextual card controls appear, with End Turn
  placed beneath them; contextual controls appear only over their source card.
- Choice instructions no longer compete with buttons inside the Actions pane.
  While a choice is pending, its prompt appears in the upper-left corner of the
  screen in a cyan hard-light `INCOMING TRANSMISSION` panel. Both its heading
  and message use `FNT_METROID`. Its height expands to contain the wrapped
  message, up to the available screen height; choice-specific buttons remain
  in the Actions area.
- Containment confirmation uses one state-aware button. It reads `NO SHIP`
  when no ready Ship is selected and changes to `USE SELECTED SHIP` when a
  legal Ship selection exists; special Queen and SA-X containment uses the same
  control model.
- Lab intake is also presented rather than teleporting. Cargo Metroids travel
  slowly from their Ships toward the closed Lab and finish staged off-screen
  beneath its tab. Metroids are seated at their sorted positions inside the
  off-screen tray; opening the Lab moves the drawer and all of its contents as
  one rigid unit rather than applying a separate card interpolation.
- Raids display live red attacker and blue defender totals. A thick red line
  connects the attacking Ship to its selected target.
- Raid-line endpoints are resolved by Ship instance and restricted to Ship hit
  regions; overlapping numeric IDs from the separate Metroid instance counter
  cannot redirect the line to SR388 or cargo.
- During the action phase, card-specific controls appear in a compact strip
  immediately above the hovered or selected card. Hover previews the available
  controls; moving onto a preview button preserves its source, and clicking it
  selects that card before resolving the action. Global and prompt controls
  remain in the Actions panel.
- Bright yellow edge lights are reserved for cards with an action that is both
  legal and affordable at that exact moment. They do not represent standard
  Capture or Raid actions. Hand cards receive one full-width light when
  playable; in-play cards receive one when at least one activated ability is
  usable; Shop cards use separate left Deploy and right Reserve segments that
  match their printed cost positions. No light appears without player priority.
- The player Lab opens upward from the bottom screen edge. The opponent Lab
  opens downward from beneath the header. Both use stage-ordered, overlapping
  vertical card trays with full-width Metroid cards.
- Hunters appear before the numbered evolutionary stages in Lab trays.
- Torizo forces its controller's Lab open and requires selection of the
  eligible Metroid to evolve rather than choosing automatically. AI-controlled
  Torizo uses the highest eligible stage.
- Details replace the earlier card-zoom panel. Holding Alt over a card displays
  full-screen card art.
- Player identity plates are anchored directly to the SR388 row: the local
  player is left-aligned beneath the leftmost surface Metroid and the opponent
  is right-aligned above the rightmost. Each uses a dark translucent underlay
  for contrast against the planet. Local hard light and text are cyan;
  opponent-owned hard light and text are red.
- CP is represented by 20-pixel CP-symbol hexes attached outside the identity
  plates rather than resizing them. Local CP enumerates left-to-right beyond
  the local plate's right edge; opponent CP enumerates right-to-left beyond the
  opponent plate's left edge.
- Player names are persistent and exchanged during the network handshake.
- Escape opens a lightweight pause overlay using the same dark ship-console
  modal language as Test Tools. It offers Resume, Back to Menu, and Quit.
  Returning to the menu closes active network sockets; paused games do not
  advance AI or rules decisions.
- Turn handoffs and game-end results have dedicated overlays.

Current AI decisions:

- The AI uses deterministic, logged utility scores rather than hidden cheating.
- It handles turn phases, containment, mandatory prompts, card play, Shop
  deployment/reservation, and Metroid capture.
- It evaluates and uses activated abilities during normal actions and the
  appropriate raid priority window.
- It defends raids by comparing committed totals and preserving Characters
  when they cannot change the outcome.
- Every considered candidate and final decision is written to the GameMaker
  debug output and rolling balance journal with an `[AI ...]` prefix.
- It now evaluates general activated abilities by effect, cost, source value,
  and best legal target. This includes economy, Security, removal, copying,
  attachments, Shop manipulation, and Phazon effects.
- It initiates raids only when its maximum committed attack can exceed the
  opponent's estimated maximum defense, then commits Characters until it
  exceeds that estimate.
- When defending, it uses Samus's repeatable +1 raid defense only when the CP
  can improve the outcome, then commits enough Characters to win or tie.
- Card valuation now rewards existing faction concentration and each faction's
  mechanical identity: GF economy, SP Ships/raids, CZ Metroid/removal, BH
  activations, and PZ board concentration.
- Hand refreshes are evaluated from the known composition of the AI's remaining
  deck, never its order. The AI compares each card in hand with the average
  utility of an unknown draw, selects only sufficiently weak cards, and weighs
  their combined expected improvement against the 1 CP action cost.
- Human players enter a refresh selection mode, toggle any number of cards in
  hand, then confirm or cancel. Confirmation pays 1 CP, discards the selected
  cards, and draws until the player holds five cards. A player already below
  five may select zero cards and use the action solely to refill their hand.
- Shop refreshes likewise use only the composition of the unknown Shop pool.
  The AI estimates the best useful and affordable acquisition among five
  replacement cards after paying the refresh cost, then compares that estimate
  with the best card already visible in the row.
- Both refresh actions compete directly with playing cards, capturing, raiding,
  activating abilities, and acquiring visible Shop cards. They are not
  automatic fallback actions.
- AI ready effects remember their targets for the rest of the turn so a
  ready/exhaust pair cannot cycle indefinitely. Admiral Dane specifically
  rejects an exhausted GFS Tyr when Tyr's +1 CP would merely repay Dane's 1 CP
  cost; an armed Galactic Federation HQ double is allowed because that sequence
  has a genuine net gain.
- Quiet Robe validates that two distinct available Metroids fit within the
  target Ship's Security before the Ship can be selected. Two cavern selections
  inspect the top two actual cavern Metroids rather than evaluating the top card
  twice. The AI also terminates the choice safely if an unexpected state change
  leaves no legal remaining selection.

### Balance match logs

Starting a game immediately creates a timestamped `loc_balance_*.txt` file in
`%LOCALAPPDATA%\LegacyofChozo`. GameMaker internally accesses this through its
sandboxed writable directory, but user-facing `[BALANCE]` and `[BATCH]` messages
report the canonical Local AppData path. Filename collisions use `_run_2`,
`_run_3`, and later suffixes.

The file is an append-only live journal:

- new rules events are flushed once per completed Step update;
- AI decisions are flushed immediately when recorded;
- a crash therefore preserves everything successfully written before the
  failing update;
- game end appends the completed match summary to the same file;
- match-summary or log-finalization failures cannot prevent the winner screen.

A completed journal contains:

- seed, mode, elapsed time, turn count, mutation position, and result;
- final Research, CP, Lab Hazard, Lab stage distribution, deck zones, and
  board composition for both players;
- tempo counts for captures, raid initiations/results, breaches, evolutions,
  mutation advancements, deployments, reservations, Shop refreshes, and Queen
  resolutions;
- the complete ordered rules event log;
- the complete AI decision trace captured during the match.

### AI batch runner

The title menu includes a fast AI-versus-AI batch configuration screen.

- Each AI can favor `GF`, `SP`, `CZ`, `BH`, or `PZ`, or use `NONE` for the
  normal adaptable synergy model.
- A normal VS-AI match randomly assigns its opponent any of the six acquisition
  profiles used in batch testing and presents it as an in-world identity:
  `NONE` is **Mercenary**, `GF` is **Galactic Federation**, `SP` is
  **Space Pirate**, `CZ` is **Chozo**, `BH` is **Bounty Hunter**, and `PZ` is
  **Phazon**. The combined `CZ` profile does not currently distinguish Thoha
  from Mawkin priorities.
- Slow AI-versus-AI mode independently assigns the same profile identities to
  both visible AI players. Identical-profile mirror matches remain possible;
  those names receive `Alpha` and `Beta` suffixes for clarity.
- The title screen has a persistent, default-on `FACTION STARTERS` option for
  visible AI modes. When enabled, each AI makes one identity-specific
  replacement in its ten-card neutral starter deck; Shop counts are unchanged:
  `NONE` replaces Military Rations with Armoured Frigate. `GF` and `SP` use
  provisional full faction decks described below. `CZ` replaces Ship Captain
  with a 50/50 Quiet Robe or Raven Beak, `BH`
  replaces Budget Cuts with Ghor, and `PZ` replaces one Orders Received with
  Hive Mind Communication. A Chozo identity is renamed **Thoha** when it rolls
  Quiet Robe and **Mawkin** when it rolls Raven Beak.
- The home screen uses the centered `TITLELOGO` sprite in place of a rendered
  text title, scaled uniformly to fit the available header area.
- During Slow AI-versus-AI games only, nameplate hard light reflects identity:
  grey `NONE`, cyan `GF`, red `SP`, yellow `CZ`, green `BH`, and dark blue `PZ`.
  The batch-results matrix uses the same colors for its Player 1 column and
  Player 2 row labels. These values are centralized in the `LOC_COLOR_*`
  GameMaker macros at the top of `obj_bootstrap`'s Create event.
- The game-over summary uses fitted winner titles and palette-aware player
  panels. Standard player-versus-player/AI presentation uses cyan for Player 1
  and red for Player 2; Slow AI-versus-AI uses each selected identity palette.
  Player names use their panel color. Research, CP, and total Metroids are
  displayed as `sprResearch`, `sprCommand`, and `sprMetroid` counters: each icon
  is tinted to the player's palette with its value centered over it in white.
- Favored-faction cards receive a strong utility bonus while off-profile cards
  receive a small penalty. This tests whether narrow deck focus is rewarded.
- AI archetype tags are separate from printed faction tags. They affect focused
  acquisition scoring and batch profile-card counts, but never rules-facing
  faction interactions or card presentation. The centralized
  `ai_archetypes_by_id` map currently tags P.E.D. Suit (`GF`) as supporting the
  `PZ` archetype because it consumes Phazon tokens.
- Batch matches inherit the title-screen faction-starter setting. Each result
  records whether starters were enabled and the exact starter assigned to each
  seat. Paired legs preserve the same starter for deck A and deck B when seats
  swap; this is especially important for the Thoha/Mawkin split.
- A selected matchup can run for 1, 10, 50, 100, or 500 paired seeds. Each
  seed produces two games, with the same two deck profiles swapping Player
  Slot 1 and Player Slot 2.
- Matrix mode runs all 21 unordered pairings of the five factions and `NONE`.
  Pairings with different profiles receive the mirrored two-game treatment.
- Same-profile pairings are not mirrored because swapping two identical AI
  profiles does not create a distinct seat configuration. A full matrix
  therefore runs 36 games per paired-seed count rather than 42.
- The same deck takes the first turn in both legs of a pair, isolating seat
  position from initiative. The starting deck alternates between successive
  paired seeds.
- Fast mode suppresses per-decision journals. Detailed mode retains each
  match's crash-resistant rules and AI trace journal at a substantial speed
  cost.
- The runner processes up to 500 AI decisions per rendered frame and replaces
  the board with a minimal progress display.
- Raw match results are checkpointed to CSV after every completed game.
- Each result is explicitly marked valid or invalid. Decision-safety exits
  record the pending choice, phase, turn, Mutation, event count, and last AI
  action instead of silently treating the partial state as clean data.
- Invalid games are automatically replayed once with the same seed, profiles,
  seats, and starting deck while detailed live journaling is enabled. The
  replay log path is written back to the CSV.
- The configuration screen accepts an exact numeric base seed for deterministic
  matchup reproduction; an empty field selects a fresh random seed.
- The CSV records pair ID, mirrored leg, seed, persistent deck A/B identity,
  seat assignment, starting deck, winning deck, first player, profiles,
  winner, turns, Research, CP, favored-card counts, total owned cards,
  captures, raids, breaches, evolutions, hand refreshes, and Shop refreshes.
  Per-player telemetry additionally records peak CP, captures, raids initiated
  and won, breaches suffered, final Metroid and Research totals by stage, and
  the most frequently acquired Shop card.
- Completion produces a text report summarizing wins from Player Slot 1,
  wins from Player Slot 2, two-leg sweeps ("both" seats), split pairs, draws,
  average turns, average Research, and average favored-card acquisition by
  matchup. It also includes aggregate slot and sweep results per profile.
- Completion opens a seat-oriented results matrix with Player 1 profiles across
the top and Player 2 profiles down the left. Each cell shows Player 1's win
percentage for that exact seat configuration, with whole-number values colored
on a white-at-0% to green-at-100% gradient. A bottom control toggles the cells
between percentages and Player 1's `wins/losses - draws`. The header states
the total games processed and scheduled games per seat matchup. Cells
containing any invalid games use a red background to identify contaminated
configurations.

Batch matches have independent 500-turn and AI-decision safety limits. The turn
limit prevents a strategically nonterminal game from accumulating enough board
state and history that reaching the much larger decision limit itself becomes
computationally expensive. Failsafe outcomes remain invalid/red rather than
being counted as normal game results.

Researcher requires one discard for each card it successfully draws. If the
deck and discard pile cannot supply every requested draw, only the cards actually
drawn must be discarded; drawing none creates no pending choice.

The completed batch report is paginated. Its first page is the seat-oriented
win-rate matrix. Four profile pages follow (neutral, GF, SP, and CZ), each aggregating point rate,
per-game behavior, head-to-head results, Research contribution by Metroid
stage, and the profile's most frequently acquired Shop card.

Only GF, SP, and CZ have focused acquisition profiles. A focused AI receives a
very small bonus for its own faction and a slight penalty for each of the other
two main factions on a card. BH, PZ, and NA remain neutral secondary-color
options rather than having dedicated priority brains.

Raid planning distinguishes ordinary winning raids from tactical exhaustion
raids. When an opponent has Metroids in its Lab, the AI may sacrifice an empty,
ready Ship without committing Characters if the defender must exhaust useful
Characters to win and doing so materially weakens its upcoming containment
check. The score accounts for forced Strength, resulting containment deficit,
Lab Research, raid cost, attacker value, cargo risk, and final-round pressure.

Metroid movement uses explicit presentation transits in local and network play.
Captures travel from SR388 or the Cavern to the destination Ship, and turn-start
intake travels from Ship cargo into the opening Lab drawer. Gameplay waits for
these sequences locally while both peers retain immediately synchronized rules
state. Ships render all carried Metroids in overlapping slots populated from
right to left rather than displaying only the first cargo card.

Visible matches select named leaders rather than abstract factions. Adam
Malkovich uses the GF deck and AI profile; Mother Brain uses SP; Quiet Robe and
Raven Beak use the Thoha and Mawkin CZ decks respectively; and B.S.L. Researcher
uses the neutral Mercenary configuration. Player 1 and Player 2/opponent leader
selectors appear on the title screen. Both default to Random; Random resolves to
one of the five concrete leaders at match start, and that resolved identity
persists into rematches. Batch testing continues to use faction profiles
directly.

The title screen uses a persistent game-mode column and a contextual setup
column. VS AI collects the human player's name and both deck choices; Hotseat
collects two names and two decks; Network Play collects the local name and deck,
then exposes Host and address/Join controls; AI vs AI collects two decks; and
Settings exposes camera, debug, and UI-color controls. The three local modes use
an explicit Play button. UI colors include an Auto choice that follows the
resolved leader deck's faction color during play and uses the standard cyan
accent on the title menu. Network peers exchange both names and
resolved leader identities before constructing their synchronized decks.

The provisional GF faction starter replaces the full neutral deck with two GF
Soldiers; one each of GF Marine, G.F.S. Tyr, Adam Malkovich, Biologic Space
Laboratories, Researcher, and Sloop; and two Private Military. Galactic
Federation HQ, Admiral Dane, and G.F.S. Olympus remain Shop progression pieces.

The provisional SP faction starter contains one Zebesian Pirate; one Attack
Vessel; one each of Sloop, Beam Pirate, Space Pirate Homeworld, Researcher, Ship
Captain, and Orders Received; and two Private Military. Mother Brain, Pirate
Destroyer, Frigate Orpheon, and SA-X Breaks Out remain Shop progression pieces.

The provisional CZ starter has separate Thoha and Mawkin configurations. Both
contain Samus Aran, Gunship, Researcher, Ship Captain, two Private Military,
Orders Received, and Away Team. Thoha adds Quiet Robe and Chozo Transport;
Mawkin adds Chozo Warrior and Mawkin Starship. Raven Beak remains a Shop
progression card while still serving as the persisted Mawkin identity marker.

The game-end dialog shows turn/seed information and compact
capture/raid/breach/evolution totals. Each player panel uses its identity palette,
uniform uppercase `FNT_NUMBER` names, and boxed Research, CP, and Metroid symbols.
Result, Player 1, and Player 2 tabs expose the same per-player telemetry for a
single completed match without requiring a batch run.
Their white NES-style values use visual glyph-bound centering and a dark outline
for contrast. The boxed symbols are recolored through their alpha masks so the
original cyan artwork cannot distort red, yellow, green, or Phazon palettes.

Its navigation offers two always-interactive choices, including in spectator
AI mode. `REMATCH` generates a new seed while preserving player names, AI
profiles, and exact identity starters (including Thoha/Mawkin); `BACK TO MENU`
returns to the title screen.

Test Tools includes `SIMULATE TO GAME OVER`. It temporarily gives both seats to
the AI and resolves the current match without presentation delays, then restores
the original mode/controller flags and leaves the rendered game-over screen open
for UI inspection. Test Tools remain locally interactive while an AI owns the
turn, and AI-vs-AI mode also exposes a compact `SIM` button directly in the top
HUD. Headless resolution bypasses target/effect presentation waits; a repeated-
state canary stops after 250 identical decision states, backed by the broader
200,000-decision safety limit, so a malformed choice cannot silently loop.

Local shell controls are resolved independently from rules-engine priority and
presentation locks. Escape/pause and the persistent top-row camera/debug controls
remain interactive during opening presentation, evolution, Lab intake, targeting
effects, turn handoff, and AI-controlled turns; those states suppress gameplay
actions only.

Test Tools also provides `RANDOM WIN SCREEN`, a presentation-only inspection
mode with two random AI identities and independently randomized Research, CP,
and Metroid values from 0 through 3. Its `REROLL` control regenerates the mock
result in place; `BACK TO MENU` leaves the preview.

Test Tools is divided into `GAME` and `ANIMATION` tabs. Rules-state mutation,
seed, simulation, and result-preview controls remain on Game; presentation
regression scenarios have a dedicated Animation workspace so the diagnostic UI
can expand without crowding ordinary setup tools.

The first Animation-tab scenarios invoke the production paths for hand
deployment, Event discard/replacement, Shop reservation, hand refresh, Shop
refresh, discard-to-deck recycling, SR388 evolution, Phazon-token flashing, and
Ship-to-Lab intake. Each prepares only its minimum prerequisite, closes the
modal, and records a `TEST ANIMATION` event; if the live position lacks a needed
card or Ship, the tool injects the minimum suitable instance and position needed
to run it. These are explicitly live-state tests: deployments, Events, reserves,
refreshes, recycling, evolution, Phazon gain, and Lab intake really occur and
permanently mutate the current test match. The Animation tab displays this warning
in its header and each run is recorded in the event log.

Animation scenarios are split into Movement and Interaction pages. The second
page covers SR388 capture, attachment movement, friendly and opposing target
lines, discard and destroy removal, raid targeting/cross-table framing, two
sequential Omega breaches, and the Queen event sequence. Target-line-only tests
carry an audit flag and expire without resolving a card ability; all other cases
exercise and mutate the real rules state.

Card destruction has its own presentation queue, separate from discard movement.
The removed card remains visually at its last world position for 900 ms, burns
to solid white during the first half, then the white silhouette fades completely
during the second half. The same path is used for destroyed in-play cards and
hand-origin destruction such as Torizo; the underlying card enters the removed
zone immediately and cannot be interacted with during the effect.

## 16. Current rules-engine model

The implementation keeps immutable card definitions separate from mutable card
instances and presentation assets. Its primary concepts are:

- `GameState`: active player, priority player, phase/step, mutation position, SR388 slots, cavern, Shop, supplies, removed cards, and winner
- `PlayerState`: CP, deck, hand, discard, board zones, Lab, and per-turn usage flags
- `CardDefinition`: immutable printed data from the workbook
- `CardInstance`: owner, controller, zone, ready/exhausted state, attachments, counters, and temporary modifiers
- `MetroidInstance`: stage, Hazard, Research Value, location, and special state
- `ShipState`: cargo, base capacity of one, and capacity modifiers
- `Effect`: costs, targets, conditions, resolution steps, and timing
- `PendingChoice`: explicit player decision required to continue resolution

### Runtime module layout

`obj_bootstrap` is now an orchestration object rather than the source location
for the entire program. Its Create event retains the shared faction-color macros
and invokes ordered initializer modules; Step and Draw delegate to controller
scripts. The extracted GameMaker script resources are:

- `scr_loc_bootstrap_data`: generated-data loading, definitions, instances,
  Shop/deck primitives, and dynamic sprites
- `scr_loc_bootstrap_state`: presentation queues and initial game state
- `scr_loc_rules`: factions, stats, containment, mutation, scoring, Queen, and
  game-end resolution
- `scr_loc_actions`: deployment, reserve, Events, refresh, capture, and Quiet Robe
- `scr_loc_abilities`: activated-ability definitions, costs, targeting, and
  resolution
- `scr_loc_raids`: raid selection, contribution, abilities, cargo, and resolution
- `scr_loc_modes_testing`: game modes, identity starters, rematches, debug
  simulation, win previews, and animation scenarios
- `scr_loc_batch`: batch schedules, paired seeds, reports, and match completion
- `scr_loc_network`: direct-IP setup, synchronized inputs, and restart support
- `scr_loc_ai`: acquisition heuristics, abilities, raids, pending choices, and
  controller stepping
- `scr_loc_regression`: deterministic rules regression cases
- `scr_loc_developer_ui`: test helpers, remaining UI-state initialization, and AI
  diagnostics
- `scr_loc_step`: frame/input/presentation controller
- `scr_loc_draw`: board and HUD renderer

The module initializer order deliberately matches the former Create-event order,
so existing instance-scoped functions and state retain their behavior while the
large object event is reduced to explicit subsystem calls.
- `GameEvent`: an auditable state-change record such as `CP_GAINED`, `CARD_EXHAUSTED`, `METROID_EVOLVED`, or `BREACH_OCCURRED`

Random results, including first player, evolution rolls, and shuffles, use the
shared seeded random state. AI mode randomizes its seed by default; recorded
seeds allow a match to be reproduced.

## 17. Current playable scope

The first playable scope is complete:

1. Two copies of the Neutral starter deck.
2. Shop acquire/refill/refresh.
3. Player draw, hand, discard, and reshuffle.
4. CP economy and turn phases.
5. SR388 capture, automatic Ship-to-Lab movement, evolution, containment, and scoring.
6. Characters, Ships, Locations, Events, attachments, and their printed
   effects.
7. Raids, including Ship destruction and cargo loss or transfer.
8. Activated and passive card effects, targeting, costs, and pending choices.
9. Phazon tokens, interactions, corruption, and Hunter Metroids.

This scope supports human playtesting and recorded AI matches for game length,
CP pressure, capture rate, raid frequency, breach rate, card use, and scoring
pace. Automated AI-versus-AI batches and cross-match aggregation are the next
balance-instrumentation milestone.

## 18. Glossary

- **Activate:** Use a card ability and pay its listed costs.
- **Breach:** Failure of a Containment Check; a highest-stage Metroid escapes and its owner discards a Character if able.
- **Capture:** Move a Metroid from SR388 or another Ship onto a Ship you control.
- **Command Points (CP):** Currency used for cards, actions, and effects.
- **Containment Check:** Start-of-turn comparison of ready Character Strength plus optional Ship Security against Lab Hazard.
- **Deploy:** Pay the higher Shop price to put a Shop card directly into play.
- **Destroy:** Remove a card from the game permanently.
- **Evolve:** Replace a Metroid with its next stage.
- **Exhaust:** Mark a card unavailable until it is readied.
- **Hazard:** A Metroid's containment difficulty.
- **Lab:** Player zone holding secured Metroids for scoring.
- **Mutation Track:** Global game-end countdown advanced by evolution and card effects.
- **Phazon token:** A board-only corruption counter; exhausting at the corruption threshold causes the card to be discarded.
- **Priority:** Permission to activate effects at the current point in the turn or structured procedure.
- **Ready:** Available to act or contribute.
- **Reserve:** Pay the lower Shop price to put a card into the player's discard pile.
- **Research Value:** Victory-point value of a Metroid.
- **Security:** A Ship's capture, containment, and raid value.
- **Stage:** A Metroid's evolution level.
- **Strength:** A Character's containment value.
