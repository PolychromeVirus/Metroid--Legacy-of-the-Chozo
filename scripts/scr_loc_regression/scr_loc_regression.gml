function loc_regression() {
    run_regression_suite = function() {
        var _saved_game_state = game_state;
        var _saved_pending_choice = pending_choice;
        var _saved_containment = containment_resolution;
        var _saved_special = special_containment_sequence;
        var _saved_next_card_id = next_card_instance_id;
        var _saved_next_metroid_id = next_metroid_instance_id;
        var _saved_faction_starters_enabled = faction_starters_enabled;
        var _assert_context = {passed: 0, failed: 0, lines: []};
        var _assert = method(_assert_context, function(
            _condition,
            _name,
            _detail
        ) {
            if (_condition) {
                passed += 1;
                array_push(lines, "PASS: " + _name);
            } else {
                failed += 1;
                array_push(
                    lines,
                    "FAIL: " + _name + " - " + _detail
                );
            }
        });
        var _reset = function() {
            pending_choice = undefined;
            containment_resolution = undefined;
            special_containment_sequence = undefined;
            game_state = {
                seed: 388,
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
                abs((_gf_own_value - _gf_neutral_value) - 0.3) < 0.001
                && abs((_gf_for_sp_value - _gf_neutral_value) + 0.25)
                    < 0.001
                && abs(_bh_for_gf_value - _bh_neutral_value) < 0.001,
                "Main-faction AI profiles use light exclusionary preferences",
                "Own, rival, or secondary-faction utility received the wrong bias."
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
                "loc.quiet_robe"
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
                && !is_undefined(pending_choice)
                && pending_choice.kind == "queen_event"
                && pending_choice.stage == "revealed"
                && pending_choice.shop_index == 0,
                "Queen waits for every Shop slot to refill before activating",
                "Queen interrupted refill before the Shop row reached five cards."
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
                 _queen_row_index < 4;
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
                shop_index: 4,
                prompt: ""
            };
            random_set_seed(388);
            finish_queen_shop_event();
            var _queen_returned_to_deck = false;
            var _queen_immediately_redrawn = false;
            for (var _queen_deck_index = 0;
                 _queen_deck_index < array_length(game_state.shop_deck);
                 _queen_deck_index++) {
                if (game_state.shop_deck[_queen_deck_index].instance_id
                    == _queen_card.instance_id) {
                    _queen_returned_to_deck = true;
                    break;
                }
            }
            for (var _queen_redraw_index = 0;
                 _queen_redraw_index < array_length(game_state.shop_row);
                 _queen_redraw_index++) {
                if (game_state.shop_row[_queen_redraw_index].instance_id
                    == _queen_card.instance_id) {
                    _queen_immediately_redrawn = true;
                    break;
                }
            }
            _assert(
                array_length(game_state.shop_row) == 5
                && array_length(game_state.shop_deck) == 3
                && array_length(game_state.shop_discard) == 0
                && (_queen_returned_to_deck || _queen_immediately_redrawn)
                && (!_queen_immediately_redrawn
                    || (!is_undefined(pending_choice)
                        && pending_choice.kind == "queen_event"
                        && pending_choice.stage == "revealed")),
                "Queen recycles an exhausted Shop deck before replacement",
                "Queen was neither returned to the deck nor legally redrawn."
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
            resolve_adam_breach_choice(false);
            var _adam_breach_prompted = !is_undefined(pending_choice)
                && pending_choice.kind == "breach_character";
            resolve_breach_character_choice(1);
            _assert(
                _adam_prompted
                && _adam_breach_prompted
                && is_undefined(special_containment_sequence),
                "Declining Adam advances special containment into the breach",
                "Adam's optional prompt recreated or stalled the sequence."
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
                attacker_ship_index: 0,
                defender_ship_index: 0,
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
                attacker_ship_index: 0,
                defender_ship_index: 0,
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
                attacker_ship_index: 0,
                defender_ship_index: 0,
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
                attacker_ship_index: 0,
                defender_ship_index: 0,
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
                attacker_ship_index: 0,
                defender_ship_index: 0,
                attacker_characters: [0],
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
            var _timing_attacker = make_card_instance(
                get_card_definition("loc.light_shuttle"), 0, "board"
            );
            var _timing_defender = make_card_instance(
                get_card_definition("loc.light_shuttle"), 1, "board"
            );
            array_push(game_state.players[0].board.ships, _timing_attacker);
            array_push(game_state.players[1].board.ships, _timing_defender);
            game_state.players[0].command_points = 2;
            begin_raid_choice(0);
            select_raid_target(0);
            _assert(
                !_timing_attacker.ready
                && _timing_defender.ready
                && game_state.players[0].command_points == 0,
                "Raid initiation exhausts only the attacking Ship",
                "Readiness or the 2 CP raid cost resolved incorrectly."
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
                attacker_ship_index: 0,
                defender_ship_index: 0,
                attacker_characters: [0],
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
                attacker_ship_index: 0,
                defender_ship_index: 0,
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
                attacker_ship_index: 0,
                defender_ship_index: 0,
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
            var _queen_auto_in_row = false;
            for (var _queen_auto_deck_index = 0;
                 _queen_auto_deck_index < array_length(game_state.shop_deck);
                 _queen_auto_deck_index++) {
                if (game_state.shop_deck[_queen_auto_deck_index].instance_id
                    == _queen_auto_card.instance_id) {
                    _queen_auto_in_deck = true;
                }
            }
            for (var _queen_auto_row_index = 0;
                 _queen_auto_row_index < array_length(game_state.shop_row);
                 _queen_auto_row_index++) {
                if (game_state.shop_row[_queen_auto_row_index].instance_id
                    == _queen_auto_card.instance_id) {
                    _queen_auto_in_row = true;
                }
            }
            _assert(
                _queen_reached_second
                && is_undefined(special_containment_sequence)
                && array_length(game_state.shop_row) == 5
                && (_queen_auto_in_deck || _queen_auto_in_row)
                && (!_queen_auto_in_row
                    ? is_undefined(pending_choice)
                    : (!is_undefined(pending_choice)
                        && pending_choice.kind == "queen_event"
                        && pending_choice.stage == "revealed")),
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
        next_card_instance_id = _saved_next_card_id;
        next_metroid_instance_id = _saved_next_metroid_id;
        faction_starters_enabled = _saved_faction_starters_enabled;
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
        show_debug_message(
            "[REGRESSION] " + string(_assert_context.passed) + " passed, "
            + string(_assert_context.failed) + " failed. "
            + get_export_display_path(_path)
        );
        return _assert_context.failed == 0;
    };

}

