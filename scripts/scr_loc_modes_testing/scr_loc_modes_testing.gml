function loc_modes_testing() {
    get_leader_identity_config = function(_leader_id) {
        switch (_leader_id) {
            case "adam_malkovich": return {
                name: "Adam Malkovich",
                faction: "GF",
                starter_id: "loc.gf_marine"
            };
            case "mother_brain": return {
                name: "Mother Brain",
                faction: "SP",
                starter_id: "loc.zebesian_pirate"
            };
            case "quiet_robe": return {
                name: "Quiet Robe",
                faction: "CZ",
                starter_id: "loc.quiet_robe"
            };
            case "raven_beak": return {
                name: "Raven Beak",
                faction: "CZ",
                starter_id: "loc.raven_beak"
            };
            default: return {
                name: "B.S.L. Researcher",
                faction: "",
                starter_id: "loc.armoured_frigate"
            };
        }
    };

    resolve_leader_identity_id = function(_leader_id) {
        if (_leader_id == "random") {
            return title_leader_keys[
                irandom_range(1, array_length(title_leader_keys) - 1)
            ];
        }
        return _leader_id;
    };

    apply_leader_identity = function(_player, _leader_id) {
        _leader_id = resolve_leader_identity_id(_leader_id);
        var _leader = get_leader_identity_config(_leader_id);
        _player.leader_identity_id = _leader_id;
        _player.name = _leader.name;
        _player.favored_faction = _leader.faction;
        return apply_identity_starter(
            _player,
            false,
            _leader.starter_id,
            true
        );
    };

    get_identity_starter_config = function(_faction, _forced_starter_id) {
        switch (_faction) {
            case "GF": return {
                starter_id: "loc.gf_marine",
                replace_id: "starter.full_deck",
                deck_ids: [
                    "loc.gf_soldier",
                    "loc.gf_soldier",
                    "loc.gf_marine",
                    "loc.g_f_s_tyr",
                    "loc.adam_malkovich",
                    "loc.biologic_space_laboratories",
                    "starter.researcher",
                    "starter.private_military",
                    "starter.private_military",
                    "loc.g_f_s_olympus"
                ]
            };
            case "SP": return {
                starter_id: "loc.zebesian_pirate",
                replace_id: "starter.full_deck",
                deck_ids: [
                    "loc.zebesian_pirate",
                    "loc.frigate_orpheon",
                    "starter.sloop",
                    "loc.beam_pirate",
                    "loc.space_pirate_homeworld",
                    "starter.researcher",
                    "starter.ship_captain",
                    "starter.private_military",
                    "starter.private_military",
                    "starter.orders_received"
                ]
            };
            case "CZ":
                var _chozo_identity_id = is_undefined(_forced_starter_id)
                    || _forced_starter_id == ""
                    ? choose("loc.quiet_robe", "loc.raven_beak")
                    : _forced_starter_id;
                return {
                    starter_id: _chozo_identity_id,
                    replace_id: "starter.full_deck",
                    deck_ids: _chozo_identity_id == "loc.quiet_robe"
                        ? [
                            "loc.samus_aran",
                            "loc.quiet_robe",
                            "loc.gunship",
                            "loc.chozo_transport",
                            "starter.researcher",
                            "starter.ship_captain",
                            "starter.private_military",
                            "starter.private_military",
                            "starter.orders_received",
                            "starter.away_team"
                        ]
                        : [
                            "loc.samus_aran",
                            "loc.chozo_warrior",
                            "loc.gunship",
                            "loc.mawkin_starship",
                            "starter.researcher",
                            "starter.ship_captain",
                            "starter.private_military",
                            "starter.private_military",
                            "starter.orders_received",
                            "starter.away_team"
                        ]
                };
            case "BH": return {
                starter_id: "loc.ghor",
                replace_id: "starter.budget_cuts"
            };
            case "PZ": return {
                starter_id: "lop.hive_mind_communication",
                replace_id: "starter.orders_received"
            };
            default: return {
                starter_id: "loc.armoured_frigate",
                replace_id: "starter.full_deck",
                deck_ids: [
                    "lop.dark_samus",
                    "loc.gandrayda",
                    "starter.private_military",
                    "starter.private_military",
                    "starter.researcher",
                    "loc.security_guard",
                    "lop.hive_mind_communication",
                    "starter.away_team",
                    "loc.delano_7",
                    "loc.armoured_frigate"
                ]
            };
        }
    };

    apply_identity_starter = function(
        _player,
        _rename_identity,
        _forced_starter_id,
        _force_enabled
    ) {
        var _forced = !is_undefined(_force_enabled) && _force_enabled;
        if ((!faction_starters_enabled || !_player.is_ai) && !_forced) {
            return false;
        }

        // Recombine the untouched opening deck, make the identity-specific
        // replacement, then redeal. This preserves a ten-card starter deck and
        // gives the faction card the same opening-hand odds as every other starter.
        for (var _starter_hand_index = 0;
             _starter_hand_index < array_length(_player.hand);
             _starter_hand_index++) {
            var _starter_hand_card = _player.hand[_starter_hand_index];
            clear_card_board_state(_starter_hand_card);
            _starter_hand_card.zone = "deck";
            array_push(_player.deck, _starter_hand_card);
        }
        _player.hand = [];

        var _starter_config = get_identity_starter_config(
            _player.favored_faction,
            _forced_starter_id
        );
        var _starter_id = _starter_config.starter_id;
        var _starter_definition = get_card_definition(_starter_id);
        var _starter_applied = false;
        var _replaced_name = "the neutral starter deck";
        if (variable_struct_exists(_starter_config, "deck_ids")) {
            _player.deck = [];
            _starter_applied = true;
            for (var _faction_deck_index = 0;
                 _faction_deck_index < array_length(_starter_config.deck_ids);
                 _faction_deck_index++) {
                var _faction_deck_id =
                    _starter_config.deck_ids[_faction_deck_index];
                var _faction_deck_definition = get_card_definition(
                    _faction_deck_id
                );
                if (is_undefined(_faction_deck_definition)) {
                    _starter_applied = false;
                    array_push(
                        setup_errors,
                        "Unknown faction starter card " + _faction_deck_id + "."
                    );
                    continue;
                }
                array_push(
                    _player.deck,
                    make_card_instance(
                        _faction_deck_definition,
                        _player.index,
                        "deck"
                    )
                );
            }
        } else {
            var _replace_index = -1;
            var _replaced_definition = undefined;
            for (var _starter_deck_index = 0;
                 _starter_deck_index < array_length(_player.deck);
                 _starter_deck_index++) {
                if (_player.deck[_starter_deck_index].definition_id
                == _starter_config.replace_id) {
                    _replace_index = _starter_deck_index;
                    _replaced_definition =
                        _player.deck[_starter_deck_index].definition;
                    break;
                }
            }
            if (_replace_index >= 0 && !is_undefined(_starter_definition)) {
                array_delete(_player.deck, _replace_index, 1);
                array_push(
                    _player.deck,
                    make_card_instance(
                        _starter_definition,
                        _player.index,
                        "deck"
                    )
                );
                _starter_applied = true;
                _replaced_name = _replaced_definition.name;
            }
        }
        if (_starter_applied) {
            _player.identity_starter_id = _starter_id;
            _player.identity_starter_replaced_id = _starter_config.replace_id;
        } else {
            array_push(
                setup_errors,
                "Could not apply identity starter " + _starter_id
                    + " for " + _player.name + "."
            );
        }

        shuffle_array(_player.deck);
        draw_from_deck(_player, 5);
        if (_starter_applied) {
            if (_rename_identity && _player.favored_faction == "CZ") {
                _player.name = _starter_id == "loc.quiet_robe"
                    ? "Thoha"
                    : "Mawkin";
            }
            array_push(
                game_state.event_log,
                _player.name + " replaced " + _replaced_name + " with its "
                    + batch_profile_label(_player.favored_faction)
                    + " starter configuration."
            );
        }
        return _starter_applied;
    };

    start_game_mode = function(_mode) {
        if (!title_menu_active) {
            return false;
        }
        var _is_ai_mode = _mode == "ai" || _mode == "ai_watch";
        if (_is_ai_mode
        && (!variable_global_exists("loc_ai_random_seed_ready")
            || !global.loc_ai_random_seed_ready)) {
            randomize();
            global.loc_test_seed = irandom(2147483646);
            global.loc_ai_random_seed_ready = true;
            global.loc_ai_start_mode = _mode;
            room_restart();
            return true;
        }
        if (_is_ai_mode
        && variable_global_exists("loc_ai_random_seed_ready")) {
            global.loc_ai_random_seed_ready = false;
        }
        game_state.game_mode = _mode;
        board_camera_center_far = settings_default_center_far;
        board_camera_locked = settings_default_camera_locked;
        board_camera_recenter_requested = true;
        game_state.players[0].name = net_player_name;
        game_state.players[0].is_ai = _mode == "ai_watch";
        game_state.players[1].is_ai = _is_ai_mode;
        game_state.players[0].favored_faction = "";
        game_state.players[1].favored_faction = "";
        if (_mode != "network") {
            apply_leader_identity(
                game_state.players[0],
                title_leader_keys[title_leader_p1_index]
            );
            apply_leader_identity(
                game_state.players[1],
                title_leader_keys[title_leader_p2_index]
            );
            if (game_state.players[0].name == game_state.players[1].name) {
                game_state.players[0].name += " Alpha";
                game_state.players[1].name += " Beta";
            }
            if (_mode == "ai") {
                game_state.players[0].name = net_player_name;
            } else if (_mode == "hotseat") {
                game_state.players[0].name = net_player_name;
                game_state.players[1].name = title_player_two_name;
            }
        }
        game_state.view_player = 0;
        ai_action_delay = _mode == "ai_watch" ? 700 : 420;
        ai_next_step_time = current_time + ai_action_delay;
        title_menu_active = false;
        array_push(
            game_state.event_log,
            _mode == "ai_watch"
                ? "Game mode selected: Slow AI vs AI ("
                    + game_state.players[0].name + " vs "
                    + game_state.players[1].name + ")."
                : (_mode == "ai"
                    ? "Game mode selected: VS AI ("
                        + game_state.players[1].name + ")."
                    : "Game mode selected: Hotseat.")
        );
        try {
            sync_balance_live_log();
        } catch (_initial_balance_sync_error) {
            show_debug_message(
                "[BALANCE] Initial live log failed: "
                + string(_initial_balance_sync_error)
            );
        }
        return true;
    };

    begin_rematch = function() {
        randomize();
        global.loc_test_seed = irandom(2147483646);
        global.loc_rematch_config = {
            pending: true,
            mode: game_state.game_mode,
            faction_starters_enabled: faction_starters_enabled,
            player_names: [
                game_state.players[0].name,
                game_state.players[1].name
            ],
            player_is_ai: [
                game_state.players[0].is_ai,
                game_state.players[1].is_ai
            ],
            player_profiles: [
                game_state.players[0].favored_faction,
                game_state.players[1].favored_faction
            ],
            player_starters: [
                game_state.players[0].identity_starter_id,
                game_state.players[1].identity_starter_id
            ],
            player_leaders: [
                game_state.players[0].leader_identity_id,
                game_state.players[1].leader_identity_id
            ]
        };
        room_restart();
        return true;
    };

    resume_rematch = function() {
        if (!variable_global_exists("loc_rematch_config")
        || !global.loc_rematch_config.pending) {
            return false;
        }
        var _rematch = global.loc_rematch_config;
        _rematch.pending = false;
        game_state.game_mode = _rematch.mode;
        faction_starters_enabled = _rematch.faction_starters_enabled;
        for (var _rematch_player_index = 0;
             _rematch_player_index < 2;
             _rematch_player_index++) {
            var _rematch_player = game_state.players[_rematch_player_index];
            _rematch_player.name = _rematch.player_names[_rematch_player_index];
            _rematch_player.is_ai = _rematch.player_is_ai[_rematch_player_index];
            _rematch_player.favored_faction =
                _rematch.player_profiles[_rematch_player_index];
            if (variable_struct_exists(_rematch, "player_leaders")
            && _rematch.player_leaders[_rematch_player_index] != "") {
                apply_leader_identity(
                    _rematch_player,
                    _rematch.player_leaders[_rematch_player_index]
                );
            } else if (_rematch_player.is_ai) {
                apply_identity_starter(
                    _rematch_player,
                    false,
                    _rematch.player_starters[_rematch_player_index]
                );
            }
            _rematch_player.name = _rematch.player_names[
                _rematch_player_index
            ];
        }
        game_state.view_player = 0;
        ai_action_delay = game_state.game_mode == "ai_watch" ? 700 : 420;
        ai_next_step_time = current_time + ai_action_delay;
        title_menu_active = false;
        array_push(
            game_state.event_log,
            "Rematch started with seed " + string(game_state.seed) + "."
        );
        return true;
    };

    begin_debug_headless_game_over = function() {
        if (game_state.phase == "game_over") {
            return false;
        }
        debug_headless_original_mode = game_state.game_mode;
        debug_headless_original_ai = [
            game_state.players[0].is_ai,
            game_state.players[1].is_ai
        ];
        game_state.players[0].is_ai = true;
        game_state.players[1].is_ai = true;
        debug_headless_to_game_over_active = true;
        debug_headless_steps = 0;
        debug_headless_last_signature = "";
        debug_headless_same_state_steps = 0;
        test_tools_open = false;
        pending_choice = undefined;
        array_push(
            game_state.event_log,
            "TEST: Headless simulation started for game-over presentation."
        );
        return true;
    };

    open_random_end_screen_preview = function() {
        var _preview_factions = ["", "GF", "SP", "CZ", "BH", "PZ"];
        var _preview_names = function(_faction) {
            switch (_faction) {
                case "GF": return "Galactic Federation";
                case "SP": return "Space Pirate";
                case "CZ": return choose("Thoha", "Mawkin");
                case "BH": return "Bounty Hunter";
                case "PZ": return "Phazon";
                default: return "Mercenary";
            }
        };
        var _faction_0 = _preview_factions[irandom(array_length(
            _preview_factions
        ) - 1)];
        var _faction_1 = _preview_factions[irandom(array_length(
            _preview_factions
        ) - 1)];
        var _name_0 = _preview_names(_faction_0);
        var _name_1 = _preview_names(_faction_1);
        if (_name_0 == _name_1) {
            _name_0 += " Alpha";
            _name_1 += " Beta";
        }
        var _research = [irandom(3), irandom(3)];
        var _cp = [irandom(3), irandom(3)];
        var _winner = -1;
        if (_research[0] != _research[1]) {
            _winner = _research[0] > _research[1] ? 0 : 1;
        } else if (_cp[0] != _cp[1]) {
            _winner = _cp[0] > _cp[1] ? 0 : 1;
        }
        end_screen_preview = {
            names: [_name_0, _name_1],
            factions: [_faction_0, _faction_1],
            research: _research,
            cp: _cp,
            metroids: [irandom(3), irandom(3)],
            winner: _winner
        };
        game_state.phase = "game_over";
        game_state.winner = _winner;
        test_tools_open = false;
        return true;
    };

    run_animation_audit_scenario = function(_scenario) {
        var _player_index = game_state.view_player;
        var _player = game_state.players[_player_index];
        game_state.active_player = _player_index;
        game_state.priority_player = _player_index;
        game_state.phase = "action";
        _player.command_points = max(_player.command_points, 99);
        ai_next_step_time = current_time + 1800;
        var _started = false;

        switch (_scenario) {
            case "deploy":
                var _deploy_found = false;
                for (var _i = 0; _i < array_length(_player.hand); _i++) {
                    var _card = _player.hand[_i];
                    if (string_lower(_card.definition.type) != "event"
                    && is_real(_card.definition.costs.deploy)) {
                        _deploy_found = true;
                        _started = play_hand_card(_i);
                        break;
                    }
                }
                if (!_deploy_found) {
                    var _deploy_card = make_card_instance(
                        get_card_definition("starter.researcher"),
                        _player_index,
                        "hand"
                    );
                    _deploy_card.ui_position_initialized = true;
                    _deploy_card.ui_x = board_viewport_right * 0.5;
                    _deploy_card.ui_y = ui_screen_height - 24;
                    _deploy_card.ui_zone = "active_hand";
                    if (array_length(_player.hand) > 0) {
                        var _hand_anchor = _player.hand[0];
                        _deploy_card.ui_position_initialized = true;
                        _deploy_card.ui_x = _hand_anchor.ui_x;
                        _deploy_card.ui_y = _hand_anchor.ui_y;
                        _deploy_card.ui_zone = "active_hand";
                    }
                    array_push(_player.hand, _deploy_card);
                    _started = play_hand_card(array_length(_player.hand) - 1);
                }
                break;
            case "event":
                _player.event_played_this_turn = false;
                var _event_found = false;
                for (var _i = 0; _i < array_length(_player.hand); _i++) {
                    if (string_lower(_player.hand[_i].definition.type) == "event") {
                        _event_found = true;
                        _started = play_hand_card(_i);
                        break;
                    }
                }
                if (!_event_found) {
                    var _event_card = make_card_instance(
                        get_card_definition("starter.orders_received"),
                        _player_index,
                        "hand"
                    );
                    _event_card.ui_position_initialized = true;
                    _event_card.ui_x = board_viewport_right * 0.5;
                    _event_card.ui_y = ui_screen_height - 24;
                    _event_card.ui_zone = "active_hand";
                    if (array_length(_player.hand) > 0) {
                        var _event_anchor = _player.hand[0];
                        _event_card.ui_position_initialized = true;
                        _event_card.ui_x = _event_anchor.ui_x;
                        _event_card.ui_y = _event_anchor.ui_y;
                        _event_card.ui_zone = "active_hand";
                    }
                    array_push(_player.hand, _event_card);
                    _started = play_hand_card(array_length(_player.hand) - 1);
                }
                break;
            case "reserve":
                var _reserve_found = false;
                for (var _i = 0; _i < array_length(game_state.shop_row); _i++) {
                    if (is_real(game_state.shop_row[_i].definition.costs.reserve)) {
                        _reserve_found = true;
                        _started = reserve_shop_card(_i);
                        break;
                    }
                }
                if (!_reserve_found) {
                    var _reserve_card = make_card_instance(
                        get_card_definition("loc.gf_marine"),
                        -1,
                        "shop"
                    );
                    if (array_length(game_state.shop_row) > 0) {
                        var _old_shop_card = game_state.shop_row[0];
                        _reserve_card.ui_position_initialized =
                            _old_shop_card.ui_position_initialized;
                        _reserve_card.ui_x = _old_shop_card.ui_x;
                        _reserve_card.ui_y = _old_shop_card.ui_y;
                        _reserve_card.ui_zone = _old_shop_card.ui_zone;
                        _old_shop_card.zone = "shop_discard";
                        array_push(game_state.shop_discard, _old_shop_card);
                        game_state.shop_row[0] = _reserve_card;
                        _started = reserve_shop_card(0);
                    } else {
                        array_push(game_state.shop_row, _reserve_card);
                        _started = reserve_shop_card(0);
                    }
                }
                break;
            case "refresh_hand":
                if (array_length(_player.hand) <= 0) {
                    var _refresh_seed_card = make_card_instance(
                        get_card_definition("starter.researcher"),
                        _player_index,
                        "hand"
                    );
                    _refresh_seed_card.ui_position_initialized = true;
                    _refresh_seed_card.ui_x = board_viewport_right * 0.5;
                    _refresh_seed_card.ui_y = ui_screen_height - 24;
                    _refresh_seed_card.ui_zone = "active_hand";
                    array_push(_player.hand, _refresh_seed_card);
                }
                var _refresh_indices = [];
                for (var _i = 0; _i < array_length(_player.hand); _i++) {
                    array_push(_refresh_indices, _i);
                }
                _started = array_length(_refresh_indices) > 0
                    && refresh_hand_cards(_refresh_indices);
                break;
            case "refresh_shop":
                _started = refresh_shop_action();
                break;
            case "shuffle":
                while (array_length(_player.deck) > 0) {
                    var _deck_card = array_pop(_player.deck);
                    clear_card_board_state(_deck_card);
                    _deck_card.zone = "discard";
                    array_push(_player.discard, _deck_card);
                }
                if (array_length(_player.discard) <= 0
                && array_length(_player.hand) > 0) {
                    var _hand_card = array_pop(_player.hand);
                    clear_card_board_state(_hand_card);
                    _hand_card.zone = "discard";
                    array_push(_player.discard, _hand_card);
                }
                if (array_length(_player.discard) <= 0) {
                    array_push(_player.discard, make_card_instance(
                        get_card_definition("starter.orders_received"),
                        _player_index,
                        "discard"
                    ));
                }
                if (array_length(_player.discard) > 0) {
                    draw_from_deck(_player, 1);
                    _started = true;
                }
                break;
            case "evolve":
                var _evolve_slot = -1;
                for (var _i = 0; _i < array_length(game_state.sr388); _i++) {
                    if (!is_undefined(game_state.sr388[_i])
                    && game_state.sr388[_i].definition.stage < 5) {
                        _evolve_slot = _i;
                        break;
                    }
                }
                if (_evolve_slot < 0) {
                    _evolve_slot = 0;
                    game_state.sr388[_evolve_slot] = create_metroid_for_stage(1);
                }
                evolve_sr388_slot(_evolve_slot);
                _started = true;
                break;
            case "phazon":
                var _zones = [
                    _player.board.ships,
                    _player.board.characters,
                    _player.board.locations
                ];
                for (var _z = 0; _z < array_length(_zones) && !_started; _z++) {
                    if (array_length(_zones[_z]) > 0) {
                        _zones[_z][0].phazon_tokens += 1;
                        _started = true;
                    }
                }
                if (!_started) {
                    var _phazon_card = make_card_instance(
                        get_card_definition("starter.researcher"),
                        _player_index,
                        "board"
                    );
                    array_push(_player.board.characters, _phazon_card);
                    _phazon_card.phazon_tokens = 1;
                    _started = true;
                }
                break;
            case "lab_intake":
                if (array_length(_player.board.ships) <= 0) {
                    var _audit_ship = make_card_instance(
                        get_card_definition("starter.sloop"),
                        _player_index,
                        "board"
                    );
                    array_push(_player.board.ships, _audit_ship);
                }
                var _ship = _player.board.ships[0];
                if (array_length(_ship.cargo) <= 0) {
                    var _metroid = create_metroid_for_stage(1);
                    _metroid.zone = "cargo";
                    _metroid.host_ship_instance_id = _ship.instance_id;
                    _metroid.ui_position_initialized = true;
                    _metroid.ui_x = _ship.ui_position_initialized
                        ? _ship.ui_x : board_layout_width * 0.5;
                    _metroid.ui_y = _ship.ui_position_initialized
                        ? _ship.ui_y : board_layout_height * 0.68;
                    array_push(_ship.cargo, _metroid);
                }
                resolve_lab_intake();
                _started = true;
                break;
            case "capture":
                if (array_length(_player.board.ships) <= 0) {
                    array_push(_player.board.ships, make_card_instance(
                        get_card_definition("starter.sloop"),
                        _player_index,
                        "board"
                    ));
                }
                var _capture_ship = _player.board.ships[0];
                _capture_ship.ready = true;
                _capture_ship.cargo = [];
                if (!_capture_ship.ui_position_initialized) {
                    _capture_ship.ui_position_initialized = true;
                    _capture_ship.ui_x = board_layout_width * 0.5;
                    _capture_ship.ui_y = board_layout_height * 0.70;
                    _capture_ship.ui_zone = "ship";
                }
                game_state.sr388[0] = create_metroid_for_stage(1);
                game_state.sr388[0].ui_position_initialized = true;
                game_state.sr388[0].ui_x = board_layout_width * 0.5;
                game_state.sr388[0].ui_y = board_layout_height * 0.5;
                game_state.sr388[0].ui_zone = "sr388";
                _started = capture_metroid_action(0, 0);
                break;
            case "attachment":
                var _attachment_host = make_card_instance(
                    get_card_definition("starter.sloop"),
                    _player_index,
                    "board"
                );
                var _attachment_source = make_card_instance(
                    get_card_definition("starter.researcher"),
                    _player_index,
                    "board"
                );
                _attachment_source.ui_position_initialized = true;
                _attachment_source.ui_x = board_layout_width * 0.35;
                _attachment_source.ui_y = board_layout_height * 0.62;
                array_push(_player.board.ships, _attachment_host);
                array_push(_player.board.characters, _attachment_source);
                _started = move_source_to_attachment(
                    "character",
                    array_length(_player.board.characters) - 1,
                    _attachment_source,
                    _attachment_host
                );
                break;
            case "target_friendly":
            case "target_enemy":
                var _line_source = make_card_instance(
                    get_card_definition("starter.researcher"),
                    _player_index,
                    "board"
                );
                array_push(_player.board.characters, _line_source);
                var _line_target_player = _scenario == "target_enemy"
                    ? game_state.players[1 - _player_index] : _player;
                var _line_target = make_card_instance(
                    get_card_definition("starter.private_military"),
                    _line_target_player.index,
                    "board"
                );
                array_push(_line_target_player.board.characters, _line_target);
                presentation_target_effect = {
                    source: _line_source,
                    target: _line_target,
                    target_kind: "audit",
                    target_index: -1,
                    started_at_ms: current_time,
                    resolve_at_ms: current_time + 900,
                    audit_only: true
                };
                _started = true;
                break;
            case "discard":
            case "destroy":
                var _leaving_card = make_card_instance(
                    get_card_definition("starter.private_military"),
                    _player_index,
                    "board"
                );
                _leaving_card.ui_position_initialized = true;
                _leaving_card.ui_x = board_layout_width * 0.5;
                _leaving_card.ui_y = board_layout_height * 0.62;
                array_push(_player.board.characters, _leaving_card);
                remove_ability_source(
                    "character",
                    array_length(_player.board.characters) - 1,
                    _leaving_card,
                    _scenario == "destroy"
                );
                _started = true;
                break;
            case "raid_line":
                var _raid_defender = game_state.players[1 - _player_index];
                if (array_length(_player.board.ships) <= 0) {
                    array_push(_player.board.ships, make_card_instance(
                        get_card_definition("starter.sloop"), _player_index, "board"
                    ));
                }
                if (array_length(_raid_defender.board.ships) <= 0) {
                    array_push(_raid_defender.board.ships, make_card_instance(
                        get_card_definition("starter.sloop"),
                        _raid_defender.index,
                        "board"
                    ));
                }
                pending_choice = {
                    kind: "raid",
                    stage: "attackers",
                    attacker_ship_id: _player.board.ships[0].instance_id,
                    defender_ship_id: _raid_defender.board.ships[0].instance_id,
                    attacker_characters: [],
                    defender_characters: [],
                    attacker_ability_bonus: 0,
                    defender_ability_bonus: 0,
                    interaction_mode: "abilities",
                    ability_source_kind: "",
                    ability_source_index: -1,
                    ability_index: -1,
                    raid_cost: 0,
                    prompt: "TEST ANIMATION: Raid targeting line.",
                    audit_only: true,
                    audit_expires_ms: current_time + 1200
                };
                _started = true;
                break;
            case "breaches":
                _player.lab = [
                    create_metroid_for_stage(5),
                    create_metroid_for_stage(5)
                ];
                for (var _lab_i = 0; _lab_i < 2; _lab_i++) {
                    _player.lab[_lab_i].zone = "lab";
                }
                while (array_length(_player.board.characters) < 2) {
                    array_push(_player.board.characters, make_card_instance(
                        get_card_definition("starter.private_military"),
                        _player_index,
                        "board"
                    ));
                }
                _started = begin_containment_sequence(
                    _player_index, 0, -1, true, "turn"
                );
                break;
            case "queen":
                test_force_queen();
                _started = !is_undefined(pending_choice)
                    && pending_choice.kind == "queen_event";
                break;
        }
        if (_started) {
            test_tools_open = false;
            array_push(game_state.event_log,
                "TEST ANIMATION: " + string_upper(_scenario) + ".");
        } else {
            array_push(game_state.event_log,
                "TEST ANIMATION: " + string_upper(_scenario)
                + " could not start from the current board state.");
        }
        return _started;
    };

    handle_test_tool_action = function(_action) {
        if (!settings_debug_mode) {
            return false;
        }
        switch (_action) {
            case "test_open":
                if (is_undefined(pending_choice)) {
                    test_selected_kind = ui_selected_kind;
                    test_selected_index = ui_selected_index;
                    test_tools_open = true;
                }
                return true;
            case "test_close": test_tools_open = false; return true;
            case "test_tab_game": test_tools_tab = "game"; return true;
            case "test_tab_animation": test_tools_tab = "animation"; return true;
            case "test_anim_deploy": return run_animation_audit_scenario("deploy");
            case "test_anim_event": return run_animation_audit_scenario("event");
            case "test_anim_reserve": return run_animation_audit_scenario("reserve");
            case "test_anim_refresh_hand": return run_animation_audit_scenario("refresh_hand");
            case "test_anim_refresh_shop": return run_animation_audit_scenario("refresh_shop");
            case "test_anim_shuffle": return run_animation_audit_scenario("shuffle");
            case "test_anim_evolve": return run_animation_audit_scenario("evolve");
            case "test_anim_phazon": return run_animation_audit_scenario("phazon");
            case "test_anim_lab": return run_animation_audit_scenario("lab_intake");
            case "test_anim_page":
                test_animation_page = 1 - test_animation_page;
                return true;
            case "test_anim_capture": return run_animation_audit_scenario("capture");
            case "test_anim_attachment": return run_animation_audit_scenario("attachment");
            case "test_anim_target_friendly": return run_animation_audit_scenario("target_friendly");
            case "test_anim_target_enemy": return run_animation_audit_scenario("target_enemy");
            case "test_anim_discard": return run_animation_audit_scenario("discard");
            case "test_anim_destroy": return run_animation_audit_scenario("destroy");
            case "test_anim_raid": return run_animation_audit_scenario("raid_line");
            case "test_anim_breaches": return run_animation_audit_scenario("breaches");
            case "test_anim_queen": return run_animation_audit_scenario("queen");
            case "test_cp":
                game_state.players[game_state.active_player].command_points += 5;
                array_push(game_state.event_log, "TEST: Added 5 CP.");
                return true;
            case "test_ready": test_ready_active_player(); return true;
            case "test_deploy": test_deploy_selected_shop(); return true;
            case "test_larva": test_add_metroid_to_selected_ship(1); return true;
            case "test_omega": test_add_metroid_to_selected_ship(5); return true;
            case "test_queen": test_force_queen(); return true;
            case "test_game_over": begin_debug_headless_game_over(); return true;
            case "test_random_win": open_random_end_screen_preview(); return true;
            case "test_fixed_seed":
                global.loc_test_seed = 388;
                room_restart();
                return true;
            case "test_random_seed":
                randomize();
                global.loc_test_seed = irandom(2147483646);
                room_restart();
                return true;
        }
        return false;
    };

}

