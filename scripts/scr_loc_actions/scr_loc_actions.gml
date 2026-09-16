function loc_actions() {
    log_action_failure = function(_message) {
        array_push(game_state.event_log, "ACTION FAILED: " + _message);
    };

    put_card_in_play = function(_player, _card) {
        _card.zone = "board";
        _card.owner = _player.index;
        _card.controller = _player.index;
        _card.ready = true;
        if (_card.definition_id == "lop.corrupt_rundas") {
            _card.phazon_tokens = 3;
            array_push(
                game_state.event_log,
                "Corrupt Rundas entered play with 3 Phazon tokens."
            );
        }

        switch (_card.definition.type) {
            case "character":
                array_push(_player.board.characters, _card);
                return true;

            case "ship":
                array_push(_player.board.ships, _card);
                return true;

            case "relic":
                array_push(_player.board.relics, _card);
                return true;

            case "location":
                array_push(_player.board.locations, _card);
                return true;
        }

        return false;
    };

    get_zebes_discount = function(_player, _card) {
        if (!card_has_faction(_card, "CZ")) {
            return 0;
        }
        var _discount = 0;
        for (var _location_index = 0;
             _location_index < array_length(_player.board.locations);
             _location_index++) {
            if (_player.board.locations[_location_index].definition_id
            == "loc.zebes") {
                _discount += 1;
            }
        }
        return _discount;
    };

    get_modified_reserve_cost = function(_player, _card) {
        var _base_cost = _card.definition.costs.reserve;
        if (!is_real(_base_cost)) {
            return _base_cost;
        }
        return max(
            0,
            _base_cost
            - min(_player.next_reserve_discount, _base_cost)
            - get_zebes_discount(_player, _card)
        );
    };

    get_modified_deploy_cost = function(_player, _card) {
        var _base_cost = _card.definition.costs.deploy;
        if (!is_real(_base_cost)) {
            return _base_cost;
        }
        return max(0, _base_cost - get_zebes_discount(_player, _card));
    };

    reserve_shop_card = function(_shop_index) {
        if (game_state.phase != "action") {
            log_action_failure("Cards can only be reserved during the action phase.");
            return false;
        }
        if (_shop_index < 0 || _shop_index >= array_length(game_state.shop_row)) {
            log_action_failure("Select a valid Shop card.");
            return false;
        }

        var _player = game_state.players[game_state.active_player];
        var _card = game_state.shop_row[_shop_index];
        var _base_cost = _card.definition.costs.reserve;
        if (!is_real(_base_cost)) {
            log_action_failure(_card.definition.name + " cannot be reserved.");
            return false;
        }

        var _discount = min(_player.next_reserve_discount, _base_cost);
        var _cost = get_modified_reserve_cost(_player, _card);
        if (_player.command_points < _cost) {
            log_action_failure(
                "Need " + string(_cost) + " CP to reserve "
                + _card.definition.name + "."
            );
            return false;
        }

        _player.command_points -= _cost;
        if (_discount > 0) {
            _player.next_reserve_discount = 0;
        }
        var _reserve_visual_until = current_time + 360;
        if (game_state.game_mode != "batch") {
            _card.ui_hide_until_ms = _reserve_visual_until;
            array_push(presentation_card_transits, {
                card: _card,
                player_index: _player.index,
                kind: "shop_to_discard",
                start_x: _card.ui_x,
                start_y: _card.ui_y,
                started_at_ms: current_time,
                duration_ms: 360
            });
        }
        array_delete(game_state.shop_row, _shop_index, 1);
        _card.owner = _player.index;
        _card.controller = _player.index;
        clear_card_board_state(_card);
        _card.zone = "discard";
        array_push(_player.discard, _card);
        telemetry_record_card_taken(_player, _card);
        array_push(
            game_state.event_log,
            _player.name + " reserved " + _card.definition.name
            + " for " + string(_cost) + " CP."
        );
        refill_shop();
        if (game_state.game_mode != "batch") {
            for (var _reserve_refill_index = 0;
                 _reserve_refill_index < array_length(game_state.shop_row);
                 _reserve_refill_index++) {
                game_state.shop_row[
                    _reserve_refill_index
                ].ui_hold_until_ms = max(
                    game_state.shop_row[
                        _reserve_refill_index
                    ].ui_hold_until_ms,
                    _reserve_visual_until
                );
            }
            var _reserve_replacement = game_state.shop_row[
                array_length(game_state.shop_row) - 1
            ];
            _reserve_replacement.ui_force_shop_origin = true;
        }
        selected_shop_index = clamp(
            selected_shop_index,
            0,
            array_length(game_state.shop_row) - 1
        );
        return true;
    };

    deploy_shop_card = function(_shop_index) {
        if (game_state.phase != "action") {
            log_action_failure("Cards can only be deployed during the action phase.");
            return false;
        }
        if (_shop_index < 0 || _shop_index >= array_length(game_state.shop_row)) {
            log_action_failure("Select a valid Shop card.");
            return false;
        }

        var _player = game_state.players[game_state.active_player];
        var _card = game_state.shop_row[_shop_index];
        if (_card.definition.type == "event") {
            log_action_failure("Events must be reserved before they can be played.");
            return false;
        }

        var _cost = get_modified_deploy_cost(_player, _card);
        if (!is_real(_cost)) {
            log_action_failure(_card.definition.name + " has no Deploy cost.");
            return false;
        }
        if (_player.command_points < _cost) {
            log_action_failure(
                "Need " + string(_cost) + " CP to deploy "
                + _card.definition.name + "."
            );
            return false;
        }

        _player.command_points -= _cost;
        var _deploy_refill_visual_until = current_time + 520;
        array_delete(game_state.shop_row, _shop_index, 1);
        put_card_in_play(_player, _card);
        telemetry_record_card_taken(_player, _card);
        array_push(
            game_state.event_log,
            _player.name + " deployed " + _card.definition.name
            + " for " + string(_cost) + " CP."
        );
        refill_shop();
        if (game_state.game_mode != "batch") {
            for (var _deploy_refill_index = 0;
                 _deploy_refill_index < array_length(game_state.shop_row);
                 _deploy_refill_index++) {
                game_state.shop_row[
                    _deploy_refill_index
                ].ui_hold_until_ms = max(
                    game_state.shop_row[
                        _deploy_refill_index
                    ].ui_hold_until_ms,
                    _deploy_refill_visual_until
                );
            }
            var _deploy_replacement = game_state.shop_row[
                array_length(game_state.shop_row) - 1
            ];
            _deploy_replacement.ui_force_shop_origin = true;
        }
        selected_shop_index = clamp(
            selected_shop_index,
            0,
            array_length(game_state.shop_row) - 1
        );
        return true;
    };

    evolve_lab_metroid_without_mutation = function(_player, _chosen_index) {
        var _best_index = -1;
        var _best_stage = -1;
        if (!is_undefined(_chosen_index)
        && _chosen_index >= 0
        && _chosen_index < array_length(_player.lab)) {
            var _chosen_stage = _player.lab[_chosen_index].definition.stage;
            if (is_real(_chosen_stage) && _chosen_stage < 5) {
                _best_index = _chosen_index;
                _best_stage = _chosen_stage;
            }
        } else {
            for (var _i = 0; _i < array_length(_player.lab); _i++) {
                var _stage = _player.lab[_i].definition.stage;
                if (is_real(_stage) && _stage < 5 && _stage > _best_stage) {
                    _best_stage = _stage;
                    _best_index = _i;
                }
            }
        }
        if (_best_index < 0) {
            array_push(game_state.event_log, "Torizo had no valid Lab Metroid to evolve.");
            return;
        }

        var _old_name = _player.lab[_best_index].definition.name;
        var _old_metroid = _player.lab[_best_index];
        var _evolved = create_metroid_for_stage(_best_stage + 1);
        _evolved.zone = "lab";
        _evolved.ui_position_initialized = _old_metroid.ui_position_initialized;
        _evolved.ui_x = _old_metroid.ui_x;
        _evolved.ui_y = _old_metroid.ui_y;
        _evolved.ui_zone = _old_metroid.ui_zone;
        if (game_state.game_mode != "batch"
        && game_state.game_mode != "network") {
            _evolved.evolution_old_definition = _old_metroid.definition;
            _evolved.evolution_started_ms = current_time;
            presentation_evolution_until_ms = max(
                presentation_evolution_until_ms,
                current_time + _evolved.evolution_duration_ms
            );
        }
        _player.lab[_best_index] = _evolved;
        array_push(
            game_state.event_log,
            "Torizo evolved " + _old_name + " into "
            + _evolved.definition.name + " without advancing Mutation."
        );
    };

    begin_torizo_metroid_choice = function(_player) {
        var _has_valid_metroid = false;
        for (var _lab_index = 0;
             _lab_index < array_length(_player.lab);
             _lab_index++) {
            var _lab_stage = _player.lab[_lab_index].definition.stage;
            if (is_real(_lab_stage) && _lab_stage < 5) {
                _has_valid_metroid = true;
                break;
            }
        }
        if (!_has_valid_metroid) {
            array_push(
                game_state.event_log,
                "Torizo had no valid Lab Metroid to evolve."
            );
            return false;
        }

        if (_player.is_ai) {
            evolve_lab_metroid_without_mutation(_player, undefined);
            return true;
        }

        pending_choice = {
            kind: "torizo_metroid",
            player_index: game_state.active_player,
            prompt: "Choose a Metroid in your Lab for Torizo to evolve."
        };
        ui_selected_kind = "lab_tab";
        ui_selected_index = 0;
        ui_selected_instance_id = -1;
        return true;
    };

    resolve_torizo_metroid_choice = function(_lab_index) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "torizo_metroid") {
            return false;
        }
        var _player = game_state.players[pending_choice.player_index];
        if (_lab_index < 0 || _lab_index >= array_length(_player.lab)) {
            return false;
        }
        var _stage = _player.lab[_lab_index].definition.stage;
        if (!is_real(_stage) || _stage >= 5) {
            return false;
        }
        evolve_lab_metroid_without_mutation(_player, _lab_index);
        pending_choice = undefined;
        ui_selected_kind = "";
        ui_selected_index = -1;
        ui_selected_instance_id = -1;
        return true;
    };

    begin_hyper_mode_choice = function(_player) {
        var _cards_to_scan = [];
        var _zones = [
            _player.board.characters,
            _player.board.ships,
            _player.board.locations,
            _player.board.relics
        ];
        for (var _zone_index = 0;
             _zone_index < array_length(_zones);
             _zone_index++) {
            var _zone = _zones[_zone_index];
            for (var _card_index = 0;
                 _card_index < array_length(_zone);
                 _card_index++) {
                array_push(_cards_to_scan, _zone[_card_index]);
            }
        }

        var _tokens_removed = 0;
        for (var _scan_index = 0;
             _scan_index < array_length(_cards_to_scan);
             _scan_index++) {
            var _scan_card = _cards_to_scan[_scan_index];
            if (_scan_card.controller == _player.index
            && _scan_card.phazon_tokens > 0) {
                _scan_card.phazon_tokens -= 1;
                _tokens_removed += 1;
            }
            for (var _attachment_index = 0;
                 _attachment_index < array_length(_scan_card.attachments);
                 _attachment_index++) {
                array_push(
                    _cards_to_scan,
                    _scan_card.attachments[_attachment_index]
                );
            }
        }

        if (_tokens_removed <= 0) {
            array_push(
                game_state.event_log,
                "Hyper Mode found no Phazon tokens to remove."
            );
            return true;
        }
        if (array_length(_player.board.characters) <= 0) {
            array_push(
                game_state.event_log,
                "Hyper Mode removed " + string(_tokens_removed)
                    + " Phazon token(s), but there was no Character to receive them."
            );
            return true;
        }

        game_state.priority_player = _player.index;
        pending_choice = {
            kind: "hyper_mode_character",
            player_index: _player.index,
            tokens_removed: _tokens_removed,
            prompt: "Hyper Mode: choose one Character you control to receive all "
                + string(_tokens_removed) + " removed Phazon token(s)."
        };
        return true;
    };

    resolve_hyper_mode_character = function(_character_index) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "hyper_mode_character") {
            return false;
        }
        var _player = game_state.players[pending_choice.player_index];
        if (_character_index < 0
        || _character_index >= array_length(_player.board.characters)) {
            return false;
        }
        var _character = _player.board.characters[_character_index];
        if (_character.controller != _player.index) {
            return false;
        }
        var _tokens = pending_choice.tokens_removed;
        _character.phazon_tokens += _tokens;
        array_push(
            game_state.event_log,
            "Hyper Mode moved " + string(_tokens) + " Phazon token(s) onto "
                + _character.definition.name + "."
        );
        pending_choice = undefined;
        ui_selected_kind = "";
        ui_selected_index = -1;
        ui_selected_instance_id = -1;
        return true;
    };

    begin_back_in_the_day_choice = function(_player) {
        var _owned_definition_ids = [];
        var _owned_zones = [
            _player.deck,
            _player.hand,
            _player.discard,
            _player.board.characters,
            _player.board.ships,
            _player.board.locations,
            _player.board.relics
        ];
        for (var _owned_zone_index = 0;
             _owned_zone_index < array_length(_owned_zones);
             _owned_zone_index++) {
            var _owned_zone = _owned_zones[_owned_zone_index];
            for (var _owned_card_index = 0;
                 _owned_card_index < array_length(_owned_zone);
                 _owned_card_index++) {
                var _owned_id = _owned_zone[_owned_card_index].definition_id;
                if (!raid_array_contains(_owned_definition_ids, _owned_id)) {
                    array_push(_owned_definition_ids, _owned_id);
                }
            }
        }
        for (var _removed_index = 0;
             _removed_index < array_length(game_state.removed_cards);
             _removed_index++) {
            var _removed_card = game_state.removed_cards[_removed_index];
            if (_removed_card.controller != _player.index) continue;
            if (!raid_array_contains(
                _owned_definition_ids,
                _removed_card.definition_id
            )) {
                array_push(
                    _owned_definition_ids,
                    _removed_card.definition_id
                );
            }
        }
        var _candidate_ids = [];
        var _candidate_names = [];
        for (var _shop_deck_index = 0;
             _shop_deck_index < array_length(game_state.shop_deck);
             _shop_deck_index++) {
            var _shop_search_card = game_state.shop_deck[_shop_deck_index];
            if (!raid_array_contains(
                _owned_definition_ids,
                _shop_search_card.definition_id
            ) || raid_array_contains(
                _candidate_ids,
                _shop_search_card.definition_id
            )) continue;
            array_push(_candidate_ids, _shop_search_card.definition_id);
            array_push(_candidate_names, _shop_search_card.definition.name);
        }
        if (array_length(_candidate_ids) <= 0) {
            array_push(
                game_state.event_log,
                "Back In the Day found no matching card in the Shop deck."
            );
            return true;
        }
        pending_choice = {
            kind: "back_in_the_day",
            player_index: _player.index,
            candidate_ids: _candidate_ids,
            candidate_names: _candidate_names,
            page: 0,
            prompt: "Choose a matching card from the Shop deck to add to your discard pile."
        };
        return true;
    };

    resolve_back_in_the_day_choice = function(_candidate_index) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "back_in_the_day"
        || _candidate_index < 0
        || _candidate_index >= array_length(pending_choice.candidate_ids)) {
            return false;
        }
        var _player = game_state.players[pending_choice.player_index];
        var _definition_id = pending_choice.candidate_ids[_candidate_index];
        for (var _shop_index = 0;
             _shop_index < array_length(game_state.shop_deck);
             _shop_index++) {
            var _found_card = game_state.shop_deck[_shop_index];
            if (_found_card.definition_id != _definition_id) continue;
            array_delete(game_state.shop_deck, _shop_index, 1);
            clear_card_board_state(_found_card);
            _found_card.controller = _player.index;
            _found_card.zone = "discard";
            array_push(_player.discard, _found_card);
            shuffle_array(game_state.shop_deck);
            array_push(
                game_state.event_log,
                _player.name + " found " + _found_card.definition.name
                    + " with Back In the Day and added it to their discard pile."
            );
            pending_choice = undefined;
            return true;
        }
        array_push(
            game_state.event_log,
            "Back In the Day's selected card was no longer in the Shop deck."
        );
        pending_choice = undefined;
        return true;
    };

    resolve_event_effect = function(_player, _card) {
        switch (_card.definition_id) {
            case "starter.orders_received":
                _player.command_points += 1;
                telemetry_update_max_cp(_player);
                array_push(game_state.event_log, "Orders Received granted 1 CP.");
                break;

            case "starter.budget_cuts":
                _player.next_reserve_discount = max(
                    _player.next_reserve_discount,
                    1
                );
                array_push(
                    game_state.event_log,
                    "Budget Cuts will reduce the next Reserve cost by 1 CP."
                );
                break;

            case "starter.away_team":
                _player.next_capture_discount = max(
                    _player.next_capture_discount,
                    1
                );
                array_push(
                    game_state.event_log,
                    "Away Team will reduce the next Capture cost by 1 CP."
                );
                break;

            case "starter.military_rations":
                _player.prevent_next_effect_exhaust = true;
                array_push(
                    game_state.event_log,
                    "Military Rations will prevent the next effect-based exhaustion."
                );
                break;

            case "loc.torizo":
                begin_torizo_metroid_choice(_player);
                break;

            case "loc.sa_x_breaks_out":
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
                break;

            case "loc.collision_course":
                for (var _slot = 0; _slot < 4; _slot++) {
                    game_state.sr388[_slot] = create_metroid_for_stage(1);
                }
                array_push(
                    game_state.event_log,
                    "Collision Course returned every SR388 slot to Larva."
                );
                break;

            case "lop.hive_mind_communication":
                _player.command_points += 2;
                telemetry_update_max_cp(_player);
                for (var _character_index = 0;
                     _character_index < array_length(_player.board.characters);
                     _character_index++) {
                    _player.board.characters[_character_index].phazon_tokens += 1;
                    array_push(
                        game_state.event_log,
                        _player.board.characters[_character_index].definition.name
                            + " gained 1 Phazon token from Hive Mind Communication ("
                            + string(_player.board.characters[
                                _character_index
                            ].phazon_tokens) + " total)."
                    );
                }
                array_push(
                    game_state.event_log,
                    "Hive Mind Communication granted 2 CP and spread Phazon."
                );
                break;

            case "loc.back_in_the_day":
                begin_back_in_the_day_choice(_player);
                break;

            case "lop.hyper_mode":
                begin_hyper_mode_choice(_player);
                break;

            default:
                array_push(
                    game_state.event_log,
                    _card.definition.name
                    + " has no scripted effect yet; its Event play still resolved."
                );
                break;
        }
    };

    can_play_hand_card = function(_hand_index) {
        if (game_state.phase != "action") {
            return false;
        }
        var _player = game_state.players[game_state.active_player];
        if (_hand_index < 0 || _hand_index >= array_length(_player.hand)) {
            return false;
        }
        var _card = _player.hand[_hand_index];
        if (_card.definition.type == "event") {
            return !_player.event_played_this_turn;
        }
        var _cost = _card.definition.costs.reserve;
        if (!is_real(_cost)) {
            return false;
        }
        _cost = max(0, _cost - get_zebes_discount(_player, _card));
        return _player.command_points >= _cost;
    };

    prepare_hand_card_for_world_motion = function(_card) {
        if (is_undefined(_card)
        || _card.ui_zone != "active_hand") {
            return;
        }
        _card.ui_x = board_camera_x
            + (_card.ui_x / max(0.01, board_camera_zoom));
        _card.ui_y = board_camera_y
            + ((_card.ui_y - board_viewport_top)
                / max(0.01, board_camera_zoom));
        _card.ui_zone = "hand_departing_world";
    };

    get_salvage_refund = function(_card) {
        if (is_undefined(_card)) return 0;
        return floor(max(0, _card.definition.costs.reserve) * 0.5);
    };

    can_salvage_permanent = function(_kind, _index) {
        var _base_kind = string_copy(_kind, 1, 9) == "opponent_"
            ? string_delete(_kind, 1, 9)
            : _kind;
        var _raid_ability_window = !is_undefined(pending_choice)
            && pending_choice.kind == "raid"
            && (pending_choice.stage == "attackers"
                || pending_choice.stage == "defenders");
        if (game_state.phase != "action"
        || (!_raid_ability_window
            && game_state.priority_player != game_state.active_player)
        || (_base_kind != "character"
            && _base_kind != "ship"
            && _base_kind != "relic"
            && _base_kind != "location")) {
            return false;
        }
        var _card = get_ability_source(_kind, _index);
        return !is_undefined(_card)
            && _card.zone == "board"
            && _card.ready
            && _card.controller == game_state.priority_player;
    };

    salvage_permanent = function(_kind, _index) {
        if (!can_salvage_permanent(_kind, _index)) {
            log_action_failure("Only a ready permanent you control can be salvaged during your action phase.");
            return false;
        }
        var _card = get_ability_source(_kind, _index);
        var _player = game_state.players[_card.controller];
        var _refund = get_salvage_refund(_card);
        var _name = _card.definition.name;
        remove_ability_source(_kind, _index, _card, false);
        _player.command_points += _refund;
        telemetry_update_max_cp(_player);
        array_push(game_state.event_log,
            _player.name + " salvaged " + _name + " for "
            + string(_refund) + " CP.");
        if (guidance_is_local_player(_player.index)) {
            queue_first_game_guidance(
                "salvage", "SALVAGE",
                "Salvage discards one of your ready Characters, Vehicles, Locations, or Relics and grants half its printed Reserve cost, rounded down. The discarded card is no longer available on your board."
            );
        }
        if (!is_undefined(pending_choice)
        && pending_choice.kind == "raid") {
            pending_choice.ability_source_kind = "";
            pending_choice.ability_source_index = -1;
            pending_choice.ability_index = -1;
        }
        ui_selected_kind = "";
        ui_selected_index = -1;
        return true;
    };

    play_hand_card = function(_hand_index) {
        if (game_state.phase != "action") {
            log_action_failure("Hand cards can only be played during the action phase.");
            return false;
        }

        var _player = game_state.players[game_state.active_player];
        if (_hand_index < 0 || _hand_index >= array_length(_player.hand)) {
            log_action_failure("Select a valid hand card.");
            return false;
        }

        var _card = _player.hand[_hand_index];
        if (_card.definition.type == "event") {
            if (_player.event_played_this_turn) {
                log_action_failure("Only one Event can be played each turn.");
                return false;
            }

            prepare_hand_card_for_world_motion(_card);
            array_delete(_player.hand, _hand_index, 1);
            _player.event_played_this_turn = true;
            array_push(
                game_state.event_log,
                _player.name + " played " + _card.definition.name + "."
            );
            var _event_removed_before_resolution =
                _card.definition_id == "loc.back_in_the_day";
            if (_event_removed_before_resolution) {
                clear_card_board_state(_card);
                _card.zone = "removed";
                array_push(game_state.removed_cards, _card);
                array_push(
                    game_state.event_log,
                    _card.definition.name + " was removed from the game."
                );
            }
            resolve_event_effect(_player, _card);
            var _event_was_destroyed = _card.definition_id == "loc.torizo";
            var _event_visual_until = current_time + 360;
            if (_event_removed_before_resolution) {
                queue_card_destruction(_card, "hand");
            } else {
                clear_card_board_state(_card);
                if (_event_was_destroyed) {
                    queue_card_destruction(_card, "hand");
                    _card.zone = "removed";
                    array_push(game_state.removed_cards, _card);
                    array_push(
                        game_state.event_log,
                        "Torizo was destroyed and removed from the game."
                    );
                } else {
                    _card.zone = "discard";
                    if (game_state.game_mode != "batch"
                    && _player.index == game_state.view_player) {
                        _card.ui_hide_until_ms = _event_visual_until;
                        array_push(presentation_card_transits, {
                            card: _card,
                            player_index: _player.index,
                            kind: "hand_event_to_discard",
                            start_x: _card.ui_x,
                            start_y: _card.ui_y,
                            started_at_ms: current_time,
                            duration_ms: 360
                        });
                    }
                    array_push(_player.discard, _card);
                    array_push(
                        game_state.event_log,
                        _card.definition.name
                            + " was discarded after its Event resolved."
                    );
                }
            }
            var _event_hand_count_before_draw = array_length(_player.hand);
            draw_from_deck(_player, 1);
            if (array_length(_player.hand) > _event_hand_count_before_draw) {
                var _event_replacement = _player.hand[
                    array_length(_player.hand) - 1
                ];
                _event_replacement.ui_force_deck_origin = true;
                _event_replacement.ui_hold_until_ms = max(
                    _event_replacement.ui_hold_until_ms,
                    _event_was_destroyed
                        ? current_time + 180
                        : _event_visual_until
                );
            }
        } else {
            var _cost = _card.definition.costs.reserve;
            if (!is_real(_cost)) {
                log_action_failure(_card.definition.name + " has no play cost.");
                return false;
            }
            _cost = max(0, _cost - get_zebes_discount(_player, _card));
            if (_player.command_points < _cost) {
                log_action_failure(
                    "Need " + string(_cost) + " CP to play "
                    + _card.definition.name + "."
                );
                return false;
            }

            _player.command_points -= _cost;
            var _hand_deploy_visual_until = current_time + 520;
            prepare_hand_card_for_world_motion(_card);
            array_delete(_player.hand, _hand_index, 1);
            put_card_in_play(_player, _card);
            array_push(
                game_state.event_log,
                _player.name + " played " + _card.definition.name
                + " for " + string(_cost) + " CP."
            );
            var _deploy_hand_count_before_draw = array_length(_player.hand);
            draw_from_deck(_player, 1);
            if (array_length(_player.hand) > _deploy_hand_count_before_draw) {
                var _hand_deploy_replacement = _player.hand[
                    array_length(_player.hand) - 1
                ];
                _hand_deploy_replacement.ui_force_deck_origin = true;
                _hand_deploy_replacement.ui_hold_until_ms = max(
                    _hand_deploy_replacement.ui_hold_until_ms,
                    _hand_deploy_visual_until
                );
            }
        }

        selected_hand_index = clamp(
            selected_hand_index,
            0,
            max(0, array_length(_player.hand) - 1)
        );
        // The departing instance owned the selection. Never transfer that state
        // to whichever card now occupies the same hand index.
        ui_selected_kind = "";
        ui_selected_index = -1;
        ui_selected_instance_id = -1;
        ui_context_preview_kind = "";
        ui_context_preview_index = -1;
        ui_context_preview_until_ms = 0;
        return true;
    };

    refresh_hand_cards = function(_selected_indices) {
        if (game_state.phase != "action") {
            log_action_failure("The hand can only be refreshed during the action phase.");
            return false;
        }
        var _player = game_state.players[game_state.active_player];
        if (_player.command_points < 1) {
            log_action_failure("Need 1 CP to refresh the hand.");
            return false;
        }
        if (!is_array(_selected_indices)) {
            log_action_failure("Invalid hand refresh selection.");
            return false;
        }
        if (array_length(_selected_indices) <= 0
        && array_length(_player.hand) >= 5) {
            log_action_failure("Select at least one hand card to refresh.");
            return false;
        }

        _player.command_points -= 1;
        var _discarded = 0;
        for (var _hand_index = array_length(_player.hand) - 1;
             _hand_index >= 0;
             _hand_index--) {
            if (!raid_array_contains(_selected_indices, _hand_index)) {
                continue;
            }
            var _card = _player.hand[_hand_index];
            prepare_hand_card_for_world_motion(_card);
            if (_player.index == game_state.view_player
            && game_state.game_mode != "batch") {
                _card.ui_hide_until_ms = current_time + 260;
                array_push(presentation_card_transits, {
                    card: _card,
                    player_index: _player.index,
                    kind: "hand_to_discard",
                    start_x: _card.ui_x,
                    start_y: _card.ui_y,
                    started_at_ms: current_time,
                    duration_ms: 260
                });
            }
            array_delete(_player.hand, _hand_index, 1);
            clear_card_board_state(_card);
            _card.zone = "discard";
            array_push(_player.discard, _card);
            array_push(
                game_state.event_log,
                _player.name + " discarded " + _card.definition.name
                    + " during a hand refresh."
            );
            _discarded += 1;
        }
        var _draw_count = max(0, 5 - array_length(_player.hand));
        draw_from_deck(_player, _draw_count);
        var _refresh_draw_time = current_time + 620;
        for (var _refresh_draw_index = max(
                 0,
                 array_length(_player.hand) - _draw_count
             );
             _refresh_draw_index < array_length(_player.hand);
             _refresh_draw_index++) {
            var _refresh_draw_card = _player.hand[_refresh_draw_index];
            _refresh_draw_card.ui_force_deck_origin = true;
            _refresh_draw_card.ui_hold_until_ms = max(
                _refresh_draw_card.ui_hold_until_ms,
                _refresh_draw_time,
                presentation_shuffle_until_ms[_player.index]
            );
            _refresh_draw_card.ui_zone = "refresh_pending_hand";
        }
        selected_hand_index = 0;
        array_push(
            game_state.event_log,
            _player.name + " refreshed " + string(_discarded)
            + " hand card(s) for 1 CP and drew "
            + string(_draw_count) + "."
        );
        if (guidance_is_local_player(_player.index)) {
            queue_first_game_guidance(
                "hand_refresh", "HAND REFRESHED",
                "Selected cards are discarded before you draw back to five cards."
            );
        }
        return true;
    };

    refresh_entire_hand = function() {
        var _player = game_state.players[game_state.active_player];
        var _all_indices = [];
        for (var _hand_index = 0;
             _hand_index < array_length(_player.hand);
             _hand_index++) {
            array_push(_all_indices, _hand_index);
        }
        return refresh_hand_cards(_all_indices);
    };

    begin_hand_refresh_choice = function() {
        if (game_state.phase != "action") {
            log_action_failure("The hand can only be refreshed during the action phase.");
            return false;
        }
        var _player = game_state.players[game_state.active_player];
        if (_player.command_points < 1) {
            log_action_failure("Need 1 CP to refresh the hand.");
            return false;
        }
        pending_choice = {
            kind: "hand_refresh",
            player_index: game_state.active_player,
            selected_indices: [],
            prompt: "Choose any hand cards to discard, then confirm to draw to five."
        };
        ui_selected_kind = "";
        ui_selected_index = -1;
        return true;
    };

    toggle_hand_refresh_card = function(_hand_index) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "hand_refresh"
        || pending_choice.player_index != game_state.active_player) {
            return false;
        }
        var _hand = game_state.players[
            pending_choice.player_index
        ].hand;
        if (_hand_index < 0 || _hand_index >= array_length(_hand)) {
            return false;
        }
        var _selected_position = -1;
        for (var _choice_index = 0;
             _choice_index < array_length(pending_choice.selected_indices);
             _choice_index++) {
            if (pending_choice.selected_indices[_choice_index] == _hand_index) {
                _selected_position = _choice_index;
                break;
            }
        }
        if (_selected_position >= 0) {
            array_delete(pending_choice.selected_indices, _selected_position, 1);
        } else {
            array_push(pending_choice.selected_indices, _hand_index);
        }
        return true;
    };

    confirm_hand_refresh_choice = function() {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "hand_refresh"
        || pending_choice.player_index != game_state.active_player) {
            return false;
        }
        var _player = game_state.players[pending_choice.player_index];
        if (array_length(pending_choice.selected_indices) <= 0
        && array_length(_player.hand) >= 5) {
            log_action_failure("Select at least one hand card to refresh.");
            return false;
        }
        var _indices = pending_choice.selected_indices;
        pending_choice = undefined;
        ui_selected_kind = "";
        ui_selected_index = -1;
        return refresh_hand_cards(_indices);
    };

    refresh_shop_action = function() {
        if (game_state.phase != "action") {
            log_action_failure("The Shop can only be refreshed during the action phase.");
            return false;
        }
        var _player = game_state.players[game_state.active_player];
        if (_player.command_points < 1) {
            log_action_failure("Need 1 CP to refresh the Shop.");
            return false;
        }

        _player.command_points -= 1;
        var _shop_refresh_visual_until = current_time + 700;
        if (game_state.game_mode != "batch") {
            for (var _shop_refresh_visual_index = 0;
                 _shop_refresh_visual_index < array_length(game_state.shop_row);
                 _shop_refresh_visual_index++) {
                var _shop_refresh_visual_card = game_state.shop_row[
                    _shop_refresh_visual_index
                ];
                array_push(presentation_card_transits, {
                    card: _shop_refresh_visual_card,
                    player_index: -1,
                    kind: "shop_refresh_out",
                    start_x: _shop_refresh_visual_card.ui_x,
                    start_y: _shop_refresh_visual_card.ui_y,
                    started_at_ms: current_time,
                    duration_ms: 300
                });
            }
        }
        while (array_length(game_state.shop_row) > 0) {
            var _card = array_pop(game_state.shop_row);
            _card.zone = "shop_discard";
            array_push(game_state.shop_discard, _card);
            array_push(
                game_state.event_log,
                _card.definition.name + " was discarded from the Shop during refresh."
            );
        }
        refill_shop();
        if (game_state.game_mode != "batch") {
            for (var _shop_refresh_refill_index = 0;
                 _shop_refresh_refill_index < array_length(game_state.shop_row);
                 _shop_refresh_refill_index++) {
                var _shop_refresh_new_card = game_state.shop_row[
                    _shop_refresh_refill_index
                ];
                _shop_refresh_new_card.ui_force_shop_origin = true;
                _shop_refresh_new_card.ui_hold_until_ms = max(
                    _shop_refresh_new_card.ui_hold_until_ms,
                    _shop_refresh_visual_until
                        + (_shop_refresh_refill_index * 55)
                );
            }
        }
        selected_shop_index = 0;
        array_push(
            game_state.event_log,
            _player.name + " refreshed the Shop for 1 CP."
        );
        if (guidance_is_local_player(_player.index)) {
            queue_first_game_guidance(
                "shop_refresh", "SHOP REFRESHED",
                "Refreshing the Shop discards every current offer and replaces all five cards."
            );
        }
        return true;
    };

    get_capture_cost = function(_player) {
        var _cost = 1 - min(_player.next_capture_discount, 1);
        for (var _gray_index = 0;
             _gray_index < array_length(_player.board.characters);
             _gray_index++) {
            var _gray_voice = _player.board.characters[_gray_index];
            if (_gray_voice.ready
            && _gray_voice.definition_id == "loc.gray_voice") {
                _cost -= 1;
            }
        }
        return max(0, _cost);
    };

    capture_metroid_action = function(_ship_index, _source_index) {
        if (game_state.phase != "action") {
            log_action_failure("Metroids can only be captured during the action phase.");
            return false;
        }

        var _player = game_state.players[game_state.active_player];
        if (_ship_index < 0
        || _ship_index >= array_length(_player.board.ships)) {
            log_action_failure("Select a Ship before capturing.");
            return false;
        }

        var _ship = _player.board.ships[_ship_index];
        if (!_ship.ready) {
            log_action_failure(_ship.definition.name + " is exhausted.");
            return false;
        }

        var _capacity = 1;
        if (array_length(_ship.cargo) >= _capacity) {
            log_action_failure(_ship.definition.name + " is already at capacity.");
            return false;
        }

        var _metroid = undefined;
        var _from_cavern = _source_index == 4;
        if (_from_cavern) {
            if (array_length(game_state.cavern) <= 0) {
                log_action_failure("The cavern contains no Omega Metroids.");
                return false;
            }
            _metroid = game_state.cavern[array_length(game_state.cavern) - 1];
        } else {
            if (_source_index < 0 || _source_index >= 4) {
                log_action_failure("Select a valid SR388 slot.");
                return false;
            }
            _metroid = game_state.sr388[_source_index];
            if (is_undefined(_metroid)) {
                log_action_failure(
                    "SR388 slot " + string(_source_index + 1) + " is empty."
                );
                return false;
            }
        }

        var _security = get_card_stat(_ship);
        if (_metroid.definition.hazard > _security) {
            log_action_failure(
                _ship.definition.name + " has " + string(_security)
                + " Security but " + _metroid.definition.name + " has "
                + string(_metroid.definition.hazard) + " Hazard."
            );
            return false;
        }

        var _discount = min(_player.next_capture_discount, 1);
        var _cost = get_capture_cost(_player);
        if (_player.command_points < _cost) {
            log_action_failure(
                "Need " + string(_cost) + " CP to capture "
                + _metroid.definition.name + "."
            );
            return false;
        }

        _player.command_points -= _cost;
        if (_discount > 0) {
            _player.next_capture_discount = 0;
        }
        if (_ship.definition_id != "loc.frigate_orpheon") {
            _ship.ready = false;
            if (card_discards_from_phazon(_ship)) {
                var _corrupted_capture_ship = _ship.definition.name;
                remove_ability_source(
                    "ship",
                    _ship_index,
                    _ship,
                    false
                );
                array_push(
                    game_state.event_log,
                    _corrupted_capture_ship
                    + " was discarded after exhausting to capture; "
                    + "the Metroid remained on SR388."
                );
                return true;
            }
        }

        var _capture_cargo_index = array_length(_ship.cargo);
        if (game_state.game_mode != "batch"
        && _metroid.ui_position_initialized) {
            var _capture_transit_duration = 620;
            array_push(presentation_card_transits, {
                card: _metroid,
                player_index: _player.index,
                kind: "metroid_to_ship",
                target_ship: _ship,
                cargo_index: _capture_cargo_index,
                start_x: _metroid.ui_x,
                start_y: _metroid.ui_y,
                started_at_ms: current_time,
                duration_ms: _capture_transit_duration
            });
            _metroid.ui_cargo_arrival_ms =
                current_time + _capture_transit_duration;
            presentation_capture_until_ms = max(
                presentation_capture_until_ms,
                _metroid.ui_cargo_arrival_ms
            );
        }

        if (_from_cavern) {
            array_pop(game_state.cavern);
        } else {
            game_state.sr388[_source_index] = undefined;
        }

        _metroid.zone = "ship";
        _metroid.host_ship_instance_id = _ship.instance_id;
        array_push(_ship.cargo, _metroid);
        if (_ship.definition_id == "loc.gunship") {
            _player.command_points += 1;
            telemetry_update_max_cp(_player);
            array_push(
                game_state.event_log,
                "Gunship generated 1 CP from its capture."
            );
        }
        array_push(
            game_state.event_log,
            _player.name + " captured " + _metroid.definition.name
            + " with " + _ship.definition.name + " for "
            + string(_cost) + " CP."
        );
        _player.telemetry.captures += 1;
        telemetry_update_max_cp(_player);
        return true;
    };

    can_capture_metroid = function(_ship_index, _source_index) {
        if (game_state.phase != "action") {
            return false;
        }

        var _player = game_state.players[game_state.active_player];
        if (_ship_index < 0
        || _ship_index >= array_length(_player.board.ships)) {
            return false;
        }

        var _ship = _player.board.ships[_ship_index];
        if (!_ship.ready || array_length(_ship.cargo) >= 1) {
            return false;
        }

        var _metroid = undefined;
        if (_source_index == 4) {
            if (array_length(game_state.cavern) <= 0) {
                return false;
            }
            _metroid = game_state.cavern[array_length(game_state.cavern) - 1];
        } else {
            if (_source_index < 0 || _source_index >= 4) {
                return false;
            }
            _metroid = game_state.sr388[_source_index];
            if (is_undefined(_metroid)) {
                return false;
            }
        }

        var _cost = get_capture_cost(_player);
        return _player.command_points >= _cost
            && _metroid.definition.hazard <= get_card_stat(_ship);
    };

    get_sr388_metroid_for_choice = function(_source_index) {
        if (_source_index == 4) {
            if (array_length(game_state.cavern) > 0) {
                return game_state.cavern[array_length(game_state.cavern) - 1];
            }
            return undefined;
        }
        if (_source_index >= 0 && _source_index < 4) {
            return game_state.sr388[_source_index];
        }
        return undefined;
    };

    quiet_robe_pair_exists = function(_ship) {
        if (is_undefined(_ship)) {
            return false;
        }
        var _security = get_card_stat(_ship);
        for (var _first_source = 0; _first_source < 5; _first_source++) {
            var _first_metroid = get_sr388_metroid_for_choice(_first_source);
            if (is_undefined(_first_metroid)) {
                continue;
            }
            for (var _second_source = 0;
                 _second_source < 5;
                 _second_source++) {
                if (_first_source < 4 && _second_source == _first_source) {
                    continue;
                }
                var _second_metroid;
                if (_first_source == 4 && _second_source == 4) {
                    var _cavern_count = array_length(game_state.cavern);
                    _second_metroid = _cavern_count >= 2
                        ? game_state.cavern[_cavern_count - 2]
                        : undefined;
                } else {
                    _second_metroid =
                        get_sr388_metroid_for_choice(_second_source);
                }
                if (!is_undefined(_second_metroid)
                && _first_metroid.definition.hazard
                    + _second_metroid.definition.hazard <= _security) {
                    return true;
                }
            }
        }
        return false;
    };

    can_select_quiet_robe_metroid = function(_source_index) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "quiet_robe_metroids") {
            return false;
        }
        var _metroid = get_sr388_metroid_for_choice(_source_index);
        if (is_undefined(_metroid)) {
            return false;
        }
        var _security = get_card_stat(pending_choice.ship);
        var _new_hazard = pending_choice.selected_hazard
            + _metroid.definition.hazard;
        if (_new_hazard > _security) {
            return false;
        }
        if (pending_choice.remaining <= 1) {
            return true;
        }

        for (var _follow_index = 0; _follow_index < 5; _follow_index++) {
            if (_follow_index == _source_index && _source_index < 4) {
                continue;
            }
            if (_follow_index == 4 && _source_index == 4
            && array_length(game_state.cavern) < 2) {
                continue;
            }
            var _follow_metroid;
            if (_source_index == 4 && _follow_index == 4) {
                var _cavern_count = array_length(game_state.cavern);
                _follow_metroid = _cavern_count >= 2
                    ? game_state.cavern[_cavern_count - 2]
                    : undefined;
            } else {
                _follow_metroid = get_sr388_metroid_for_choice(_follow_index);
            }
            if (!is_undefined(_follow_metroid)
            && _new_hazard + _follow_metroid.definition.hazard <= _security) {
                return true;
            }
        }
        return false;
    };

    resolve_quiet_robe_metroid_choice = function(_source_index) {
        if (!can_select_quiet_robe_metroid(_source_index)) {
            return false;
        }
        var _choice = pending_choice;
        var _metroid = get_sr388_metroid_for_choice(_source_index);
        if (_source_index == 4) {
            array_pop(game_state.cavern);
        } else {
            game_state.sr388[_source_index] = undefined;
        }
        _metroid.zone = "ship";
        _metroid.host_ship_instance_id = _choice.ship.instance_id;
        array_push(_choice.ship.cargo, _metroid);
        _choice.selected_hazard += _metroid.definition.hazard;
        _choice.remaining -= 1;
        array_push(
            game_state.event_log,
            "Quiet Robe placed " + _metroid.definition.name + " on "
            + _choice.ship.definition.name + " without exhausting the Ship."
        );
        if (_choice.remaining <= 0) {
            pending_choice = undefined;
            ui_selected_kind = "";
            ui_selected_index = -1;
        } else {
            _choice.prompt = "Quiet Robe: select one more Metroid. "
                + string(_choice.selected_hazard) + "/"
                + string(get_card_stat(_choice.ship)) + " Hazard selected.";
        }
        return true;
    };

    begin_capture_choice = function(_ship_index) {
        var _player = game_state.players[game_state.active_player];
        if (_ship_index < 0
        || _ship_index >= array_length(_player.board.ships)) {
            log_action_failure("Select a Ship before capturing.");
            return false;
        }
        if (!_player.board.ships[_ship_index].ready) {
            log_action_failure("The selected Ship is exhausted.");
            return false;
        }
        if (array_length(_player.board.ships[_ship_index].cargo) >= 1) {
            log_action_failure("The selected Ship is already at capacity.");
            return false;
        }

        pending_choice = {
            kind: "capture_metroid",
            ship_index: _ship_index,
            prompt: "Select a legal Metroid on SR388 or in the cavern."
        };
        array_push(
            game_state.event_log,
            "Capture target requested for "
            + _player.board.ships[_ship_index].definition.name + "."
        );
        if (guidance_is_local_player(_player.index)) {
            queue_first_game_guidance(
                "capture", "CAPTURE",
                "Select a Metroid whose Hazard is lower than or equal to this Ship's Security. The Ship exhausts and carries the captured Metroid until your next turn."
            );
        }
        return true;
    };

}

