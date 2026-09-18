function loc_regression() {
    run_regression_suite = function() {
        var _saved_game_state = game_state;
        var _saved_pending_choice = pending_choice;
        var _saved_containment = containment_resolution;
        var _saved_special = special_containment_sequence;
        var _saved_chozo_ghosts_end_turn = chozo_ghosts_end_turn;
        var _saved_gf_soldier_breach_sequence = gf_soldier_breach_sequence;
        var _saved_next_card_id = next_card_instance_id;
        var _saved_next_metroid_id = next_metroid_instance_id;
        var _saved_faction_starters_enabled = faction_starters_enabled;
        var _saved_breaching_mutation =
            settings_experimental_breaching_mutation;
        var _saved_loaded_ships_exhausted =
            settings_experimental_loaded_ships_exhausted;
        settings_experimental_breaching_mutation = false;
        settings_experimental_loaded_ships_exhausted = false;
        var _assert_context = {passed: 0, failed: 0, lines: []};
        var _assert = method(_assert_context, function(
            _condition,
            _name,
            _detail
        ) {
            if (_condition) {
                passed += 1;
                array_push(lines, "PASS: " + _name);
                show_debug_message("REGRESSION PASS: " + _name);
            } else {
                failed += 1;
                array_push(
                    lines,
                    "FAIL: " + _name + " - " + _detail
                );
                show_debug_message(
                    "REGRESSION FAIL: " + _name + " - " + _detail
                );
            }
            global.loc_regression_progress = {
                passed: passed,
                failed: failed,
                current: _name
            };
        });
        var _reset = function() {
            pending_choice = undefined;
            containment_resolution = undefined;
            special_containment_sequence = undefined;
            chozo_ghosts_end_turn = undefined;
            gf_soldier_breach_sequence = undefined;
            game_state = {
                seed: 388,
                started_at_ms: current_time,
                turn_number: 1,
                active_player: 0,
                priority_player: 0,
                view_player: 0,
                game_mode: "regression",
                phase: "action",
                mutation: 0,
                mutation_limit: 8,
                final_round_active: false,
                final_round_end_player: -1,
                final_round_reason: "",
                players: [make_player_state(0), make_player_state(1)],
                shop_deck: [],
                shop_row: [],
                shop_discard: [],
                sr388: [
                    undefined,
                    undefined,
                    undefined,
                    undefined
                ],
                cavern: [],
                removed_cards: [],
                event_log: [],
                match_summary: "",
                balance_log_path: ""
            };
        };
        try {
            global.loc_regression_progress = {
                passed: 0,
                failed: 0,
                current: "Starting regression tests"
            };
            show_debug_message("REGRESSION: starting suite");
            _reset();
            var _relic_player = game_state.players[0];
            var _relic_definition = variable_clone(get_card_definition("loc.gray_voice"));
            _relic_definition.definition_id = "test.relic";
            _relic_definition.name = "Test Relic";
            _relic_definition.type = "relic";
            var _relic = make_card_instance(_relic_definition, 0, "hand");
            _assert(put_card_in_play(_relic_player, _relic)
                && array_length(_relic_player.board.relics) == 1
                && array_length(_relic_player.board.locations) == 0
                && array_length(_relic_player.board.characters) == 0,
                "Relics enter their own permanent zone", "Expected only one Relic.");
            _assert(get_ability_source("relic", 0) == _relic,
                "Relics are ability sources", "Expected the deployed Relic.");
            _assert(get_ready_character_strength(_relic_player) == 0,
                "Relics supply no containment Strength", "Expected zero Strength.");
            _relic.ready = false;
            _assert(!can_salvage_permanent("relic", 0),
                "Exhausted Relics cannot be salvaged", "Expected salvage rejection.");
            resolve_ready_phase();
            _assert(_relic.ready && can_salvage_permanent("relic", 0),
                "Relics ready and become salvageable", "Expected a ready Relic.");
            var _relic_source = make_card_instance(get_card_definition("loc.gray_voice"), 1, "board");
            _assert(can_resolve_ability_target(
                {target_kind: "another_permanent", source: _relic_source}, "relic", 0)
                && !can_resolve_ability_target(
                    {target_kind: "any_location", source: _relic_source}, "relic", 0),
                "Relics are permanent targets but not Location targets",
                "Expected permanent-only targeting.");
            var _relic_refund = get_salvage_refund(_relic);
            var _relic_cp = _relic_player.command_points;
            _assert(salvage_permanent("relic", 0)
                && array_length(_relic_player.board.relics) == 0
                && array_length(_relic_player.discard) == 1
                && _relic_player.command_points == _relic_cp + _relic_refund,
                "Relic salvage discards and refunds CP", "Expected a cleared Relic zone and refund.");
            _reset();
            var _gray = make_card_instance(
                get_card_definition("loc.gray_voice"), 0, "board"
            );
            array_push(game_state.players[0].board.characters, _gray);
            game_state.players[0].command_points = 0;
            _assert(
                get_capture_cost(game_state.players[0]) == 0,
                "Ready Gray Voice makes Capture free",
                "Expected 0 CP."
            );
            _gray.ready = false;
            _assert(
                get_capture_cost(game_state.players[0]) == 1,
                "Exhausted Gray Voice stops discounting Capture",
                "Expected 1 CP."
            );

            _reset();
            var _old_bird_player = game_state.players[0];
            array_push(
                _old_bird_player.board.characters,
                make_card_instance(
                    get_card_definition("loc.old_bird"), 0, "board"
                )
            );
            array_push(
                _old_bird_player.lab,
                make_metroid_instance(
                    get_metroid_definition("metroid.larva"), "lab"
                )
            );
            array_push(
                _old_bird_player.lab,
                make_metroid_instance(
                    get_metroid_definition("metroid.omega"), "lab"
                )
            );
            _assert(
                get_lab_hazard(_old_bird_player) == 6,
                "Old Bird sets every Lab Metroid to 3 Hazard",
                "Expected two Metroids to total exactly 6 Hazard."
            );

            _reset();
            settings_experimental_loaded_ships_exhausted = true;
            var _loaded_test_ship = make_card_instance(
                get_card_definition("loc.attack_vessel"), 0, "board"
            );
            var _empty_test_ship = make_card_instance(
                get_card_definition("loc.g_f_s_tyr"), 0, "board"
            );
            _loaded_test_ship.ready = false;
            _empty_test_ship.ready = false;
            array_push(
                _loaded_test_ship.cargo,
                make_metroid_instance(
                    get_metroid_definition("metroid.larva"), "cargo"
                )
            );
            var _ready_test_ships = [_loaded_test_ship, _empty_test_ship];
            array_push(
                game_state.players[0].board.ships,
                _loaded_test_ship
            );
            resolve_lab_intake();
            ready_card_array(_ready_test_ships, true);
            _assert(
                !_loaded_test_ship.ready
                && _empty_test_ship.ready
                && array_length(_loaded_test_ship.cargo) == 0
                && array_length(game_state.players[0].lab) == 1
                && !_loaded_test_ship.skip_ready_after_lab_intake,
                "Ships loaded at turn start skip readying after Lab intake",
                "Cargo failed to move or the intake marker did not suppress exactly one Ready phase."
            );
            settings_experimental_loaded_ships_exhausted = false;

            _reset();
            var _back_player = game_state.players[0];
            var _back_removed = make_card_instance(
                get_card_definition("loc.back_in_the_day"), 0, "removed"
            );
            array_push(game_state.removed_cards, _back_removed);
            var _back_shop_copy = make_card_instance(
                get_card_definition("loc.back_in_the_day"), -1, "shop_deck"
            );
            array_push(game_state.shop_deck, _back_shop_copy);
            begin_back_in_the_day_choice(_back_player);
            var _back_self_qualified = !is_undefined(pending_choice)
                && pending_choice.kind == "back_in_the_day"
                && raid_array_contains(
                    pending_choice.candidate_ids, "loc.back_in_the_day"
                );
            resolve_back_in_the_day_choice(0);
            _assert(
                _back_self_qualified
                && array_length(game_state.shop_deck) == 0
                && array_length(_back_player.discard) == 1
                && _back_player.discard[0].definition_id
                    == "loc.back_in_the_day",
                "Back In the Day can qualify itself after removal",
                "The Shop copy was not found and moved to the player's discard."
            );

            _reset();
            var _hyper_player = game_state.players[0];
            var _hyper_character = make_card_instance(
                get_card_definition("loc.gf_marine"), 0, "board"
            );
            var _hyper_ship = make_card_instance(
                get_card_definition("loc.attack_vessel"), 0, "board"
            );
            var _hyper_location = make_card_instance(
                get_card_definition("loc.ready_room"), 0, "board"
            );
            var _hyper_attachment = make_card_instance(
                get_card_definition("loc.gf_soldier"), 0, "attachment"
            );
            _hyper_character.phazon_tokens = 1;
            _hyper_ship.phazon_tokens = 1;
            _hyper_location.phazon_tokens = 1;
            _hyper_attachment.phazon_tokens = 1;
            array_push(_hyper_character.attachments, _hyper_attachment);
            array_push(_hyper_player.board.characters, _hyper_character);
            array_push(_hyper_player.board.ships, _hyper_ship);
            array_push(_hyper_player.board.locations, _hyper_location);
            begin_hyper_mode_choice(_hyper_player);
            var _hyper_choice_ready = !is_undefined(pending_choice)
                && pending_choice.kind == "hyper_mode_character"
                && pending_choice.tokens_removed == 4
                && _hyper_character.phazon_tokens == 0
                && _hyper_ship.phazon_tokens == 0
                && _hyper_location.phazon_tokens == 0
                && _hyper_attachment.phazon_tokens == 0;
            resolve_hyper_mode_character(0);
            _assert(
                _hyper_choice_ready
                && is_undefined(pending_choice)
                && _hyper_character.phazon_tokens == 4,
                "Hyper Mode consolidates removed Phazon onto one Character",
                "Tokens were not removed from every controlled card or placed together."
            );

            _reset();
            var _source = make_card_instance(
                get_card_definition("loc.gf_soldier"), 0, "board"
            );
            var _target = make_card_instance(
                get_card_definition("loc.gf_marine"), 0, "board"
            );
            array_push(game_state.players[0].board.characters, _source);
            array_push(game_state.players[0].board.characters, _target);
            pending_choice = {
                kind: "ability_target",
                source: _source,
                source_kind: "character",
                source_index: 0,
                target_kind: "another_character",
                ability: {
                    effect_kind: "discard_card",
                    cost_cp: 0,
                    cost_exhaust: false,
                    cost_destroy: true
                }
            };
            var _shift_resolved =
                resolve_ability_target_choice("character", 1);
            _assert(
                _shift_resolved
                && array_length(game_state.players[0].board.characters) == 0
                && array_length(game_state.removed_cards) == 1
                && array_length(game_state.players[0].discard) == 1,
                "Destroying a source preserves its shifted target",
                "Source or target landed in the wrong zone."
            );

            _reset();
            var _double_source = make_card_instance(
                get_card_definition("loc.gf_soldier"), 0, "board"
            );
            var _double_target = make_card_instance(
                get_card_definition("loc.gf_marine"), 0, "board"
            );
            array_push(
                game_state.players[0].board.characters,
                _double_source
            );
            array_push(
                game_state.players[0].board.characters,
                _double_target
            );
            var _discard_ability = {
                effect_kind: "discard_card",
                cost_cp: 0,
                cost_exhaust: false,
                cost_destroy: false
            };
            var _first_resolution = resolve_activated_ability(
                _double_source, _discard_ability, "character", 1
            );
            var _second_resolution = resolve_activated_ability(
                _double_source, _discard_ability, "character", 1
            );
            _assert(
                _first_resolution && !_second_resolution,
                "A doubled effect tolerates a vanished target",
                "The empty second resolution did not fail safely."
            );

            _reset();
            var _mawkin_source = make_card_instance(
                get_card_definition("loc.mawkin_starship"), 0, "board"
            );
            var _mawkin_target = make_card_instance(
                get_card_definition("loc.g_f_s_tyr"), 1, "board"
            );
            var _mawkin_flagship = make_card_instance(
                get_card_definition("loc.g_f_s_olympus"), 1, "board"
            );
            array_push(
                game_state.players[0].board.ships,
                _mawkin_source
            );
            array_push(
                game_state.players[1].board.ships,
                _mawkin_target
            );
            array_push(
                game_state.players[1].board.ships,
                _mawkin_flagship
            );
            game_state.players[0].command_points = 3;
            pending_choice = {
                kind: "ability_target",
                source: _mawkin_source,
                source_kind: "ship",
                source_index: 0,
                target_kind: "mawkin_ship",
                ability: {
                    effect_kind: "discard_card",
                    cost_cp: 3,
                    cost_exhaust: true,
                    cost_destroy: false
                }
            };
            var _mawkin_resolved = resolve_ability_target_choice(
                "opponent_ship", 0
            );
            _assert(
                _mawkin_resolved
                && !_mawkin_source.ready
                && _mawkin_source.phazon_tokens == 2
                && array_length(game_state.players[1].board.ships) == 1
                && game_state.players[1].board.ships[0].definition_id
                    == "loc.g_f_s_olympus"
                && array_length(game_state.players[1].discard) == 1,
                "Mawkin Starship discards an eligible Ship and gains two Phazon",
                "The eligible Ship or post-resolution Phazon cost was not applied."
            );
            _assert(
                !can_resolve_ability_target(
                    {
                        source: _mawkin_source,
                        target_kind: "mawkin_ship",
                        ability: {effect_kind: "discard_card"}
                    },
                    "opponent_ship",
                    0
                ),
                "Mawkin Starship rejects Ships above its Security",
                "G.F.S. Olympus was accepted despite exceeding Mawkin Starship's Security."
            );

            _reset();
            var _dark_samus = make_card_instance(
                get_card_definition("lop.dark_samus"), 0, "board"
            );
            _dark_samus.phazon_tokens = 2;
            var _dark_samus_choice = {
                source: _dark_samus,
                target_kind: "dark_samus_character"
            };
            _assert(
                !can_resolve_ability_target(
                    _dark_samus_choice,
                    "metroid",
                    0
                ),
                "Dark Samus rejects an SR388 Metroid target",
                "A non-Character target was accepted or caused an error."
            );

            _reset();
            var _immune_dark_samus = make_card_instance(
                get_card_definition("lop.dark_samus"), 0, "board"
            );
            _immune_dark_samus.phazon_tokens = 3;
            var _phazon_donor = make_card_instance(
                get_card_definition("loc.gf_marine"), 0, "board"
            );
            _phazon_donor.phazon_tokens = 1;
            array_push(game_state.players[0].board.characters, _immune_dark_samus);
            array_push(game_state.players[0].board.characters, _phazon_donor);
            var _consolidate_ability = {
                effect_kind: "dark_samus_consolidate",
                cost_cp: 0,
                cost_exhaust: true,
                cost_destroy: false
            };
            var _consolidated = resolve_activated_ability(
                _immune_dark_samus,
                _consolidate_ability,
                "character",
                1
            );
            _assert(
                _consolidated
                && _immune_dark_samus.phazon_tokens == 4
                && _phazon_donor.phazon_tokens == 0
                && !card_discards_from_phazon(_immune_dark_samus),
                "Dark Samus consolidates Phazon and survives accumulation",
                "Her token transfer or Phazon-discard immunity failed."
            );

            _reset();
            game_state.phase = "action";
            game_state.active_player = 0;
            game_state.priority_player = 0;
            game_state.players[0].command_points = 1;
            var _multi_dark_samus = make_card_instance(
                get_card_definition("lop.dark_samus"), 0, "board"
            );
            _multi_dark_samus.phazon_tokens = 3;
            array_push(
                game_state.players[0].board.characters,
                _multi_dark_samus
            );
            for (var _multi_target_index = 0;
                 _multi_target_index < 3;
                 _multi_target_index++) {
                var _multi_target = make_card_instance(
                    get_card_definition("loc.gf_marine"), 1, "board"
                );
                _multi_target.temporary_stat_bonus =
                    (_multi_target_index < 2 ? 1 : 2)
                    - get_card_stat(_multi_target);
                array_push(
                    game_state.players[1].board.characters,
                    _multi_target
                );
            }
            var _multi_started = activate_selected_ability(
                "character", 0, 0
            );
            var _multi_first = toggle_dark_samus_discard_target(
                "opponent_character", 0
            );
            var _multi_second = toggle_dark_samus_discard_target(
                "opponent_character", 1
            );
            var _multi_over_budget = toggle_dark_samus_discard_target(
                "opponent_character", 2
            );
            var _multi_confirmed = confirm_dark_samus_discard();
            _assert(
                _multi_started && _multi_first && _multi_second
                && !_multi_over_budget && _multi_confirmed
                && array_length(game_state.players[1].board.characters) == 1
                && _multi_dark_samus.phazon_tokens == 0,
                "Dark Samus discards multiple Characters within one Strength budget",
                "Multi-selection exceeded its budget or discarded the wrong cards."
            );

            _reset();
            game_state.phase = "action";
            game_state.active_player = 0;
            game_state.priority_player = 0;
            var _salvage_card = make_card_instance(
                get_card_definition("loc.gf_marine"), 0, "board"
            );
            array_push(game_state.players[0].board.characters, _salvage_card);
            _salvage_card.ready = false;
            var _exhausted_salvage_rejected = !can_salvage_permanent(
                "character", 0
            );
            _salvage_card.ready = true;
            var _salvage_cp_before = game_state.players[0].command_points;
            var _expected_salvage = floor(
                _salvage_card.definition.costs.reserve * 0.5
            );
            var _salvaged = salvage_permanent("character", 0);
            _assert(
                _exhausted_salvage_rejected && _salvaged
                && array_length(game_state.players[0].board.characters) == 0
                && array_length(game_state.players[0].discard) == 1
                && game_state.players[0].command_points
                    == _salvage_cp_before + _expected_salvage,
                "Salvage requires a ready permanent and refunds half Reserve cost",
                "An exhausted card was eligible, or the zone/refund was incorrect."
            );

            _reset();
            var _profile_player = game_state.players[0];
            var _profile_gf_card = make_card_instance(
                get_card_definition("loc.gf_marine"), 0, "shop"
            );
            var _profile_bh_card = make_card_instance(
                get_card_definition("loc.gandrayda"), 0, "shop"
            );
            _profile_player.favored_faction = "";
            var _gf_neutral_value = ai_card_utility(
                _profile_gf_card,
                _profile_player
            );
            var _bh_neutral_value = ai_card_utility(
                _profile_bh_card,
                _profile_player
            );
            _profile_player.favored_faction = "GF";
            var _gf_own_value = ai_card_utility(
                _profile_gf_card,
                _profile_player
            );
            var _bh_for_gf_value = ai_card_utility(
                _profile_bh_card,
                _profile_player
            );
            _profile_player.favored_faction = "SP";
            var _gf_for_sp_value = ai_card_utility(
                _profile_gf_card,
                _profile_player
            );
            _assert(
                abs(_gf_own_value - _gf_neutral_value) < 0.001
                && abs(_gf_for_sp_value - _gf_neutral_value) < 0.001
                && abs(_bh_for_gf_value - _bh_neutral_value) < 0.001,
                "AI card utility is derived without faction preference drift",
                "Changing the favored profile changed semantic card utility."
            );

            _reset();
            var _telemetry_player = game_state.players[0];
            _telemetry_player.command_points = 7;
            telemetry_update_max_cp(_telemetry_player);
            var _telemetry_card = make_card_instance(
                get_card_definition("loc.gf_marine"), 0, "discard"
            );
            telemetry_record_card_taken(_telemetry_player, _telemetry_card);
            telemetry_record_card_taken(_telemetry_player, _telemetry_card);
            var _telemetry_metroid = make_metroid_instance(
                get_metroid_definition("metroid.alpha"), "lab"
            );
            _telemetry_metroid.zone = "lab";
            array_push(_telemetry_player.lab, _telemetry_metroid);
            var _telemetry_snapshot = batch_player_telemetry_snapshot(
                _telemetry_player
            );
            _assert(
                _telemetry_snapshot.max_cp == 7
                && _telemetry_snapshot.most_taken_id == "loc.gf_marine"
                && _telemetry_snapshot.most_taken_count == 2
                && _telemetry_snapshot.metroid_counts[1] == 1
                && batch_array_total(_telemetry_snapshot.metroid_counts) == 1
                && _telemetry_snapshot.metroid_research[1]
                    == _telemetry_metroid.definition.research_value,
                "Player telemetry records CP, cards, and scored Metroids",
                "The telemetry snapshot lost or misclassified a counter."
            );

            _reset();
            game_state.mutation = 4;
            game_state.sr388[0] = create_metroid_for_stage(4);
            evolve_sr388_slot(0);
            _assert(
                game_state.mutation == 6
                && game_state.sr388[0].definition_id == "metroid.omega",
                "Late-game Omega births advance Mutation twice",
                "A Zeta evolving at Mutation 4 did not advance to 6."
            );

            _reset();
            game_state.mutation = 3;
            game_state.sr388[0] = create_metroid_for_stage(4);
            evolve_sr388_slot(0);
            _assert(
                game_state.mutation == 4,
                "Early Omega births still advance Mutation once",
                "The late-game acceleration started before Mutation 4."
            );

            _reset();
            var _queen_test_ids = [
                "loc.gf_marine",
                "loc.ghor",
                "loc.attack_vessel",
                "loc.quiet_robe",
                "loc.gf_soldier"
            ];
            for (var _queen_deck_setup_index = 0;
                 _queen_deck_setup_index < array_length(_queen_test_ids);
                 _queen_deck_setup_index++) {
                array_push(game_state.shop_deck, make_card_instance(
                    get_card_definition(
                        _queen_test_ids[_queen_deck_setup_index]
                    ),
                    -1,
                    "shop_deck"
                ));
            }
            // array_pop draws Queen first, with four more cards still needed.
            array_push(game_state.shop_deck, make_card_instance(
                get_card_definition("loc.queen_metroid_awakens"),
                -1,
                "shop_deck"
            ));
            refill_shop();
            _assert(
                array_length(game_state.shop_row) == 5
                && is_undefined(pending_choice)
                && array_length(game_state.shop_deck) == 1
                && game_state.shop_deck[0].definition_id
                    == "loc.queen_metroid_awakens",
                "Queen resolves after the Shop fills and receives a replacement",
                "Queen interrupted refill or immediately replaced itself."
            );

            _reset();
            var _host = make_card_instance(
                get_card_definition("loc.gf_marine"), 0, "board"
            );
            var _attachment = make_card_instance(
                get_card_definition("lop.aurora_unit_217"), 0, "attachment"
            );
            array_push(_host.attachments, _attachment);
            clear_card_board_state(_host);
            _assert(
                array_length(_host.attachments) == 0
                && array_length(game_state.players[0].discard) == 1
                && game_state.players[0].discard[0].instance_id
                    == _attachment.instance_id,
                "Attachments discard when their host leaves play",
                "Attachment cleanup did not preserve ownership and destination."
            );

            _reset();
            var _breach_character = make_card_instance(
                get_card_definition("loc.gf_marine"), 0, "board"
            );
            array_push(
                game_state.players[0].board.characters,
                _breach_character
            );
            array_push(
                game_state.players[0].lab,
                create_metroid_for_stage(5)
            );
            begin_special_containment(
                [{
                    player_index: 0,
                    bonus_hazard: 0,
                    forced_breach: false
                }],
                "sa_x",
                -1
            );
            choose_special_containment_ship(-1);
            var _breach_prompted = !is_undefined(pending_choice)
                && pending_choice.kind == "breach_character";
            resolve_breach_character_choice(0);
            _assert(
                _breach_prompted
                && is_undefined(special_containment_sequence)
                && array_length(game_state.players[0].lab) == 0,
                "Special Omega containment advances after its casualty",
                "The special sequence or Lab did not finish cleanly."
            );

            _reset();
            var _corrupted_source = make_card_instance(
                get_card_definition("loc.gf_soldier"), 0, "board"
            );
            _corrupted_source.phazon_tokens = 3;
            array_push(
                game_state.players[0].board.characters,
                _corrupted_source
            );
            pay_activated_ability_cost(
                "character",
                0,
                _corrupted_source,
                {
                    effect_kind: "gain_cp",
                    cost_cp: 0,
                    cost_exhaust: true,
                    cost_destroy: false
                }
            );
            _assert(
                array_length(game_state.players[0].board.characters) == 0
                && array_length(game_state.players[0].discard) == 1
                && game_state.players[0].discard[0].phazon_tokens == 0,
                "A corrupted card discards after exhausting as a cost",
                "The source remained in play or retained board-only corruption."
            );

            _reset();
            for (var _queen_row_index = 0;
                 _queen_row_index < 3;
                 _queen_row_index++) {
                array_push(
                    game_state.shop_row,
                    make_card_instance(
                        get_card_definition("loc.gf_marine"),
                        -1,
                        "shop"
                    )
                );
            }
            var _queen_card = make_card_instance(
                get_card_definition("loc.queen_metroid_awakens"),
                -1,
                "shop"
            );
            array_push(game_state.shop_row, _queen_card);
            var _second_queen_card = make_card_instance(
                get_card_definition("loc.queen_metroid_awakens"),
                -1,
                "shop"
            );
            array_push(game_state.shop_row, _second_queen_card);
            for (var _queen_discard_index = 0;
                 _queen_discard_index < 3;
                 _queen_discard_index++) {
                array_push(
                    game_state.shop_discard,
                    make_card_instance(
                        get_card_definition("loc.gf_soldier"),
                        -1,
                        "shop_discard"
                    )
                );
            }
            pending_choice = {
                kind: "queen_event",
                stage: "resolved",
                shop_index: 3,
                prompt: ""
            };
            random_set_seed(388);
            finish_queen_shop_event();
            var _queen_returned_to_deck = false;
            var _queen_count_in_deck = 0;
            for (var _queen_deck_index = 0;
                 _queen_deck_index < array_length(game_state.shop_deck);
                 _queen_deck_index++) {
                if (game_state.shop_deck[_queen_deck_index].definition_id
                == "loc.queen_metroid_awakens") {
                    _queen_count_in_deck += 1;
                }
                if (game_state.shop_deck[_queen_deck_index].instance_id
                    == _queen_card.instance_id) {
                    _queen_returned_to_deck = true;
                }
            }
            var _queen_left_in_row = false;
            for (var _queen_check_row_index = 0;
                 _queen_check_row_index < array_length(game_state.shop_row);
                 _queen_check_row_index++) {
                if (game_state.shop_row[_queen_check_row_index].definition_id
                == "loc.queen_metroid_awakens") {
                    _queen_left_in_row = true;
                    break;
                }
            }
            _assert(
                array_length(game_state.shop_row) == 5
                && array_length(game_state.shop_deck) == 3
                && array_length(game_state.shop_discard) == 0
                && _queen_returned_to_deck
                && _queen_count_in_deck == 2
                && !_queen_left_in_row
                && is_undefined(pending_choice),
                "Queen cleanup removes every visible Queen before replacement",
                "A Queen was lost, left face-up, or immediately redrawn."
            );

            _reset();
            var _adam = make_card_instance(
                get_card_definition("loc.adam_malkovich"), 0, "board"
            );
            var _adam_casualty = make_card_instance(
                get_card_definition("loc.gf_marine"), 0, "board"
            );
            array_push(game_state.players[0].board.characters, _adam);
            array_push(
                game_state.players[0].board.characters,
                _adam_casualty
            );
            array_push(
                game_state.players[0].lab,
                create_metroid_for_stage(5)
            );
            begin_special_containment(
                [{
                    player_index: 0,
                    bonus_hazard: 0,
                    forced_breach: false
                }],
                "sa_x",
                -1
            );
            choose_special_containment_ship(-1);
            var _adam_prompted = !is_undefined(pending_choice)
                && pending_choice.kind == "adam_breach";
            var _adam_ai_accepts = _adam_prompted
                && ai_should_use_adam(pending_choice);
            resolve_adam_breach_choice(false);
            var _adam_breach_prompted = !is_undefined(pending_choice)
                && pending_choice.kind == "breach_character";
            resolve_breach_character_choice(1);
            _assert(
                _adam_prompted
                && _adam_ai_accepts
                && _adam_breach_prompted
                && is_undefined(special_containment_sequence),
                "Adam evaluates a catastrophic breach and special containment advances",
                "Adam misvalued the Omega cascade or its optional prompt stalled."
            );

            _reset();
            array_push(
                game_state.players[0].board.characters,
                make_card_instance(
                    get_card_definition("loc.gf_marine"), 0, "board"
                )
            );
            array_push(
                game_state.players[0].board.characters,
                make_card_instance(
                    get_card_definition("loc.gf_soldier"), 0, "board"
                )
            );
            array_push(game_state.players[0].lab, create_metroid_for_stage(5));
            array_push(game_state.players[0].lab, create_metroid_for_stage(5));
            begin_containment_sequence(0, 0, -1, false, "turn");
            var _first_omega_prompt = !is_undefined(pending_choice)
                && pending_choice.kind == "breach_character";
            resolve_breach_character_choice(1);
            var _second_omega_prompt = !is_undefined(pending_choice)
                && pending_choice.kind == "breach_character";
            resolve_breach_character_choice(0);
            _assert(
                _first_omega_prompt
                && _second_omega_prompt
                && array_length(game_state.players[0].lab) == 0
                && is_undefined(containment_resolution),
                "Multiple Omegas breach sequentially",
                "The second breach did not receive its own casualty resolution."
            );

            _reset();
            array_push(game_state.players[0].lab, create_metroid_for_stage(5));
            array_push(
                game_state.players[0].lab,
                make_metroid_instance(
                    get_metroid_definition("metroid.hunter"),
                    "lab"
                )
            );
            _assert(
                find_next_breaching_metroid(game_state.players[0]) == 1,
                "Hunter Metroids receive first breach priority",
                "The higher normal stage was selected before the Hunter."
            );

            _reset();
            var _multi_host = make_card_instance(
                get_card_definition("loc.gf_marine"), 0, "board"
            );
            var _attachment_one = make_card_instance(
                get_card_definition("lop.aurora_unit_217"), 0, "attachment"
            );
            var _attachment_two = make_card_instance(
                get_card_definition("lop.p_e_d_suit"), 0, "attachment"
            );
            array_push(_multi_host.attachments, _attachment_one);
            array_push(_multi_host.attachments, _attachment_two);
            clear_card_board_state(_multi_host);
            _assert(
                array_length(_multi_host.attachments) == 0
                && array_length(game_state.players[0].discard) == 2,
                "Multiple attachments all discard with their host",
                "At least one attachment survived or skipped the discard."
            );

            _reset();
            var _ped_host = make_card_instance(
                get_card_definition("loc.gf_marine"), 0, "board"
            );
            var _ped_suit = make_card_instance(
                get_card_definition("lop.p_e_d_suit"), 0, "attachment"
            );
            _ped_host.phazon_tokens = 1;
            array_push(_ped_host.attachments, _ped_suit);
            array_push(game_state.players[0].board.characters, _ped_host);
            resolve_end_turn_attachments();
            _assert(
                _ped_host.phazon_tokens == 2
                && array_length(game_state.players[0].discard) == 0,
                "P.E.D. Suit grants Phazon at end of its controller's turn",
                "The attached host did not gain exactly one Phazon token."
            );
            game_state.active_player = 1;
            resolve_end_turn_attachments();
            _assert(
                _ped_host.phazon_tokens == 2
                && array_length(game_state.players[0].board.characters) == 1
                && array_length(game_state.players[0].discard) == 0,
                "P.E.D. Suit does not trigger on the opponent's turn",
                "The attached host gained Phazon during the opponent's turn."
            );
            game_state.active_player = 0;
            resolve_end_turn_attachments();
            _assert(
                _ped_host.phazon_tokens == 3
                && array_length(game_state.players[0].board.characters) == 1
                && array_length(game_state.players[0].discard) == 0,
                "P.E.D. Suit Phazon gain does not count as exhausting",
                "The host was discarded merely for reaching three tokens."
            );

            _reset();
            var _transport_evolution_ship = make_card_instance(
                get_card_definition("loc.chozo_transport"), 0, "board"
            );
            var _transport_gamma = create_metroid_for_stage(3);
            _transport_gamma.zone = "ship";
            _transport_gamma.host_ship_instance_id =
                _transport_evolution_ship.instance_id;
            array_push(_transport_evolution_ship.cargo, _transport_gamma);
            array_push(
                game_state.players[0].board.ships,
                _transport_evolution_ship
            );
            resolve_end_turn_attachments();
            _assert(
                _transport_evolution_ship.cargo[0].definition.stage == 4
                && game_state.mutation == 1,
                "Chozo Transport evolves its cargo at end of its controller's turn",
                "The carried Gamma failed to become a Zeta with normal Mutation."
            );
            game_state.active_player = 1;
            resolve_end_turn_attachments();
            _assert(
                _transport_evolution_ship.cargo[0].definition.stage == 4
                && game_state.mutation == 1,
                "Chozo Transport does not evolve cargo on an opponent's turn",
                "The carried Metroid evolved outside its controller's end step."
            );

            _reset();
            var _teleport_station = make_card_instance(
                get_card_definition("loc.teleport_station"), 0, "board"
            );
            var _teleport_source_ship = make_card_instance(
                get_card_definition("loc.light_shuttle"), 0, "board"
            );
            var _teleport_destination_ship = make_card_instance(
                get_card_definition("loc.chozo_transport"), 0, "board"
            );
            var _teleport_metroid = create_metroid_for_stage(2);
            _teleport_metroid.zone = "ship";
            _teleport_metroid.host_ship_instance_id =
                _teleport_source_ship.instance_id;
            array_push(_teleport_source_ship.cargo, _teleport_metroid);
            array_push(
                game_state.players[0].board.characters,
                _teleport_station
            );
            array_push(
                game_state.players[0].board.ships,
                _teleport_source_ship
            );
            array_push(
                game_state.players[0].board.ships,
                _teleport_destination_ship
            );
            var _teleport_started = activate_selected_ability(
                "character", 0, 0
            );
            var _teleport_source_chosen = resolve_ability_target_choice(
                "ship", 0
            );
            var _teleport_finished = resolve_teleport_destination_choice(
                "ship", 1
            );
            _assert(
                _teleport_started
                && _teleport_source_chosen
                && _teleport_finished
                && !_teleport_station.ready
                && _teleport_station.phazon_tokens == 1
                && array_length(_teleport_source_ship.cargo) == 0
                && array_length(_teleport_destination_ship.cargo) == 1
                && _teleport_destination_ship.cargo[0].instance_id
                    == _teleport_metroid.instance_id,
                "Teleport Station moves cargo to a different Chozo Ship",
                "The move, exhaust cost, or Phazon drawback resolved incorrectly."
            );

            _reset();
            var _ghost_ai_source = make_card_instance(
                get_card_definition("lop.chozo_ghosts"), 0, "discard"
            );
            var _ghost_ai_target = make_card_instance(
                get_card_definition("loc.gf_marine"), 1, "board"
            );
            // Reproduce the stale metadata from the invalid batch match: the
            // Character is physically on Player 2's board, which determines
            // whether it is an opposing Character.
            _ghost_ai_target.controller = 0;
            array_push(
                game_state.players[1].board.characters,
                _ghost_ai_target
            );
            chozo_ghosts_end_turn = {
                ghosts: [{owner: 0, card: _ghost_ai_source}],
                index: 0,
                ends_final_round: false
            };
            pending_choice = {
                kind: "chozo_ghosts_target",
                player_index: 0,
                target_player_index: 1,
                tokens: 3,
                prompt: ""
            };
            var _ghost_ai_resolved = resolve_chozo_ghosts_target(
                _ghost_ai_target
            );
            _assert(
                _ghost_ai_resolved
                && _ghost_ai_target.phazon_tokens == 3
                && (is_undefined(pending_choice)
                    || pending_choice.kind != "chozo_ghosts_target"),
                "Chozo Ghosts AI resolves targets with stale controller metadata",
                "The legal opposing board target remained pending forever."
            );

            _reset();
            var _tyr_test_olympus = make_card_instance(
                get_card_definition("loc.g_f_s_olympus"), 1, "board"
            );
            var _tyr_test_source = make_card_instance(
                get_card_definition("loc.g_f_s_tyr"), 1, "board"
            );
            var _tyr_test_aurora = make_card_instance(
                get_card_definition("lop.aurora_unit_217"), 1, "attachment"
            );
            array_push(_tyr_test_olympus.attachments, _tyr_test_aurora);
            array_push(
                game_state.players[1].board.ships,
                _tyr_test_olympus
            );
            array_push(
                game_state.players[1].board.ships,
                _tyr_test_source
            );
            game_state.priority_player = 1;
            pending_choice = {
                kind: "raid",
                stage: "defenders",
                attacker_ship_id: -1,
                defender_ship_id: _tyr_test_olympus.instance_id,
                attacker_characters: [],
                defender_characters: [],
                attacker_ability_bonus: 0,
                defender_ability_bonus: 0
            };
            var _tyr_test_started = activate_selected_ability(
                "opponent_ship", 1, 0
            );
            var _tyr_test_resolved = _tyr_test_started
                && resolve_ability_target_choice("opponent_ship", 0);
            _assert(
                _tyr_test_started
                && _tyr_test_resolved
                && !_tyr_test_source.ready
                && _tyr_test_olympus.temporary_stat_bonus == 2
                && _tyr_test_source.phazon_tokens == 1,
                "G.F.S. Tyr supports a GF Phazon Ship and becomes corrupted",
                "Tyr's Security bonus, exhaustion, or Phazon interaction failed."
            );

            _reset();
            var _olympus_test_ship = make_card_instance(
                get_card_definition("loc.g_f_s_olympus"), 1, "board"
            );
            var _olympus_test_gf = make_card_instance(
                get_card_definition("loc.gf_marine"), 1, "board"
            );
            var _olympus_test_neutral = make_card_instance(
                get_card_definition("loc.private_military"), 1, "board"
            );
            array_push(
                game_state.players[1].board.characters,
                _olympus_test_gf
            );
            array_push(
                game_state.players[1].board.characters,
                _olympus_test_neutral
            );
            var _olympus_base_contribution = get_card_stat(
                _olympus_test_gf, "raid_character"
            ) + get_card_stat(_olympus_test_neutral, "raid_character");
            var _olympus_actual_contribution = raid_exhaust_characters(
                game_state.players[1],
                [
                    _olympus_test_gf.instance_id,
                    _olympus_test_neutral.instance_id
                ],
                _olympus_test_ship
            );
            _assert(
                _olympus_actual_contribution
                    == _olympus_base_contribution + 1,
                "G.F.S. Olympus adds one Strength per GF defender",
                "Olympus buffed the wrong faction or missed its GF Character."
            );

            _reset();
            var _soldier_raid_attacker = make_card_instance(
                get_card_definition("loc.light_shuttle"), 0, "board"
            );
            var _soldier_raid_defender = make_card_instance(
                get_card_definition("loc.light_shuttle"), 1, "board"
            );
            var _soldier_raid_trigger = make_card_instance(
                get_card_definition("loc.gf_soldier"), 0, "board"
            );
            var _soldier_raid_casualty = make_card_instance(
                get_card_definition("loc.private_military"), 1, "board"
            );
            array_push(
                game_state.players[0].board.ships,
                _soldier_raid_attacker
            );
            array_push(
                game_state.players[1].board.ships,
                _soldier_raid_defender
            );
            array_push(
                game_state.players[0].board.characters,
                _soldier_raid_trigger
            );
            array_push(
                game_state.players[1].board.characters,
                _soldier_raid_casualty
            );
            array_push(
                game_state.players[1].lab,
                create_metroid_for_stage(4)
            );
            array_push(
                game_state.players[1].lab,
                create_metroid_for_stage(1)
            );
            pending_choice = {
                kind: "raid",
                stage: "defenders",
                attacker_ship_id: _soldier_raid_attacker.instance_id,
                defender_ship_id: _soldier_raid_defender.instance_id,
                attacker_characters: [],
                defender_characters: [],
                attacker_ability_bonus: 0,
                defender_ability_bonus: 2
            };
            var _soldier_raid_resolved = resolve_raid();
            var _soldier_breach_waited = _soldier_raid_resolved
                && !_soldier_raid_trigger.ready
                && !is_undefined(pending_choice)
                && pending_choice.kind == "breach_character"
                && pending_choice.gf_soldier_breach;
            resolve_breach_character_choice(0);
            _assert(
                _soldier_breach_waited
                && array_length(game_state.players[1].lab) == 1
                && game_state.players[1].lab[0].definition.stage == 4
                && array_length(game_state.players[1].board.characters) == 0
                && is_undefined(gf_soldier_breach_sequence),
                "GF Soldier triggers when its controller's attacking Ship is destroyed",
                "The Soldier failed to exhaust or breach the opponent's lowest-stage Metroid."
            );

            _reset();
            var _tie_attacker = make_card_instance(
                get_card_definition("loc.light_shuttle"), 0, "board"
            );
            var _tie_defender = make_card_instance(
                get_card_definition("loc.light_shuttle"), 1, "board"
            );
            array_push(game_state.players[0].board.ships, _tie_attacker);
            array_push(game_state.players[1].board.ships, _tie_defender);
            pending_choice = {
                kind: "raid",
                stage: "defenders",
                attacker_ship_id: game_state.players[0].board.ships[0].instance_id,
                defender_ship_id: game_state.players[1].board.ships[0].instance_id,
                attacker_characters: [],
                defender_characters: [],
                attacker_ability_bonus: 0,
                defender_ability_bonus: 0
            };
            resolve_raid();
            _assert(
                array_length(game_state.players[0].board.ships) == 0
                && array_length(game_state.players[1].board.ships) == 0
                && array_length(game_state.players[0].discard) == 1
                && array_length(game_state.players[1].discard) == 1,
                "A tied raid discards both Ships",
                "One tied Ship survived or entered the wrong zone."
            );

            _reset();
            var _cargo_attacker = make_card_instance(
                get_card_definition("loc.attack_vessel"), 0, "board"
            );
            var _cargo_defender = make_card_instance(
                get_card_definition("loc.light_shuttle"), 1, "board"
            );
            var _captured_cargo = create_metroid_for_stage(2);
            array_push(_cargo_defender.cargo, _captured_cargo);
            array_push(game_state.players[0].board.ships, _cargo_attacker);
            array_push(game_state.players[1].board.ships, _cargo_defender);
            pending_choice = {
                kind: "raid",
                stage: "defenders",
                attacker_ship_id: game_state.players[0].board.ships[0].instance_id,
                defender_ship_id: game_state.players[1].board.ships[0].instance_id,
                attacker_characters: [],
                defender_characters: [],
                attacker_ability_bonus: 0,
                defender_ability_bonus: 0
            };
            resolve_raid();
            _assert(
                array_length(_cargo_attacker.cargo) == 1
                && _cargo_attacker.cargo[0].instance_id
                    == _captured_cargo.instance_id
                && array_length(game_state.players[1].board.ships) == 0,
                "A winning empty Ship takes all available cargo",
                "Single cargo was not transferred to the raid winner."
            );

            _reset();
            var _full_attacker = make_card_instance(
                get_card_definition("loc.attack_vessel"), 0, "board"
            );
            var _full_defender = make_card_instance(
                get_card_definition("loc.light_shuttle"), 1, "board"
            );
            var _kept_cargo = create_metroid_for_stage(1);
            var _overflow_cargo = create_metroid_for_stage(3);
            array_push(_full_attacker.cargo, _kept_cargo);
            array_push(_full_defender.cargo, _overflow_cargo);
            array_push(game_state.players[0].board.ships, _full_attacker);
            array_push(game_state.players[1].board.ships, _full_defender);
            pending_choice = {
                kind: "raid",
                stage: "defenders",
                attacker_ship_id: game_state.players[0].board.ships[0].instance_id,
                defender_ship_id: game_state.players[1].board.ships[0].instance_id,
                attacker_characters: [],
                defender_characters: [],
                attacker_ability_bonus: 0,
                defender_ability_bonus: 0
            };
            resolve_raid();
            _assert(
                array_length(_full_attacker.cargo) == 1
                && _full_attacker.cargo[0].instance_id == _kept_cargo.instance_id
                && _overflow_cargo.zone == "supply",
                "Raid cargo returns to supply when the winner is full",
                "The winner exceeded capacity or replaced existing cargo."
            );

            _reset();
            var _choice_attacker = make_card_instance(
                get_card_definition("loc.attack_vessel"), 0, "board"
            );
            var _choice_defender = make_card_instance(
                get_card_definition("loc.light_shuttle"), 1, "board"
            );
            var _choice_cargo_one = create_metroid_for_stage(1);
            var _choice_cargo_two = create_metroid_for_stage(4);
            array_push(_choice_defender.cargo, _choice_cargo_one);
            array_push(_choice_defender.cargo, _choice_cargo_two);
            array_push(game_state.players[0].board.ships, _choice_attacker);
            array_push(game_state.players[1].board.ships, _choice_defender);
            pending_choice = {
                kind: "raid",
                stage: "defenders",
                attacker_ship_id: game_state.players[0].board.ships[0].instance_id,
                defender_ship_id: game_state.players[1].board.ships[0].instance_id,
                attacker_characters: [],
                defender_characters: [],
                attacker_ability_bonus: 0,
                defender_ability_bonus: 0
            };
            resolve_raid();
            var _cargo_choice_prompted = !is_undefined(pending_choice)
                && pending_choice.kind == "raid_cargo";
            finish_attacker_raid_win(1);
            _assert(
                _cargo_choice_prompted
                && array_length(_choice_attacker.cargo) == 1
                && _choice_attacker.cargo[0].instance_id
                    == _choice_cargo_two.instance_id
                && _choice_cargo_one.zone == "supply",
                "Partial raid capacity prompts for the cargo taken",
                "The selected cargo or overflow destination was incorrect."
            );

            _reset();
            var _contributor_attacker = make_card_instance(
                get_card_definition("loc.light_shuttle"), 0, "board"
            );
            var _contributor_defender = make_card_instance(
                get_card_definition("loc.light_shuttle"), 1, "board"
            );
            var _raid_contributor = make_card_instance(
                get_card_definition("loc.gf_marine"), 0, "board"
            );
            array_push(
                game_state.players[0].board.ships,
                _contributor_attacker
            );
            array_push(
                game_state.players[1].board.ships,
                _contributor_defender
            );
            array_push(
                game_state.players[0].board.characters,
                _raid_contributor
            );
            pending_choice = {
                kind: "raid",
                stage: "defenders",
                attacker_ship_id: game_state.players[0].board.ships[0].instance_id,
                defender_ship_id: game_state.players[1].board.ships[0].instance_id,
                attacker_characters: [game_state.players[0].board.characters[0].instance_id],
                defender_characters: [],
                attacker_ability_bonus: 0,
                defender_ability_bonus: 0
            };
            resolve_raid();
            _assert(
                !_raid_contributor.ready
                && array_length(game_state.players[0].board.ships) == 1
                && array_length(game_state.players[1].board.ships) == 0,
                "Raid contributors exhaust and affect the final total",
                "The contributor remained ready or failed to break the tie."
            );

            _reset();
            var _shifted_noncontributor = make_card_instance(
                get_card_definition("loc.private_military"), 0, "board"
            );
            var _shifted_contributor = make_card_instance(
                get_card_definition("loc.gf_marine"), 0, "board"
            );
            array_push(
                game_state.players[0].board.characters,
                _shifted_noncontributor
            );
            array_push(
                game_state.players[0].board.characters,
                _shifted_contributor
            );
            var _shifted_contributor_id = _shifted_contributor.instance_id;
            var _shifted_expected_strength = get_card_stat(
                _shifted_contributor, "raid_character"
            );
            array_delete(game_state.players[0].board.characters, 0, 1);
            var _shifted_actual_strength = raid_exhaust_characters(
                game_state.players[0],
                [_shifted_contributor_id],
                undefined
            );
            _assert(
                _shifted_actual_strength == _shifted_expected_strength
                && !_shifted_contributor.ready,
                "Raid contributors survive board-index shifts by instance ID",
                "Removing an earlier Character changed the committed contributor."
            );

            _reset();
            var _removed_vehicle_attacker = make_card_instance(
                get_card_definition("loc.light_shuttle"), 0, "board"
            );
            var _removed_vehicle_defender = make_card_instance(
                get_card_definition("loc.light_shuttle"), 1, "board"
            );
            array_push(
                game_state.players[0].board.ships,
                _removed_vehicle_attacker
            );
            array_push(
                game_state.players[1].board.ships,
                _removed_vehicle_defender
            );
            pending_choice = {
                kind: "raid",
                stage: "defenders",
                attacker_ship_id: _removed_vehicle_attacker.instance_id,
                defender_ship_id: _removed_vehicle_defender.instance_id,
                attacker_characters: [],
                defender_characters: [],
                attacker_ability_bonus: 0,
                defender_ability_bonus: 0
            };
            array_delete(game_state.players[1].board.ships, 0, 1);
            var _removed_vehicle_raid_ended = !raid_validate_participants(
                pending_choice
            );
            _assert(
                _removed_vehicle_raid_ended && is_undefined(pending_choice),
                "Raid ends when a participating Vehicle leaves play",
                "The Raid retained a missing attacking or defending Vehicle."
            );

            _reset();
            var _timing_attacker = make_card_instance(
                get_card_definition("loc.light_shuttle"), 0, "board"
            );
            var _timing_defender = make_card_instance(
                get_card_definition("loc.light_shuttle"), 1, "board"
            );
            array_push(game_state.players[0].board.ships, _timing_attacker);
            array_push(game_state.players[1].board.ships, _timing_defender);
            var _timing_raid_cost = get_raid_cost(
                game_state.players[0],
                _timing_defender
            );
            _assert(
                _timing_raid_cost == get_card_stat(
                    _timing_defender,
                    "raid_defender_ship"
                ),
                "Raid cost uses an empty target Ship's current Security",
                "Empty-Ship raid cost did not match current Security."
            );
            game_state.players[0].command_points = _timing_raid_cost;
            begin_raid_target_choice(0);
            var _raid_waited_for_attacker = !is_undefined(pending_choice)
                && pending_choice.kind == "raid"
                && pending_choice.stage == "attacker_ship"
                && _timing_attacker.ready
                && game_state.players[0].command_points == _timing_raid_cost;
            select_raid_attacker(0);
            _assert(
                _raid_waited_for_attacker
                && !_timing_attacker.ready
                && _timing_defender.ready
                && game_state.players[0].command_points == 0,
                "Raid declares its target before choosing and exhausting its attacker",
                "Raid declaration, readiness, or target-based cost resolved incorrectly."
            );

            _reset();
            var _priced_defender = make_card_instance(
                get_card_definition("loc.light_shuttle"), 1, "board"
            );
            var _priced_alpha = make_metroid_instance(
                get_metroid_definition("metroid.alpha"), "cargo"
            );
            var _priced_gamma = make_metroid_instance(
                get_metroid_definition("metroid.gamma"), "cargo"
            );
            array_push(_priced_defender.cargo, _priced_alpha);
            array_push(_priced_defender.cargo, _priced_gamma);
            _assert(
                get_raid_cost(game_state.players[0], _priced_defender)
                    == _priced_gamma.definition.hazard,
                "Raid cost uses the highest carried Metroid Hazard",
                "Raid cost did not use the highest Hazard among multiple cargo."
            );

            _reset();
            var _corrupt_raid_ship = make_card_instance(
                get_card_definition("loc.light_shuttle"), 0, "board"
            );
            var _corrupt_raid_defender = make_card_instance(
                get_card_definition("loc.light_shuttle"), 1, "board"
            );
            var _corrupt_contributor = make_card_instance(
                get_card_definition("loc.gf_marine"), 0, "board"
            );
            _corrupt_contributor.phazon_tokens = 3;
            array_push(game_state.players[0].board.ships, _corrupt_raid_ship);
            array_push(
                game_state.players[1].board.ships,
                _corrupt_raid_defender
            );
            array_push(
                game_state.players[0].board.characters,
                _corrupt_contributor
            );
            pending_choice = {
                kind: "raid",
                stage: "defenders",
                attacker_ship_id: game_state.players[0].board.ships[0].instance_id,
                defender_ship_id: game_state.players[1].board.ships[0].instance_id,
                attacker_characters: [game_state.players[0].board.characters[0].instance_id],
                defender_characters: [],
                attacker_ability_bonus: 0,
                defender_ability_bonus: 0
            };
            resolve_raid();
            _assert(
                array_length(game_state.players[0].board.characters) == 0
                && array_length(game_state.players[0].discard) == 1
                && game_state.players[0].discard[0].phazon_tokens == 0,
                "Corrupted raid contributors discard after exhausting",
                "The contributor survived or retained its Phazon tokens."
            );

            _reset();
            var _ability_raid_attacker = make_card_instance(
                get_card_definition("loc.light_shuttle"), 0, "board"
            );
            var _ability_raid_defender = make_card_instance(
                get_card_definition("loc.light_shuttle"), 1, "board"
            );
            var _ability_raid_source = make_card_instance(
                get_card_definition("loc.samus_aran"), 1, "board"
            );
            array_push(
                game_state.players[0].board.ships,
                _ability_raid_attacker
            );
            array_push(
                game_state.players[1].board.ships,
                _ability_raid_defender
            );
            array_push(
                game_state.players[1].board.characters,
                _ability_raid_source
            );
            pending_choice = {
                kind: "raid",
                stage: "defenders",
                attacker_ship_id: game_state.players[0].board.ships[0].instance_id,
                defender_ship_id: game_state.players[1].board.ships[0].instance_id,
                attacker_characters: [],
                defender_characters: [],
                attacker_ability_bonus: 0,
                defender_ability_bonus: 0
            };
            resolve_activated_ability(
                _ability_raid_source,
                {
                    effect_kind: "raid_defense_1",
                    cost_cp: 1,
                    cost_exhaust: false,
                    cost_destroy: false
                },
                "",
                -1
            );
            var _defense_bonus_applied =
                pending_choice.defender_ability_bonus == 1;
            resolve_raid();
            _assert(
                _defense_bonus_applied
                && array_length(game_state.players[0].board.ships) == 0
                && array_length(game_state.players[1].board.ships) == 1,
                "Raid abilities modify totals before resolution locks",
                "The defensive bonus failed to turn a tie into a defense."
            );

            _reset();
            var _destroyer = make_card_instance(
                get_card_definition("loc.pirate_destroyer"), 0, "board"
            );
            var _destroyer_target = make_card_instance(
                get_card_definition("loc.light_shuttle"), 1, "board"
            );
            _destroyer.ready = false;
            array_push(game_state.players[0].board.ships, _destroyer);
            array_push(game_state.players[1].board.ships, _destroyer_target);
            pending_choice = {
                kind: "raid",
                stage: "defenders",
                attacker_ship_id: game_state.players[0].board.ships[0].instance_id,
                defender_ship_id: game_state.players[1].board.ships[0].instance_id,
                attacker_characters: [],
                defender_characters: [],
                attacker_ability_bonus: 10,
                defender_ability_bonus: 0
            };
            resolve_raid();
            _assert(
                _destroyer.ready
                && array_length(game_state.players[1].board.ships) == 0,
                "Pirate Destroyer readies after a successful raid",
                "The winning Destroyer remained exhausted."
            );

            _reset();
            for (var _special_player_index = 0;
                 _special_player_index < 2;
                 _special_player_index++) {
                array_push(
                    game_state.players[_special_player_index].lab,
                    create_metroid_for_stage(1)
                );
                for (var _special_strength_index = 0;
                     _special_strength_index < 4;
                     _special_strength_index++) {
                    array_push(
                        game_state.players[
                            _special_player_index
                        ].board.characters,
                        make_card_instance(
                            get_card_definition("loc.gf_marine"),
                            _special_player_index,
                            "board"
                        )
                    );
                }
            }
            var _queen_auto_card = make_card_instance(
                get_card_definition("loc.queen_metroid_awakens"),
                -1,
                "shop"
            );
            for (var _queen_auto_row_setup = 0;
                 _queen_auto_row_setup < 4;
                 _queen_auto_row_setup++) {
                var _queen_auto_row_card = make_card_instance(
                    get_card_definition("loc.gf_soldier"),
                    -1,
                    "shop"
                );
                _queen_auto_row_card.ui_shop_slot = _queen_auto_row_setup;
                array_push(game_state.shop_row, _queen_auto_row_card);
            }
            _queen_auto_card.ui_shop_slot = 4;
            array_push(game_state.shop_row, _queen_auto_card);
            for (var _queen_return_deck_index = 0;
                 _queen_return_deck_index < 4;
                 _queen_return_deck_index++) {
                array_push(
                    game_state.shop_deck,
                    make_card_instance(
                        get_card_definition("loc.gf_marine"),
                        -1,
                        "shop_deck"
                    )
                );
            }
            begin_special_containment(
                [
                    {
                        player_index: 0,
                        bonus_hazard: 2,
                        forced_breach: false
                    },
                    {
                        player_index: 1,
                        bonus_hazard: 2,
                        forced_breach: false
                    }
                ],
                "queen",
                0
            );
            choose_special_containment_ship(-1);
            var _queen_reached_second = !is_undefined(pending_choice)
                && pending_choice.kind == "special_containment_ship"
                && pending_choice.player_index == 1;
            choose_special_containment_ship(-1);
            var _queen_auto_in_deck = false;
            for (var _queen_auto_deck_index = 0;
                 _queen_auto_deck_index < array_length(game_state.shop_deck);
                 _queen_auto_deck_index++) {
                if (game_state.shop_deck[_queen_auto_deck_index].instance_id
                    == _queen_auto_card.instance_id) {
                    _queen_auto_in_deck = true;
                }
            }
            _assert(
                _queen_reached_second
                && is_undefined(special_containment_sequence)
                && array_length(game_state.shop_row) == 5
                && _queen_auto_in_deck
                && is_undefined(pending_choice),
                "Queen containment completes across both players",
                "The second player or automatic Queen return was skipped."
            );

            _reset();
            for (var _sax_player_index = 0;
                 _sax_player_index < 2;
                 _sax_player_index++) {
                array_push(
                    game_state.players[_sax_player_index].lab,
                    create_metroid_for_stage(1)
                );
                array_push(
                    game_state.players[_sax_player_index].board.characters,
                    make_card_instance(
                        get_card_definition("loc.gf_marine"),
                        _sax_player_index,
                        "board"
                    )
                );
            }
            begin_special_containment(
                [
                    {
                        player_index: 0,
                        bonus_hazard: 0,
                        forced_breach: true
                    },
                    {
                        player_index: 1,
                        bonus_hazard: 0,
                        forced_breach: true
                    }
                ],
                "sa_x",
                -1
            );
            choose_special_containment_ship(-1);
            var _sax_first_breach = !is_undefined(pending_choice)
                && pending_choice.kind == "breach_character"
                && pending_choice.player_index == 0;
            resolve_breach_character_choice(0);
            var _sax_reached_second = !is_undefined(pending_choice)
                && pending_choice.kind == "special_containment_ship"
                && pending_choice.player_index == 1;
            choose_special_containment_ship(-1);
            var _sax_second_breach = !is_undefined(pending_choice)
                && pending_choice.kind == "breach_character"
                && pending_choice.player_index == 1;
            resolve_breach_character_choice(0);
            _assert(
                _sax_first_breach
                && _sax_reached_second
                && _sax_second_breach
                && is_undefined(special_containment_sequence)
                && is_undefined(pending_choice),
                "SA-X forced containment completes across both players",
                "A forced breach or player transition failed to resolve."
            );

            var _starter_test_cases = [
                ["", "loc.armoured_frigate", "starter.military_rations", 0],
                ["GF", "loc.gf_marine", "starter.private_military", 2],
                ["SP", "loc.zebesian_pirate", "starter.sloop", 1],
                ["CZ", "loc.quiet_robe", "starter.full_deck", 0, 1],
                ["CZ", "loc.raven_beak", "starter.full_deck", 0, 0],
                ["BH", "loc.ghor", "starter.budget_cuts", 0],
                ["PZ", "lop.hive_mind_communication", "starter.orders_received", 1]
            ];
            faction_starters_enabled = true;
            for (var _starter_case_index = 0;
                 _starter_case_index < array_length(_starter_test_cases);
                 _starter_case_index++) {
                _reset();
                var _starter_case = _starter_test_cases[_starter_case_index];
                var _starter_player = game_state.players[0];
                _starter_player.is_ai = true;
                _starter_player.favored_faction = _starter_case[0];
                _starter_player.deck = expand_card_pool(
                    card_database.pools.starter,
                    0,
                    "deck"
                );
                draw_from_deck(_starter_player, 5);
                apply_identity_starter(
                    _starter_player,
                    false,
                    _starter_case[1]
                );
                var _starter_total = array_length(_starter_player.deck)
                    + array_length(_starter_player.hand);
                var _starter_found = 0;
                var _replacement_found = 0;
                var _starter_zones = [
                    _starter_player.deck,
                    _starter_player.hand
                ];
                for (var _starter_zone_index = 0;
                     _starter_zone_index < array_length(_starter_zones);
                     _starter_zone_index++) {
                    for (var _starter_card_index = 0;
                         _starter_card_index
                            < array_length(_starter_zones[_starter_zone_index]);
                         _starter_card_index++) {
                        var _starter_test_card =
                            _starter_zones[_starter_zone_index][
                                _starter_card_index
                            ];
                        _starter_found += _starter_test_card.definition_id
                            == _starter_case[1] ? 1 : 0;
                        _replacement_found += _starter_test_card.definition_id
                            == _starter_case[2] ? 1 : 0;
                    }
                }
                _assert(
                    _starter_total == 10
                    && _starter_found == (
                        array_length(_starter_case) >= 5
                            ? _starter_case[4]
                            : 1
                    )
                    && _replacement_found == _starter_case[3]
                    && _starter_player.identity_starter_id == _starter_case[1],
                    "Identity starter replacement "
                        + batch_profile_label(_starter_case[0])
                        + " " + _starter_case[1],
                    "Deck size, inserted card, or replaced-card count was wrong."
                );
            }

            _reset();
            var _sp_starter_config = get_identity_starter_config(
                "SP", "loc.zebesian_pirate"
            );
            _assert(
                raid_array_contains(
                    _sp_starter_config.deck_ids, "loc.frigate_orpheon"
                )
                && !raid_array_contains(
                    _sp_starter_config.deck_ids, "loc.attack_vessel"
                ),
                "SP starter uses Frigate Orpheon instead of Attack Vessel",
                "The experimental starter substitution was not preserved."
            );

            var _gf_flagship_config = get_identity_starter_config(
                "GF", "loc.gf_marine"
            );
            var _gf_tyr_count = 0;
            var _gf_olympus_count = 0;
            for (var _gf_flagship_index = 0;
                 _gf_flagship_index
                    < array_length(_gf_flagship_config.deck_ids);
                 _gf_flagship_index++) {
                var _gf_flagship_id =
                    _gf_flagship_config.deck_ids[_gf_flagship_index];
                if (_gf_flagship_id == "loc.g_f_s_tyr") {
                    _gf_tyr_count += 1;
                } else if (_gf_flagship_id == "loc.g_f_s_olympus") {
                    _gf_olympus_count += 1;
                }
            }
            _assert(
                _gf_tyr_count == 1 && _gf_olympus_count == 1,
                "GF starter pairs one Tyr with one G.F.S. Olympus",
                "The starter does not contain exactly one support Ship and one flagship."
            );
            var _na_starter_config = get_identity_starter_config(
                "", "loc.armoured_frigate"
            );
            var _na_private_military_count = 0;
            for (var _na_starter_index = 0;
                 _na_starter_index
                    < array_length(_na_starter_config.deck_ids);
                 _na_starter_index++) {
                if (_na_starter_config.deck_ids[_na_starter_index]
                == "starter.private_military") {
                    _na_private_military_count += 1;
                }
            }
            _assert(
                array_length(_na_starter_config.deck_ids) == 10
                && raid_array_contains(
                    _na_starter_config.deck_ids, "loc.delano_7"
                )
                && raid_array_contains(
                    _na_starter_config.deck_ids,
                    "lop.hive_mind_communication"
                )
                && raid_array_contains(
                    _na_starter_config.deck_ids, "lop.dark_samus"
                )
                && raid_array_contains(
                    _na_starter_config.deck_ids, "loc.gandrayda"
                )
                && raid_array_contains(
                    _na_starter_config.deck_ids, "loc.security_guard"
                )
                && _na_private_military_count == 2
                && !raid_array_contains(
                    _na_starter_config.deck_ids, "starter.orders_received"
                )
                && !raid_array_contains(
                    _na_starter_config.deck_ids, "starter.budget_cuts"
                )
                && !raid_array_contains(
                    _na_starter_config.deck_ids, "loc.b_s_l_ship"
                )
                && !raid_array_contains(
                    _na_starter_config.deck_ids, "starter.ship_captain"
                )
                && !raid_array_contains(
                    _na_starter_config.deck_ids, "starter.sloop"
                ),
                "NA starter links Dark Samus to its Phazon package",
                "The neutral starter substitutions were not preserved."
            );
            _assert(
                batch_profile_faction("CZT") == "CZ"
                && batch_profile_faction("CZM") == "CZ"
                && batch_identity_starter_id("CZT", 388, "A")
                    == "loc.quiet_robe"
                && batch_identity_starter_id("CZM", 388, "A")
                    == "loc.raven_beak",
                "Batch separates Thoha and Mawkin starter profiles",
                "CZT/CZM did not retain CZ drafting with fixed starter identities."
            );

            _reset();
            var _zebesian = make_card_instance(
                get_card_definition("loc.zebesian_pirate"), 0, "board"
            );
            var _beam_pirate = make_card_instance(
                get_card_definition("loc.beam_pirate"), 0, "board"
            );
            var _attack_vessel = make_card_instance(
                get_card_definition("loc.attack_vessel"), 0, "board"
            );
            var _pirate_homeworld = make_card_instance(
                get_card_definition("loc.space_pirate_homeworld"), 0, "board"
            );
            array_push(game_state.players[0].board.characters, _zebesian);
            array_push(game_state.players[0].board.characters, _beam_pirate);
            array_push(game_state.players[0].board.ships, _attack_vessel);
            array_push(game_state.players[0].board.locations, _pirate_homeworld);
            _assert(
                get_card_stat(_zebesian) == 4,
                "Zebesian Pirate scales with all ready Space Pirate cards",
                "A ready Space Pirate Character, Ship, or Location was omitted."
            );

            _reset();
            var _pressure_attacker = make_card_instance(
                get_card_definition("starter.sloop"), 0, "board"
            );
            var _pressure_defender = make_card_instance(
                get_card_definition("loc.light_shuttle"), 1, "board"
            );
            var _pressure_character = make_card_instance(
                get_card_definition("starter.private_military"), 1, "board"
            );
            array_push(game_state.players[0].board.ships, _pressure_attacker);
            array_push(game_state.players[1].board.ships, _pressure_defender);
            array_push(
                game_state.players[1].board.characters,
                _pressure_character
            );
            array_push(
                game_state.players[1].lab,
                create_metroid_for_stage(5)
            );
            game_state.players[0].command_points = 2;
            var _pressure_score = ai_raid_exhaustion_score(0, 0);
            game_state.players[1].lab = [];
            var _empty_lab_pressure_score = ai_raid_exhaustion_score(0, 0);
            _assert(
                _pressure_score > 0 && _empty_lab_pressure_score <= -100000,
                "AI values losing raids that create containment pressure",
                "The tactical raid was rejected with a threatened Lab or accepted with an empty Lab."
            );

            var _planner_candidates = [
                {
                    kind: "test", index: 0, secondary: -1,
                    source_kind: "", ability_index: -1,
                    cost: 2, value: 1.10, groups: ["greedy"],
                    is_event: false, name: "GREEDY"
                },
                {
                    kind: "test", index: 1, secondary: -1,
                    source_kind: "", ability_index: -1,
                    cost: 1, value: 0.70, groups: ["setup"],
                    is_event: false, name: "SETUP"
                },
                {
                    kind: "test", index: 2, secondary: -1,
                    source_kind: "", ability_index: -1,
                    cost: 1, value: 0.70, groups: ["followup"],
                    is_event: false, name: "FOLLOWUP"
                }
            ];
            var _planner_combo = ai_plan_turn(_planner_candidates, 2);
            _assert(
                _planner_combo.first != 0
                    && _planner_combo.value >= 1.39,
                "AI planner prefers a stronger affordable action sequence",
                "The planner chose the locally best action instead of the better two-action line."
            );
            var _future_candidate = [{
                kind: "test", index: 0, secondary: -1,
                source_kind: "", ability_index: -1,
                cost: 4, value: 1.00, groups: ["future"],
                is_event: false, earliest_phase: 1,
                name: "NEXT TURN TEST"
            }];
            var _planner_bank = ai_plan_turn(_future_candidate, 0);
            _assert(
                _planner_bank.first < 0 && _planner_bank.value >= 0.69,
                "AI planner banks CP for a valuable next-turn action",
                "A future-only action was either executed early or ignored."
            );
            game_state.players[0].command_points = 4;
            game_state.players[0].ai_hand_refresh_turn =
                game_state.turn_number;
            game_state.players[0].ai_shop_refresh_turn =
                game_state.turn_number;
            _assert(
                ai_plan_hand_refresh(game_state.players[0]).score <= -100000
                    && ai_score_shop_refresh(
                        game_state.players[0], 0
                    ) <= -100000,
                "AI refresh actions are limited to once per turn",
                "Replanning offered a second hand or Shop refresh in the same turn."
            );

            _reset();
            var _removal_character = make_card_instance(
                get_card_definition("starter.private_military"), 1, "board"
            );
            array_push(
                game_state.players[1].board.characters,
                _removal_character
            );
            game_state.players[1].deck = [];
            _assert(
                ai_board_card_removal_value(
                    _removal_character, game_state.players[1]
                ) > 0.02,
                "An empty deck does not erase permanent removal value",
                "A deployed Character was treated as worthless because its owner could shuffle the discard."
            );

            _reset();
            var _empty_removal_ship = make_card_instance(
                get_card_definition("starter.sloop"), 1, "board"
            );
            var _loaded_removal_ship = make_card_instance(
                get_card_definition("starter.sloop"), 1, "board"
            );
            array_push(
                _loaded_removal_ship.cargo,
                // The other Sloop can safely contribute its 1 Security after
                // this Larva reaches the Lab, so its expected scoring value is
                // deliberately positive. An Alpha here would correctly be
                // valued at zero with no Character Strength in the fixture.
                create_metroid_for_stage(1)
            );
            array_push(
                game_state.players[1].board.ships,
                _empty_removal_ship,
                _loaded_removal_ship
            );
            var _empty_ship_removal = ai_board_card_removal_value(
                _empty_removal_ship, game_state.players[1]
            );
            var _loaded_ship_removal = ai_board_card_removal_value(
                _loaded_removal_ship, game_state.players[1]
            );
            _assert(
                _loaded_ship_removal > _empty_ship_removal,
                "Removal values Metroid cargo lost with a Ship",
                "A loaded Ship was not a more valuable removal target than an identical empty Ship."
            );
            _loaded_removal_ship.cargo[0] = create_metroid_for_stage(2);
            var _possessed_cargo_loss = ai_containment_loss_at(
                game_state.players[1], 0, 1
            );
            var _without_possessed_cargo_loss = ai_containment_loss_at(
                game_state.players[1],
                0,
                1,
                undefined,
                _loaded_removal_ship.cargo[0].instance_id
            );
            _assert(
                _possessed_cargo_loss > _without_possessed_cargo_loss,
                "AI containment forecasts include Metroids aboard Ships",
                "Ship cargo was omitted until it physically entered the Lab."
            );

            var _shared_target_candidates = [
                {
                    kind: "test", index: 0, secondary: -1,
                    source_kind: "", ability_index: -1,
                    cost: 0, value: 1, groups: ["target_99", "source_1"],
                    is_event: false, name: "REMOVE A"
                },
                {
                    kind: "test", index: 1, secondary: -1,
                    source_kind: "", ability_index: -1,
                    cost: 0, value: 1, groups: ["target_99", "source_2"],
                    is_event: false, name: "REMOVE B"
                }
            ];
            var _shared_target_plan = ai_plan_turn(
                _shared_target_candidates, 0
            );
            _assert(
                _shared_target_plan.value < 1.01,
                "AI planner cannot remove the same projected target twice",
                "Two removal abilities both claimed value from one target."
            );

            _reset();
            game_state.priority_player = 1;
            pending_choice = {
                kind: "space_pirate_payment",
                owner_index: 0,
                payer_index: 1
            };
            _assert(
                network_expected_player() == 1,
                "Network choices follow transferred priority",
                "A source-card owner field overrode the opponent who must respond."
            );

            _reset();
            var _empty_researcher = make_card_instance(
                get_card_definition("starter.researcher"),
                0,
                "board"
            );
            array_push(
                game_state.players[0].board.characters,
                _empty_researcher
            );
            game_state.players[0].deck = [];
            game_state.players[0].discard = [];
            game_state.players[0].hand = [];
            resolve_start_turn_researchers(game_state.players[0]);
            _assert(
                is_undefined(pending_choice),
                "Researcher requires only successful draws to be discarded",
                "An empty deck created an impossible Researcher discard choice."
            );

            _reset();
            for (var _mercy_metroid_index = 0;
                 _mercy_metroid_index < 10;
                 _mercy_metroid_index++) {
                array_push(
                    game_state.players[0].lab,
                    create_metroid_for_stage(1)
                );
            }

            var _mercy_started = check_alternate_end_conditions();
            var _mercy_waited = _mercy_started
                && game_state.final_round_active
                && game_state.final_round_end_player == 1
                && game_state.phase != "game_over";
            game_state.active_player = 1;
            game_state.priority_player = 1;
            game_state.phase = "action";
            end_turn_action();
            _assert(
                _mercy_waited && game_state.phase == "game_over",
                "Ten-Metroid mercy rule finishes the round",
                "The threshold ended immediately or failed to score after the final turn."
            );

            _reset();
            game_state.turn_number = 50;
            _assert(
                check_alternate_end_conditions()
                && game_state.final_round_active
                && game_state.final_round_end_player == 1,
                "Turn 50 starts a final round",
                "The turn limit did not arm the opponent's final turn."
            );

            _reset();
            faction_starters_enabled = false;
            var _disabled_starter_player = game_state.players[0];
            _disabled_starter_player.is_ai = true;
            _disabled_starter_player.favored_faction = "GF";
            _disabled_starter_player.deck = expand_card_pool(
                card_database.pools.starter,
                0,
                "deck"
            );
            draw_from_deck(_disabled_starter_player, 5);
            var _disabled_result = apply_identity_starter(
                _disabled_starter_player,
                false,
                "loc.gf_marine"
            );
            _assert(
                !_disabled_result
                && _disabled_starter_player.identity_starter_id == ""
                && array_length(_disabled_starter_player.deck)
                    + array_length(_disabled_starter_player.hand) == 10,
                "Faction starter toggle disables replacements",
                "A disabled faction starter changed the neutral deck."
            );

            _reset();
            var _gf_ai_player = game_state.players[0];
            _gf_ai_player.is_ai = true;
            _gf_ai_player.ai_brain = "commander";
            var _gf_economy_candidate = make_card_instance(
                get_card_definition("loc.gf_marine"), 0, "hand"
            );
            var _gf_economy_profile = ai_effect_profile(
                _gf_economy_candidate
            );
            var _gf_stable_economy_value = ai_gf_card_priority(
                _gf_economy_candidate,
                _gf_ai_player,
                _gf_economy_profile
            );
            array_push(
                _gf_ai_player.lab,
                make_metroid_instance(
                    get_metroid_definition("metroid.omega"), "lab"
                )
            );
            var _gf_unstable_economy_value = ai_gf_card_priority(
                _gf_economy_candidate,
                _gf_ai_player,
                _gf_economy_profile
            );
            _assert(
                _gf_stable_economy_value > _gf_unstable_economy_value,
                "GF develops economy after stabilizing",
                "An exposed GF board valued economy as highly as a stable board."
            );

            _reset();
            _gf_ai_player = game_state.players[0];
            _gf_ai_player.is_ai = true;
            _gf_ai_player.ai_brain = "commander";
            _gf_economy_candidate = make_card_instance(
                get_card_definition("loc.gf_marine"), 0, "hand"
            );
            _gf_economy_profile = ai_effect_profile(_gf_economy_candidate);
            var _gf_first_economy_value = ai_gf_card_priority(
                _gf_economy_candidate,
                _gf_ai_player,
                _gf_economy_profile
            );
            var _gf_existing_marine = make_card_instance(
                get_card_definition("loc.gf_marine"), 0, "board"
            );
            array_push(
                _gf_ai_player.board.characters,
                _gf_existing_marine
            );
            var _gf_redundant_economy_value = ai_gf_card_priority(
                _gf_economy_candidate,
                _gf_ai_player,
                _gf_economy_profile
            );
            _assert(
                _gf_first_economy_value > _gf_redundant_economy_value,
                "GF values missing engine roles above redundancy",
                "A redundant economy piece received the same role bonus as the first."
            );

            var _gf_salvage_priority = ai_gf_action_priority({
                kind: "salvage",
                index: 0,
                secondary: -1,
                source_kind: "character"
            }, _gf_ai_player);
            _assert(
                ai_gf_card_is_critical(_gf_existing_marine, _gf_ai_player)
                && _gf_salvage_priority <= -0.7,
                "GF protects its sole engine pieces",
                "Salvaging the only economy provider was not strongly discouraged."
            );

            _reset();
            var _sp_ai_player = game_state.players[0];
            var _sp_enemy = game_state.players[1];
            _sp_ai_player.is_ai = true;
            _sp_ai_player.ai_brain = "pirate";
            var _sp_attack_ship = make_card_instance(
                get_card_definition("loc.attack_vessel"), 0, "board"
            );
            var _sp_defense_ship = make_card_instance(
                get_card_definition("loc.armoured_frigate"), 1, "board"
            );
            array_push(_sp_ai_player.board.ships, _sp_attack_ship);
            array_push(_sp_enemy.board.ships, _sp_defense_ship);
            var _sp_frontier_before = ai_sp_raid_frontier(
                _sp_ai_player, 0, -1, 0
            );
            var _sp_non_faction_candidate = make_card_instance(
                get_card_definition("loc.samus_aran"), 0, "hand"
            );
            var _sp_non_faction_value = ai_sp_card_priority(
                _sp_non_faction_candidate,
                _sp_ai_player,
                ai_effect_profile(_sp_non_faction_candidate)
            );
            var _sp_frontier_after = ai_sp_raid_frontier(
                _sp_ai_player,
                get_card_stat(
                    _sp_non_faction_candidate,
                    "raid_attacker_character"
                ),
                -1,
                0
            );
            _assert(
                !card_has_faction(_sp_non_faction_candidate, "SP")
                && _sp_frontier_after > _sp_frontier_before
                && _sp_non_faction_value > 0,
                "SP values non-faction cards that open Raid targets",
                "A non-SP Strength contributor did not improve the Pirate frontier."
            );

            var _sp_margin_before_cargo = ai_sp_research_margin(
                _sp_ai_player
            );
            array_push(
                _sp_attack_ship.cargo,
                make_metroid_instance(
                    get_metroid_definition("metroid.larva"), "ship"
                )
            );
            var _sp_margin_after_cargo = ai_sp_research_margin(
                _sp_ai_player
            );
            _assert(
                _sp_margin_after_cargo > _sp_margin_before_cargo,
                "SP Research margin includes likely cargo intake",
                "Adding cargo did not improve the projected Lab race."
            );

            _sp_attack_ship.cargo = [];
            var _sp_weak_contributor = make_card_instance(
                get_card_definition("starter.private_military"), 0, "board"
            );
            var _sp_strong_contributor = make_card_instance(
                get_card_definition("loc.samus_aran"), 0, "board"
            );
            array_push(
                _sp_ai_player.board.characters,
                _sp_weak_contributor
            );
            array_push(
                _sp_ai_player.board.characters,
                _sp_strong_contributor
            );
            var _sp_commitment = ai_sp_raid_commitment(
                _sp_ai_player,
                _sp_attack_ship,
                get_card_stat(_sp_attack_ship, "raid_attacker_ship")
                    + get_card_stat(
                        _sp_strong_contributor,
                        "raid_attacker_character"
                    ) - 1
            );
            _assert(
                _sp_commitment.character_count == 1
                && _sp_commitment.strength == get_card_stat(
                    _sp_strong_contributor,
                    "raid_attacker_character"
                ),
                "SP projects strongest-first Raid commitment",
                "The projected Raid exhausted more or weaker Characters first."
            );

            _assert(
                batch_profile_brain("GF") == "commander"
                && batch_profile_brain("SP") == "pirate"
                && batch_profile_brain("CZT") == "elder"
                && batch_profile_brain("CZM") == "warrior"
                && batch_profile_brain("") == "neutral",
                "Batch profiles map to the named deck brains",
                "A batch profile selected the wrong personalized evaluator."
            );
        } catch (_regression_error) {
            _assert_context.failed += 1;
            array_push(
                _assert_context.lines,
                "ERROR: Regression suite aborted - "
                + string(_regression_error)
            );
        }
        game_state = _saved_game_state;
        pending_choice = _saved_pending_choice;
        containment_resolution = _saved_containment;
        special_containment_sequence = _saved_special;
        chozo_ghosts_end_turn = _saved_chozo_ghosts_end_turn;
        gf_soldier_breach_sequence = _saved_gf_soldier_breach_sequence;
        next_card_instance_id = _saved_next_card_id;
        next_metroid_instance_id = _saved_next_metroid_id;
        faction_starters_enabled = _saved_faction_starters_enabled;
        settings_experimental_breaching_mutation = _saved_breaching_mutation;
        settings_experimental_loaded_ships_exhausted =
            _saved_loaded_ships_exhausted;
        var _stamp = batch_make_timestamp();
        var _path = working_directory
            + "loc_regression_" + _stamp + ".txt";
        var _file = file_text_open_write(_path);
        if (_file >= 0) {
            file_text_write_string(
                _file,
                "LEGACY OF THE CHOZO - REGRESSION TESTS\n"
                + "Passed: " + string(_assert_context.passed)
                + " | Failed: " + string(_assert_context.failed) + "\n\n"
            );
            for (var _line_index = 0;
                 _line_index < array_length(_assert_context.lines);
                 _line_index++) {
                file_text_write_string(
                    _file,
                    _assert_context.lines[_line_index] + "\n"
                );
            }
            file_text_close(_file);
        }
        global.loc_regression_last = {
            passed: _assert_context.passed,
            failed: _assert_context.failed,
            path: _path
        };
        global.loc_regression_progress = undefined;
        show_debug_message(
            "[REGRESSION] " + string(_assert_context.passed) + " passed, "
            + string(_assert_context.failed) + " failed. "
            + get_export_display_path(_path)
        );
        return _assert_context.failed == 0;
    };

}

