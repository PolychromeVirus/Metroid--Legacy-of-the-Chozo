function loc_raids() {
    gf_soldier_breach_sequence = undefined;
    raid_array_contains = function(_array, _value) {
        for (var _index = 0; _index < array_length(_array); _index++) {
            if (_array[_index] == _value) {
                return true;
            }
        }
        return false;
    };

    raid_find_instance_index = function(_cards, _instance_id) {
        for (var _card_index = 0;
             _card_index < array_length(_cards);
             _card_index++) {
            if (_cards[_card_index].instance_id == _instance_id) return _card_index;
        }
        return -1;
    };

    raid_get_ship = function(_player, _instance_id) {
        var _ship_index = raid_find_instance_index(
            _player.board.ships, _instance_id
        );
        return _ship_index >= 0 ? _player.board.ships[_ship_index] : undefined;
    };

    raid_validate_participants = function(_raid) {
        if (is_undefined(_raid) || _raid.kind != "raid") return true;
        if (_raid.stage == "attacker_ship") {
            var _declared_defender_exists = !is_undefined(raid_get_ship(
                game_state.players[1 - game_state.active_player],
                _raid.defender_ship_id
            ));
            if (_declared_defender_exists) return true;
            array_push(
                game_state.event_log,
                "The declared raid ended because its defending Vehicle left play."
            );
            pending_choice = undefined;
            return false;
        }
        var _attacker_exists = !is_undefined(raid_get_ship(
            game_state.players[game_state.active_player],
            _raid.attacker_ship_id
        ));
        var _defender_exists = _raid.defender_ship_id < 0
            || !is_undefined(raid_get_ship(
                game_state.players[1 - game_state.active_player],
                _raid.defender_ship_id
            ));
        if (_attacker_exists && _defender_exists) return true;
        var _missing_side = !_attacker_exists
            ? "attacking" : "defending";
        array_push(
            game_state.event_log,
            "The raid ended because its " + _missing_side
                + " Vehicle left play."
        );
        if (pending_choice == _raid) pending_choice = undefined;
        if (raid_suspended_choice == _raid) raid_suspended_choice = undefined;
        game_state.priority_player = game_state.active_player;
        ui_selected_kind = "";
        ui_selected_index = -1;
        return false;
    };

    raid_toggle_character = function(_character_index, _defending) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "raid") {
            return false;
        }
        var _expected_stage = _defending ? "defenders" : "attackers";
        if (pending_choice.stage != _expected_stage) {
            return false;
        }

        var _player_index = _defending
            ? 1 - game_state.active_player
            : game_state.active_player;
        var _characters = game_state.players[_player_index].board.characters;
        if (_character_index < 0
        || _character_index >= array_length(_characters)
        || !_characters[_character_index].ready) {
            return false;
        }

        var _selected = _defending
            ? pending_choice.defender_characters
            : pending_choice.attacker_characters;
        var _character_id = _characters[_character_index].instance_id;
        for (var _selected_index = 0;
             _selected_index < array_length(_selected);
             _selected_index++) {
            if (_selected[_selected_index] == _character_id) {
                array_delete(_selected, _selected_index, 1);
                return true;
            }
        }
        array_push(_selected, _character_id);
        return true;
    };

    get_raid_cost = function(_player, _defender_ship) {
        if (is_undefined(_defender_ship)) return 100000;
        var _cost = get_card_stat(_defender_ship, "raid_defender_ship");
        if (array_length(_defender_ship.cargo) > 0) {
            _cost = 0;
            for (var _cargo_index = 0;
                 _cargo_index < array_length(_defender_ship.cargo);
                 _cargo_index++) {
                _cost = max(
                    _cost,
                    _defender_ship.cargo[_cargo_index].definition.hazard
                );
            }
        }
        for (var _character_index = 0;
             _character_index < array_length(_player.board.characters);
             _character_index++) {
            var _character = _player.board.characters[_character_index];
            if (_character.ready
            && _character.definition_id == "loc.chozo_warrior") {
                _cost -= 1;
            }
        }
        return max(0, _cost);
    };

    begin_raid_target_choice = function(_defender_ship_index) {
        if (game_state.phase != "action") return false;
        var _attacker_player = game_state.players[game_state.active_player];
        var _defender_player = game_state.players[1 - game_state.active_player];
        if (_defender_ship_index < 0
        || _defender_ship_index >= array_length(_defender_player.board.ships)) {
            return false;
        }
        var _defender_ship = _defender_player.board.ships[
            _defender_ship_index
        ];
        var _raid_cost = get_raid_cost(_attacker_player, _defender_ship);
        if (_attacker_player.command_points < _raid_cost) {
            log_action_failure(
                "Need " + string(_raid_cost) + " CP to raid "
                + _defender_ship.definition.name + "."
            );
            return false;
        }
        var _has_ready_attacker = false;
        for (var _ship_index = 0;
             _ship_index < array_length(_attacker_player.board.ships);
             _ship_index++) {
            if (_attacker_player.board.ships[_ship_index].ready) {
                _has_ready_attacker = true;
                break;
            }
        }
        if (!_has_ready_attacker) {
            log_action_failure("No ready Ship can initiate this raid.");
            return false;
        }
        pending_choice = {
            kind: "raid",
            stage: "attacker_ship",
            defender_ship_id: _defender_ship.instance_id,
            raid_cost: _raid_cost,
            prompt: "Select one of your ready Ships to initiate the raid."
        };
        return true;
    };

    select_raid_attacker = function(_attacker_index) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "raid"
        || pending_choice.stage != "attacker_ship") return false;
        var _attacker_player = game_state.players[game_state.active_player];
        var _defender_player = game_state.players[1 - game_state.active_player];
        if (_attacker_index < 0
        || _attacker_index >= array_length(_attacker_player.board.ships)
        || !_attacker_player.board.ships[_attacker_index].ready) {
            log_action_failure("Select one of your ready Ships to raid.");
            return false;
        }
        var _defender_ship_id = pending_choice.defender_ship_id;
        var _defender_index = raid_find_instance_index(
            _defender_player.board.ships,
            _defender_ship_id
        );
        if (_defender_index < 0) {
            pending_choice = undefined;
            log_action_failure("The targeted Ship is no longer in play.");
            return false;
        }
        pending_choice = undefined;
        if (!begin_raid_choice(_attacker_index)) return false;
        return select_raid_target(_defender_index);
    };

    begin_raid_choice = function(_attacker_index) {
        if (game_state.phase != "action") {
            return false;
        }
        var _attacker_player = game_state.players[game_state.active_player];
        var _defender_player = game_state.players[1 - game_state.active_player];
        if (_attacker_index < 0
        || _attacker_index >= array_length(_attacker_player.board.ships)
        || !_attacker_player.board.ships[_attacker_index].ready) {
            log_action_failure("Select one of your ready Ships to raid.");
            return false;
        }
        if (array_length(_defender_player.board.ships) <= 0) {
            log_action_failure("Your opponent has no Ship to raid.");
            return false;
        }
        var _has_affordable_target = false;
        for (var _target_index = 0;
             _target_index < array_length(_defender_player.board.ships);
             _target_index++) {
            if (_attacker_player.command_points >= get_raid_cost(
                _attacker_player,
                _defender_player.board.ships[_target_index]
            )) {
                _has_affordable_target = true;
                break;
            }
        }
        if (!_has_affordable_target) {
            log_action_failure("You cannot afford to raid any opposing Ship.");
            return false;
        }

        pending_choice = {
            kind: "raid",
            stage: "target",
            attacker_ship_id: _attacker_player.board.ships[
                _attacker_index
            ].instance_id,
            defender_ship_id: -1,
            attacker_characters: [],
            defender_characters: [],
            attacker_ability_bonus: 0,
            defender_ability_bonus: 0,
            interaction_mode: "abilities",
            ability_source_kind: "",
            ability_source_index: -1,
            ability_index: -1,
            raid_cost: -1,
            prompt: "Select an opposing Ship to raid."
        };
        if (guidance_is_local_player(game_state.active_player)) {
            queue_first_game_guidance(
                "raid_attacker", "RAID",
                "The attacking Ship begins with its Strength. Both players may exhaust Characters to contribute Strength; the attacker commits first."
            );
        }
        return true;
    };

    select_raid_target = function(_defender_ship_index) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "raid"
        || pending_choice.stage != "target") {
            return false;
        }
        var _attacker_player = game_state.players[game_state.active_player];
        var _defender_player = game_state.players[1 - game_state.active_player];
        if (_defender_ship_index < 0
        || _defender_ship_index >= array_length(_defender_player.board.ships)) {
            return false;
        }
        var _defender_ship = _defender_player.board.ships[
            _defender_ship_index
        ];
        var _raid_cost = get_raid_cost(_attacker_player, _defender_ship);
        if (_attacker_player.command_points < _raid_cost) {
            log_action_failure(
                "Need " + string(_raid_cost) + " CP to raid "
                + _defender_ship.definition.name + "."
            );
            return false;
        }
        pending_choice.raid_cost = _raid_cost;

        var _attacker_index = raid_find_instance_index(
            _attacker_player.board.ships,
            pending_choice.attacker_ship_id
        );
        if (_attacker_index < 0) {
            array_push(game_state.event_log,
                "The raid ended because its attacking Vehicle left play.");
            pending_choice = undefined;
            return false;
        }
        var _attacker = _attacker_player.board.ships[_attacker_index];
        _attacker_player.command_points -= pending_choice.raid_cost;
        _attacker_player.telemetry.raids_started += 1;
        _attacker.ready = false;
        if (card_discards_from_phazon(_attacker)) {
            var _corrupted_attacker_name = _attacker.definition.name;
            raid_discard_ship(
                _attacker_player,
                _attacker_index,
                undefined
            );
            pending_choice = undefined;
            array_push(
                game_state.event_log,
                _corrupted_attacker_name
                + " was discarded after exhausting while corrupted; "
                + "the raid ended without resolving."
            );
            return true;
        }
        pending_choice.defender_ship_id = _defender_player.board.ships[
            _defender_ship_index
        ].instance_id;
        pending_choice.stage = "attackers";
        pending_choice.interaction_mode = "abilities";
        pending_choice.prompt =
            "Use abilities or contribute ready Characters, then lock attackers.";
        array_push(
            game_state.event_log,
            _attacker.definition.name + " initiated a raid against "
            + _defender_player.board.ships[
                _defender_ship_index
            ].definition.name + " for "
            + string(pending_choice.raid_cost) + " CP."
        );
        return true;
    };

    lock_raid_attackers = function() {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "raid"
        || pending_choice.stage != "attackers") {
            return false;
        }
        if (!raid_validate_participants(pending_choice)) return false;
        pending_choice.stage = "defenders";
        pending_choice.interaction_mode = "abilities";
        pending_choice.ability_source_kind = "";
        pending_choice.ability_source_index = -1;
        pending_choice.ability_index = -1;
        game_state.priority_player = 1 - game_state.active_player;
        pending_choice.prompt =
            "Use abilities or contribute ready Characters, then resolve the raid.";
        if (guidance_is_local_player(1 - game_state.active_player)) {
            queue_first_game_guidance(
                "raid_defender", "DEFENDING A RAID",
                "You are being raided. The numbers on the sidebar show how much Strength they are attacking with. You may now commit your Characters or activate abilities to defend against the Raid. Click RESOLVE RAID when you are done. The loser's Ship is destroyed, and the winner takes any Metroids it carried if their available space and Security allow."
            );
        }
        return true;
    };

    toggle_raid_ability_mode = function() {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "raid"
        || (pending_choice.stage != "attackers"
        && pending_choice.stage != "defenders")) {
            return false;
        }
        pending_choice.interaction_mode =
            pending_choice.interaction_mode == "abilities"
                ? "contributors"
                : "abilities";
        pending_choice.ability_source_kind = "";
        pending_choice.ability_source_index = -1;
        pending_choice.ability_index = -1;
        return true;
    };

    select_raid_ability_source = function(_source_kind, _source_index) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "raid"
        || (pending_choice.stage != "attackers"
            && pending_choice.stage != "defenders")) {
            return false;
        }
        var _source = get_ability_source(_source_kind, _source_index);
        if (is_undefined(_source)
        || _source.controller != game_state.priority_player) {
            return false;
        }
        pending_choice.ability_source_kind = _source_kind;
        pending_choice.ability_source_index = _source_index;
        var _legal_indices = get_raid_ability_indices(_source);
        pending_choice.ability_index = array_length(_legal_indices) == 1
            ? _legal_indices[0]
            : -1;
        ui_selected_kind = _source_kind;
        ui_selected_index = _source_index;
        ui_selected_instance_id = _source.instance_id;
        return true;
    };

    get_raid_ability_indices = function(_card) {
        var _legal_indices = [];
        var _abilities = get_activated_abilities(_card);
        for (var _raid_ability_index = 0;
             _raid_ability_index < array_length(_abilities);
             _raid_ability_index++) {
            var _raid_ability = _abilities[_raid_ability_index];
            var _raid_context_legal = true;
            if (_raid_ability.effect_kind == "raid_defense_1") {
                _raid_context_legal = !is_undefined(pending_choice)
                    && pending_choice.kind == "raid"
                    && pending_choice.stage == "defenders";
            } else if (_raid_ability.effect_kind == "tyr_raid_support") {
                var _tyr_raid_target = !is_undefined(pending_choice)
                    && pending_choice.kind == "raid"
                    && pending_choice.stage == "defenders"
                    ? raid_get_ship(
                        game_state.players[_card.controller],
                        pending_choice.defender_ship_id
                    )
                    : undefined;
                _raid_context_legal = !is_undefined(_tyr_raid_target)
                    && _tyr_raid_target.instance_id != _card.instance_id;
            }
            if (_raid_context_legal
            && (!_raid_ability.cost_exhaust || _card.ready)
            && game_state.players[_card.controller].command_points
                >= _raid_ability.cost_cp) {
                array_push(_legal_indices, _raid_ability_index);
            }
        }
        return _legal_indices;
    };

    get_raid_ability_index = function(_card) {
        var _legal_indices = get_raid_ability_indices(_card);
        if (!is_undefined(pending_choice)
        && pending_choice.kind == "raid"
        && variable_struct_exists(pending_choice, "ability_index")
        && pending_choice.ability_index >= 0) {
            for (var _selected_legal_index = 0;
                 _selected_legal_index < array_length(_legal_indices);
                 _selected_legal_index++) {
                if (_legal_indices[_selected_legal_index]
                == pending_choice.ability_index) {
                    return pending_choice.ability_index;
                }
            }
        }
        return array_length(_legal_indices) == 1 ? _legal_indices[0] : -1;
    };

    card_has_raid_ability = function(_card) {
        return array_length(get_raid_ability_indices(_card)) > 0;
    };

    activate_raid_ability_index = function(
        _ability_index,
        _source_kind,
        _source_index
    ) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "raid") {
            return false;
        }
        if (argument_count >= 3) {
            select_raid_ability_source(_source_kind, _source_index);
        }
        pending_choice.ability_index = _ability_index;
        return activate_raid_selected_ability();
    };

    can_activate_raid_ability = function() {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "raid"
        || (pending_choice.stage != "attackers"
            && pending_choice.stage != "defenders")) {
            return false;
        }
        var _source = get_ability_source(
            pending_choice.ability_source_kind,
            pending_choice.ability_source_index
        );
        if (is_undefined(_source)
        || _source.controller != game_state.priority_player) {
            return false;
        }
        var _abilities = get_activated_abilities(_source);
        var _raid_ability_index = get_raid_ability_index(_source);
        if (_raid_ability_index < 0) {
            return false;
        }
        var _ability = _abilities[_raid_ability_index];
        if (_ability.cost_exhaust && !_source.ready) {
            return false;
        }
        if (game_state.players[_source.controller].command_points
        < _ability.cost_cp) {
            return false;
        }
        return card_has_raid_ability(_source);
    };

    activate_raid_selected_ability = function() {
        if (!can_activate_raid_ability()) {
            log_action_failure("That ability cannot be used during this raid.");
            return false;
        }
        var _raid = pending_choice;
        var _source = get_ability_source(
            _raid.ability_source_kind,
            _raid.ability_source_index
        );
        var _raid_abilities = get_activated_abilities(_source);
        var _raid_ability_index = get_raid_ability_index(_source);
        var _ability = _raid_abilities[_raid_ability_index];
        if (!can_activate_selected_ability(
            _raid.ability_source_kind,
            _raid.ability_source_index,
            _raid_ability_index
        )) {
            log_action_failure("That ability cannot be used during this raid.");
            return false;
        }
        raid_suspended_choice = _raid;
        var _resolved = activate_selected_ability(
            _raid.ability_source_kind,
            _raid.ability_source_index,
            _raid_ability_index
        );
        if (pending_choice == _raid) raid_validate_participants(_raid);
        if (pending_choice == _raid) raid_suspended_choice = undefined;
        _raid.ability_source_kind = "";
        _raid.ability_source_index = -1;
        _raid.ability_index = -1;
        return _resolved;
    };

    raid_character_contribution = function(_character, _defending_ship) {
        var _contribution = get_card_stat(_character, "raid_character");
        if (!is_undefined(_defending_ship)
        && _defending_ship.definition_id == "loc.g_f_s_olympus"
        && card_has_faction(_character, "GF")) {
            _contribution += 1;
        }
        return _contribution;
    };

    raid_tyr_support_potential = function(_player, _defending_ship) {
        if (is_undefined(_defending_ship)) return 0;
        var _support_value = card_has_faction(_defending_ship, "GF") ? 2 : 1;
        var _support_total = 0;
        for (var _ship_index = 0;
             _ship_index < array_length(_player.board.ships);
             _ship_index++) {
            var _ship = _player.board.ships[_ship_index];
            if (_ship.definition_id == "loc.g_f_s_tyr"
            && _ship.instance_id != _defending_ship.instance_id
            && _ship.ready) {
                _support_total += _support_value;
            }
        }
        return _support_total;
    };

    raid_exhaust_characters = function(_player, _selected, _defending_ship) {
        var _strength = 0;
        var _olympus_bonus = 0;
        for (var _selection_index = 0;
             _selection_index < array_length(_selected);
             _selection_index++) {
            var _character_index = raid_find_instance_index(
                _player.board.characters,
                _selected[_selection_index]
            );
            if (_character_index >= 0) {
                var _character = _player.board.characters[_character_index];
                if (_character.ready) {
                    var _base_contribution = get_card_stat(
                        _character, "raid_character"
                    );
                    var _character_contribution = raid_character_contribution(
                        _character, _defending_ship
                    );
                    _strength += _character_contribution;
                    _olympus_bonus += _character_contribution
                        - _base_contribution;
                    _character.ready = false;
                }
            }
        }

        if (_olympus_bonus > 0) {
            array_push(
                game_state.event_log,
                "G.F.S. Olympus added +" + string(_olympus_bonus)
                    + " Strength from Galactic Federation defenders."
            );
        }

        for (var _board_index = array_length(_player.board.characters) - 1;
             _board_index >= 0;
             _board_index--) {
            if (raid_array_contains(
                _selected,
                _player.board.characters[_board_index].instance_id
            )
            && card_discards_from_phazon(
                _player.board.characters[_board_index]
            )) {
                var _corrupted = _player.board.characters[_board_index];
                array_delete(_player.board.characters, _board_index, 1);
                clear_card_board_state(_corrupted);
                _corrupted.zone = "discard";
                array_push(_player.discard, _corrupted);
                array_push(
                    game_state.event_log,
                    _corrupted.definition.name
                    + " was discarded after contributing while corrupted."
                );
            }
        }
        return _strength;
    };

    raid_discard_ship = function(_player, _ship_index, _cargo_destination) {
        var _ship = _player.board.ships[_ship_index];
        while (array_length(_ship.cargo) > 0) {
            var _cargo = _ship.cargo[0];
            array_delete(_ship.cargo, 0, 1);
            if (!is_undefined(_cargo_destination)
            && array_length(_cargo_destination.cargo) < 1) {
                _cargo.zone = "ship";
                _cargo.host_ship_instance_id = _cargo_destination.instance_id;
                array_push(_cargo_destination.cargo, _cargo);
            } else {
                _cargo.zone = "supply";
                _cargo.host_ship_instance_id = -1;
            }
        }
        while (array_length(_ship.attachments) > 0) {
            var _attachment = _ship.attachments[0];
            array_delete(_ship.attachments, 0, 1);
            clear_card_board_state(_attachment);
            _attachment.zone = "discard";
            array_push(
                game_state.players[_attachment.owner].discard,
                _attachment
            );
            array_push(
                game_state.event_log,
                _attachment.definition.name
                    + " was discarded because its raided host left play."
            );
        }
        array_delete(_player.board.ships, _ship_index, 1);
        clear_card_board_state(_ship);
        _ship.zone = "discard";
        array_push(_player.discard, _ship);
        array_push(
            game_state.event_log,
            _ship.definition.name + " was discarded after being destroyed in a raid."
        );
        return _ship;
    };

    find_lowest_stage_breaching_metroid = function(_player) {
        for (var _hunter_index = 0;
             _hunter_index < array_length(_player.lab);
             _hunter_index++) {
            if (_player.lab[_hunter_index].definition_id == "metroid.hunter") {
                return _hunter_index;
            }
        }
        var _lowest_index = -1;
        var _lowest_stage = 100000;
        for (var _metroid_index = 0;
             _metroid_index < array_length(_player.lab);
             _metroid_index++) {
            var _stage = _player.lab[_metroid_index].definition.stage;
            if (is_real(_stage) && _stage < _lowest_stage) {
                _lowest_stage = _stage;
                _lowest_index = _metroid_index;
            }
        }
        return _lowest_index;
    };

    continue_gf_soldier_breaches = function() {
        if (is_undefined(gf_soldier_breach_sequence)) return false;
        var _sequence = gf_soldier_breach_sequence;
        while (_sequence.index < array_length(_sequence.entries)
        && (_sequence.entries[_sequence.index].remaining <= 0
            || array_length(game_state.players[
                _sequence.entries[_sequence.index].player_index
            ].lab) <= 0)) {
            _sequence.index += 1;
        }
        if (_sequence.index >= array_length(_sequence.entries)) {
            gf_soldier_breach_sequence = undefined;
            pending_choice = undefined;
            game_state.priority_player = game_state.active_player;
            ui_selected_kind = "";
            ui_selected_index = -1;
            return true;
        }
        var _entry = _sequence.entries[_sequence.index];
        var _player = game_state.players[_entry.player_index];
        var _breach_index = find_lowest_stage_breaching_metroid(_player);
        if (_breach_index < 0) {
            _entry.remaining = 0;
            return continue_gf_soldier_breaches();
        }
        _entry.remaining -= 1;
        if (!resolve_metroid_breach(_player, _breach_index, true)) {
            return continue_gf_soldier_breaches();
        }
        if (array_length(_player.board.characters) <= 0) {
            release_breach_presentation(presentation_last_breach_instance_id);
            return continue_gf_soldier_breaches();
        }
        game_state.priority_player = _entry.player_index;
        pending_choice = {
            kind: "breach_character",
            player_index: _entry.player_index,
            breach_instance_id: presentation_last_breach_instance_id,
            gf_soldier_breach: true,
            prompt: _player.name
                + ": choose a Character to discard for GF Soldier's breach."
        };
        return true;
    };

    resolve_gf_soldier_breach_character = function(_character_index) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "breach_character"
        || !variable_struct_exists(pending_choice, "gf_soldier_breach")
        || !pending_choice.gf_soldier_breach
        || is_undefined(gf_soldier_breach_sequence)) return false;
        var _player = game_state.players[pending_choice.player_index];
        if (_character_index < 0
        || _character_index >= array_length(_player.board.characters)) {
            return false;
        }
        var _character = _player.board.characters[_character_index];
        array_delete(_player.board.characters, _character_index, 1);
        clear_card_board_state(_character);
        _character.zone = "discard";
        array_push(_player.discard, _character);
        array_push(
            game_state.event_log,
            _player.name + " discarded " + _character.definition.name
                + " for GF Soldier's forced breach."
        );
        release_breach_presentation(pending_choice.breach_instance_id);
        pending_choice = undefined;
        return continue_gf_soldier_breaches();
    };

    trigger_gf_soldier_ship_destructions = function(_destroyed_players) {
        var _entries = [];
        for (var _destroyed_index = 0;
             _destroyed_index < array_length(_destroyed_players);
             _destroyed_index++) {
            var _owner_index = _destroyed_players[_destroyed_index];
            var _owner = game_state.players[_owner_index];
            var _opponent_index = 1 - _owner_index;
            var _opponent = game_state.players[_opponent_index];
            var _breach_count = 0;
            for (var _soldier_index = array_length(_owner.board.characters) - 1;
                 _soldier_index >= 0;
                 _soldier_index--) {
                var _soldier = _owner.board.characters[_soldier_index];
                if (_soldier.definition_id != "loc.gf_soldier"
                || !_soldier.ready) continue;
                _soldier.ready = false;
                _breach_count += 1;
                array_push(
                    game_state.event_log,
                    "GF Soldier exhausted after its controller's Ship was destroyed in a raid and forced "
                        + _opponent.name + "'s lowest-stage Metroid to breach."
                );
                if (card_discards_from_phazon(_soldier)) {
                    array_delete(_owner.board.characters, _soldier_index, 1);
                    clear_card_board_state(_soldier);
                    _soldier.zone = "discard";
                    array_push(_owner.discard, _soldier);
                    array_push(
                        game_state.event_log,
                        "GF Soldier was discarded after exhausting while corrupted."
                    );
                }
            }
            if (_breach_count > 0 && array_length(_opponent.lab) > 0) {
                array_push(_entries, {
                    player_index: _opponent_index,
                    remaining: _breach_count
                });
            }
        }
        pending_choice = undefined;
        if (array_length(_entries) <= 0) {
            game_state.priority_player = game_state.active_player;
            ui_selected_kind = "";
            ui_selected_index = -1;
            return true;
        }
        gf_soldier_breach_sequence = {entries: _entries, index: 0};
        return continue_gf_soldier_breaches();
    };

    finish_attacker_raid_win = function(_cargo_index) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "raid_cargo") {
            return false;
        }
        var _choice = pending_choice;
        var _attacker_player = game_state.players[game_state.active_player];
        var _defender_player = game_state.players[1 - game_state.active_player];
        var _winner_player = _choice.winner_is_attacker
            ? _attacker_player
            : _defender_player;
        var _loser_player = _choice.winner_is_attacker
            ? _defender_player
            : _attacker_player;
        var _winner_ship_id = _choice.winner_is_attacker
            ? _choice.attacker_ship_id
            : _choice.defender_ship_id;
        var _loser_ship_id = _choice.winner_is_attacker
            ? _choice.defender_ship_id
            : _choice.attacker_ship_id;
        var _winner_ship_index = raid_find_instance_index(
            _winner_player.board.ships, _winner_ship_id
        );
        var _loser_ship_index = raid_find_instance_index(
            _loser_player.board.ships, _loser_ship_id
        );
        if (_winner_ship_index < 0 || _loser_ship_index < 0) {
            array_push(game_state.event_log,
                "The raid ended because a participating Vehicle left play.");
            pending_choice = undefined;
            game_state.priority_player = game_state.active_player;
            return false;
        }
        var _winner = _winner_player.board.ships[_winner_ship_index];
        var _loser = _loser_player.board.ships[_loser_ship_index];
        if (_cargo_index < 0
        || _cargo_index >= array_length(_loser.cargo)
        || array_length(_winner.cargo) >= 1) {
            return false;
        }
        var _chosen_cargo = _loser.cargo[_cargo_index];
        array_delete(_loser.cargo, _cargo_index, 1);
        _chosen_cargo.zone = "ship";
        _chosen_cargo.host_ship_instance_id = _winner.instance_id;
        array_push(_winner.cargo, _chosen_cargo);
        var _lost_ship = raid_discard_ship(
            _loser_player,
            _loser_ship_index,
            undefined
        );
        array_push(
            game_state.event_log,
            "Raid " + string(_choice.attacker_total) + "-"
            + string(_choice.defender_total) + ": "
            + _lost_ship.definition.name + " was discarded; "
            + _chosen_cargo.definition.name + " was taken."
        );
        if (_choice.winner_is_attacker
        && _winner.definition_id == "loc.pirate_destroyer") {
            _winner.ready = true;
            array_push(
                game_state.event_log,
                "Pirate Destroyer readied after the successful raid."
            );
        }
        pending_choice = undefined;
        game_state.priority_player = game_state.active_player;
        ui_selected_kind = "";
        ui_selected_index = -1;
        var _destroyed_player_index = _choice.winner_is_attacker
            ? 1 - game_state.active_player
            : game_state.active_player;
        return trigger_gf_soldier_ship_destructions([
            _destroyed_player_index
        ]);
    };

    resolve_raid = function() {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "raid"
        || pending_choice.stage != "defenders") {
            return false;
        }

        var _raid = pending_choice;
        var _attacker_player = game_state.players[game_state.active_player];
        var _defender_player = game_state.players[1 - game_state.active_player];
        var _attacker_ship_index = raid_find_instance_index(
            _attacker_player.board.ships, _raid.attacker_ship_id
        );
        var _defender_ship_index = raid_find_instance_index(
            _defender_player.board.ships, _raid.defender_ship_id
        );
        if (_attacker_ship_index < 0 || _defender_ship_index < 0) {
            array_push(game_state.event_log,
                "The raid ended because a participating Vehicle left play.");
            pending_choice = undefined;
            game_state.priority_player = game_state.active_player;
            ui_selected_kind = "";
            ui_selected_index = -1;
            return false;
        }
        var _attacker = _attacker_player.board.ships[_attacker_ship_index];
        var _defender = _defender_player.board.ships[_defender_ship_index];
        var _attacker_total = get_card_stat(_attacker, "raid_attacker_ship")
            + raid_exhaust_characters(
                _attacker_player,
                _raid.attacker_characters,
                undefined
            )
            + _raid.attacker_ability_bonus;
        var _defender_total = get_card_stat(_defender, "raid_defender_ship")
            + raid_exhaust_characters(
                _defender_player,
                _raid.defender_characters,
                _defender
            )
            + _raid.defender_ability_bonus;

        var _destroyed_ship_players = [];
        if (_attacker_total > _defender_total) {
            _attacker_player.telemetry.raids_won += 1;
            _defender_player.telemetry.raids_lost += 1;
            var _raid_capacity_remaining =
                max(0, 1 - array_length(_attacker.cargo));
            if (_raid_capacity_remaining > 0
            && array_length(_defender.cargo) > _raid_capacity_remaining) {
                pending_choice = {
                    kind: "raid_cargo",
                    attacker_ship_id: _raid.attacker_ship_id,
                    defender_ship_id: _raid.defender_ship_id,
                    attacker_total: _attacker_total,
                    defender_total: _defender_total,
                    winner_is_attacker: true,
                    prompt: "Choose the Metroid taken from the losing Ship."
                };
                game_state.priority_player = game_state.active_player;
                return true;
            }
            var _lost_defender = raid_discard_ship(
                _defender_player,
                _defender_ship_index,
                _attacker
            );
            array_push(_destroyed_ship_players, 1 - game_state.active_player);
            array_push(
                game_state.event_log,
                "Raid " + string(_attacker_total) + "-"
                + string(_defender_total) + ": "
                + _lost_defender.definition.name + " was discarded."
            );
            if (_attacker.definition_id == "loc.pirate_destroyer") {
                _attacker.ready = true;
                array_push(
                    game_state.event_log,
                    "Pirate Destroyer readied after the successful raid."
                );
            }
        } else if (_defender_total > _attacker_total) {
            _defender_player.telemetry.raids_won += 1;
            _attacker_player.telemetry.raids_lost += 1;
            var _defender_capacity_remaining =
                max(0, 1 - array_length(_defender.cargo));
            if (_defender_capacity_remaining > 0
            && array_length(_attacker.cargo) > _defender_capacity_remaining) {
                pending_choice = {
                    kind: "raid_cargo",
                    attacker_ship_id: _raid.attacker_ship_id,
                    defender_ship_id: _raid.defender_ship_id,
                    attacker_total: _attacker_total,
                    defender_total: _defender_total,
                    winner_is_attacker: false,
                    prompt: "Choose the Metroid taken from the losing Ship."
                };
                game_state.priority_player = 1 - game_state.active_player;
                return true;
            }
            var _lost_attacker = raid_discard_ship(
                _attacker_player,
                _attacker_ship_index,
                _defender
            );
            array_push(_destroyed_ship_players, game_state.active_player);
            array_push(
                game_state.event_log,
                "Raid " + string(_attacker_total) + "-"
                + string(_defender_total) + ": "
                + _lost_attacker.definition.name + " was discarded."
            );
        } else {
            _attacker_player.telemetry.raid_ties += 1;
            _defender_player.telemetry.raid_ties += 1;
            var _tied_attacker_name = _attacker.definition.name;
            var _tied_defender_name = _defender.definition.name;
            raid_discard_ship(
                _attacker_player,
                _attacker_ship_index,
                undefined
            );
            raid_discard_ship(
                _defender_player,
                _defender_ship_index,
                undefined
            );
            array_push(_destroyed_ship_players, game_state.active_player);
            array_push(_destroyed_ship_players, 1 - game_state.active_player);
            array_push(
                game_state.event_log,
                "Raid tied " + string(_attacker_total) + "-"
                + string(_defender_total) + ": "
                + _tied_attacker_name + " and " + _tied_defender_name
                + " were discarded."
            );
        }

        pending_choice = undefined;
        game_state.priority_player = game_state.active_player;
        ui_selected_kind = "";
        ui_selected_index = -1;
        if (array_length(_destroyed_ship_players) > 0) {
            return trigger_gf_soldier_ship_destructions(
                _destroyed_ship_players
            );
        }
        return true;
    };

    cancel_pending_choice = function() {
        if (!is_undefined(pending_choice)
        && pending_choice.kind == "researcher_discard") {
            array_push(
                game_state.event_log,
                "Researcher's required discard must be completed."
            );
            return false;
        }
        if (!is_undefined(pending_choice)
        && pending_choice.kind == "queen_event") {
            array_push(
                game_state.event_log,
                "Queen Metroid Awakens must be resolved before play continues."
            );
            return false;
        }
        if (!is_undefined(pending_choice)
        && (pending_choice.kind == "space_pirate_payment"
            || pending_choice.kind == "space_pirate_ready"
             || pending_choice.kind == "choose_faction"
             || pending_choice.kind == "special_containment_ship"
             || pending_choice.kind == "adam_breach"
             || pending_choice.kind == "breach_character"
             || pending_choice.kind == "olympus_ready"
             || pending_choice.kind == "raid_cargo"
             || pending_choice.kind == "back_in_the_day"
             || pending_choice.kind == "torizo_metroid"
             || pending_choice.kind == "chozo_ghosts_source"
             || pending_choice.kind == "chozo_ghosts_target")) {
            array_push(
                game_state.event_log,
                "The current mandatory choice must be completed."
            );
            return false;
        }
        if (!is_undefined(pending_choice)
        && pending_choice.kind == "raid"
        && pending_choice.stage != "target") {
            array_push(
                game_state.event_log,
                "The raid must be resolved after its target is chosen."
            );
            return false;
        }
        if (!is_undefined(pending_choice)) {
            array_push(game_state.event_log, "Pending choice cancelled.");
        }
        pending_choice = undefined;
        return true;
    };

    resolve_end_turn_attachments = function() {
        // "At end of every turn" on a permanent means each of its controller's
        // turns, not both players' turns.
        for (var _player_index = game_state.active_player;
             _player_index <= game_state.active_player;
             _player_index++) {
            var _player = game_state.players[_player_index];
            for (var _ship_index = 0;
                 _ship_index < array_length(_player.board.ships);
                 _ship_index++) {
                var _ship = _player.board.ships[_ship_index];
                if (_ship.definition_id == "lop.leviathan_battleship") {
                    for (var _cargo_index = 0;
                         _cargo_index < array_length(_ship.cargo);
                         _cargo_index++) {
                        if (_ship.cargo[_cargo_index].definition_id
                        != "metroid.hunter") {
                            var _hunter_definition =
                                get_metroid_definition("metroid.hunter");
                            var _hunter = make_metroid_instance(
                                _hunter_definition,
                                "ship"
                            );
                            _hunter.host_ship_instance_id = _ship.instance_id;
                            _ship.cargo[_cargo_index] = _hunter;
                            array_push(
                                game_state.event_log,
                                "Leviathan Battleship replaced its cargo with "
                                + "a Hunter Metroid."
                            );
                        }
                    }
                }
                if (_ship.definition_id == "loc.chozo_transport") {
                    for (var _transport_cargo_index = 0;
                         _transport_cargo_index
                            < array_length(_ship.cargo);
                         _transport_cargo_index++) {
                        var _transport_metroid =
                            _ship.cargo[_transport_cargo_index];
                        var _transport_stage =
                            _transport_metroid.definition.stage;
                        if (!is_real(_transport_stage)
                        || _transport_stage >= 5
                        || _transport_metroid.definition_id
                            == "metroid.hunter") continue;
                        var _transport_evolved = create_metroid_for_stage(
                            _transport_stage + 1
                        );
                        _transport_evolved.zone = "ship";
                        _transport_evolved.host_ship_instance_id =
                            _ship.instance_id;
                        _transport_evolved.ui_position_initialized =
                            _transport_metroid.ui_position_initialized;
                        _transport_evolved.ui_x = _transport_metroid.ui_x;
                        _transport_evolved.ui_y = _transport_metroid.ui_y;
                        _transport_evolved.ui_zone = _transport_metroid.ui_zone;
                        _ship.cargo[_transport_cargo_index] =
                            _transport_evolved;
                        array_push(
                            game_state.event_log,
                            _transport_metroid.definition.name + " aboard "
                            + _ship.definition.name + " evolved into "
                            + _transport_evolved.definition.name + "."
                        );
                        var _transport_next_stage = _transport_stage + 1;
                        if (_transport_next_stage == 4
                        || _transport_next_stage == 5) {
                            var _transport_mutation =
                                _transport_next_stage == 5
                                && game_state.mutation >= 4 ? 2 : 1;
                            game_state.mutation = min(
                                game_state.mutation + _transport_mutation,
                                game_state.mutation_limit
                            );
                            array_push(
                                game_state.event_log,
                                "Mutation advanced "
                                + string(_transport_mutation) + " space(s) to "
                                + string(game_state.mutation) + "/"
                                + string(game_state.mutation_limit)
                                + " from Chozo Transport's research."
                            );
                        }
                    }
                }
            }
            for (var _character_index =
                    array_length(_player.board.characters) - 1;
                 _character_index >= 0;
                 _character_index--) {
                var _character = _player.board.characters[_character_index];
                var _baby_attached = false;
                var _ped_suit_count = 0;
                for (var _attachment_index = 0;
                     _attachment_index < array_length(_character.attachments);
                     _attachment_index++) {
                    var _character_attachment =
                        _character.attachments[_attachment_index];
                    if (_character_attachment.definition_id == "loc.the_baby") {
                        _baby_attached = true;
                    }
                    if (_character_attachment.printed_definition_id
                    == "lop.p_e_d_suit") {
                        _ped_suit_count += 1;
                    }
                }
                if (_ped_suit_count > 0) {
                    _character.phazon_tokens += _ped_suit_count;
                    array_push(
                        game_state.event_log,
                        _character.definition.name + " gained "
                        + string(_ped_suit_count) + " Phazon token(s) from "
                        + "P.E.D. Suit at end of turn."
                    );
                }
                if (_baby_attached) {
                    _character.ready = false;
                    array_push(
                        game_state.event_log,
                        _character.definition.name
                        + " exhausted at end of turn because The Baby is attached."
                    );
                    if (card_discards_from_phazon(_character)) {
                        var _baby_discard_name = _character.definition.name;
                        remove_ability_source(
                            _player_index == game_state.active_player
                                ? "character"
                                : "opponent_character",
                            _character_index,
                            _character,
                            false
                        );
                        array_push(
                            game_state.event_log,
                            _baby_discard_name
                                + " was discarded after The Baby exhausted it while corrupted."
                        );
                    }
                }
            }
            for (var _location_index =
                    array_length(_player.board.locations) - 1;
                 _location_index >= 0;
                 _location_index--) {
                var _location = _player.board.locations[_location_index];
                var _leviathan_attached = false;
                for (var _location_attachment_index = 0;
                     _location_attachment_index
                        < array_length(_location.attachments);
                     _location_attachment_index++) {
                    if (_location.attachments[
                        _location_attachment_index
                    ].definition_id == "lop.leviathan") {
                        _leviathan_attached = true;
                        break;
                    }
                }
                if (_leviathan_attached) {
                    _location.ready = false;
                    array_push(
                        game_state.event_log,
                        _location.definition.name
                        + " exhausted at end of turn because Leviathan is attached."
                    );
                    if (card_discards_from_phazon(_location)) {
                        var _leviathan_discard_name = _location.definition.name;
                        remove_ability_source(
                            _player_index == game_state.active_player
                                ? "location"
                                : "opponent_location",
                            _location_index,
                            _location,
                            false
                        );
                        array_push(
                            game_state.event_log,
                            _leviathan_discard_name
                                + " was discarded after Leviathan exhausted it while corrupted."
                        );
                    }
                }
            }
        }
    };

    resolve_start_turn_researchers = function(_player) {
        var _researcher_count = 0;
        for (var _character_index = 0;
             _character_index < array_length(_player.board.characters);
             _character_index++) {
            var _id = _player.board.characters[_character_index].definition_id;
            if (_id == "loc.researcher" || _id == "starter.researcher") {
                _researcher_count += 1;
            }
        }
        if (_researcher_count <= 0) {
            return;
        }
        var _researcher_hand_before = array_length(_player.hand);
        draw_from_deck(_player, _researcher_count);
        var _researcher_drawn = max(
            0,
            array_length(_player.hand) - _researcher_hand_before
        );
        if (_researcher_drawn <= 0) {
            array_push(
                game_state.event_log,
                "Researcher could not draw, so no discard was required."
            );
            return;
        }
        pending_choice = {
            kind: "researcher_discard",
            remaining: _researcher_drawn,
            prompt: "Researcher: select "
                + string(_researcher_drawn)
                + " card(s) from your hand to discard."
        };
        array_push(
            game_state.event_log,
            "Researcher drew " + string(_researcher_drawn)
            + " card(s); matching discards are required."
        );
    };

    resolve_researcher_discard = function(_hand_index) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "researcher_discard") {
            return false;
        }
        var _player = game_state.players[game_state.active_player];
        if (array_length(_player.hand) <= 0) {
            array_push(
                game_state.event_log,
                "Researcher's discard requirement cleared because the hand was empty."
            );
            pending_choice = undefined;
            return true;
        }
        if (_hand_index < 0 || _hand_index >= array_length(_player.hand)) {
            return false;
        }
        var _card = _player.hand[_hand_index];
        array_delete(_player.hand, _hand_index, 1);
        clear_card_board_state(_card);
        _card.zone = "discard";
        array_push(_player.discard, _card);
        array_push(
            game_state.event_log,
            _player.name + " discarded " + _card.definition.name
                + " for Researcher."
        );
        pending_choice.remaining -= 1;
        if (pending_choice.remaining <= 0) {
            pending_choice = undefined;
        } else {
            pending_choice.prompt = "Researcher: select "
                + string(pending_choice.remaining)
                + " more card(s) to discard.";
        }
        return true;
    };

    raid_contribute_selected = function(_source_kind, _source_index) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "raid"
        || (pending_choice.stage != "attackers"
            && pending_choice.stage != "defenders")) return false;
        if (argument_count >= 2) {
            select_raid_ability_source(_source_kind, _source_index);
        }
        var _source = get_ability_source(
            pending_choice.ability_source_kind,
            pending_choice.ability_source_index
        );
        if (is_undefined(_source)
        || _source.definition.type != "character"
        || _source.controller != game_state.priority_player) return false;
        return raid_toggle_character(
            pending_choice.ability_source_index,
            pending_choice.stage == "defenders"
        );
    };

    chozo_ghosts_end_turn = undefined;

    finish_end_turn_after_ghosts = function(_ends_final_round) {
        chozo_ghosts_end_turn = undefined;
        game_state.priority_player = game_state.active_player;
        game_state.phase = "mutation";
        resolve_mutation_phase();
        if (_ends_final_round && game_state.phase != "game_over") {
            array_push(
                game_state.event_log,
                "FINAL ROUND COMPLETE: " + game_state.final_round_reason
            );
            resolve_game_over();
            return true;
        }
        if (game_state.phase == "pass_turn"
        && current_time >= presentation_evolution_until_ms) {
            advance_game_phase();
        }
        return true;
    };

    chozo_ghosts_find_sources = function(_owner_index, _ghost) {
        var _sources = [];
        var _player = game_state.players[_owner_index];
        var _zones = [
            _player.board.characters,
            _player.board.ships,
            _player.board.locations,
            _player.board.relics
        ];
        for (var _zone_index = 0; _zone_index < array_length(_zones); _zone_index++) {
            for (var _card_index = 0;
                 _card_index < array_length(_zones[_zone_index]);
                 _card_index++) {
                var _card = _zones[_zone_index][_card_index];
                if (_card.instance_id != _ghost.instance_id
                && _card.phazon_tokens > 0) {
                    array_push(_sources, _card);
                }
            }
        }
        return _sources;
    };

    chozo_ghosts_discard = function(_owner_index, _ghost) {
        var _characters = game_state.players[_owner_index].board.characters;
        for (var _ghost_index = 0;
             _ghost_index < array_length(_characters);
             _ghost_index++) {
            if (_characters[_ghost_index].instance_id == _ghost.instance_id) {
                array_delete(_characters, _ghost_index, 1);
                clear_card_board_state(_ghost);
                _ghost.zone = "discard";
                array_push(game_state.players[_owner_index].discard, _ghost);
                return true;
            }
        }
        return false;
    };

    continue_chozo_ghosts_end_turn = function() {
        if (is_undefined(chozo_ghosts_end_turn)) return false;
        while (chozo_ghosts_end_turn.index
            < array_length(chozo_ghosts_end_turn.ghosts)) {
            var _entry = chozo_ghosts_end_turn.ghosts[
                chozo_ghosts_end_turn.index
            ];
            var _ghost = _entry.card;
            if (_ghost.zone != "board") {
                chozo_ghosts_end_turn.index += 1;
                continue;
            }
            var _sources = chozo_ghosts_find_sources(_entry.owner, _ghost);
            if (array_length(_sources) > 0) {
                game_state.priority_player = _entry.owner;
                pending_choice = {
                    kind: "chozo_ghosts_source",
                    player_index: _entry.owner,
                    ghost: _ghost,
                    prompt: "Chozo Ghosts: select another card you control with Phazon."
                };
                return true;
            }
            array_push(
                game_state.event_log,
                "Chozo Ghosts had no other controlled card with Phazon, so no token moved."
            );
            return resolve_chozo_ghosts_threshold();
        }
        return finish_end_turn_after_ghosts(
            chozo_ghosts_end_turn.ends_final_round
        );
    };

    resolve_chozo_ghosts_threshold = function() {
        var _entry = chozo_ghosts_end_turn.ghosts[
            chozo_ghosts_end_turn.index
        ];
        var _ghost = _entry.card;
        if (_ghost.phazon_tokens >= 3) {
            var _tokens = _ghost.phazon_tokens;
            _ghost.phazon_tokens = 0;
            chozo_ghosts_discard(_entry.owner, _ghost);
            array_push(
                game_state.event_log,
                "Chozo Ghosts was discarded with " + string(_tokens)
                    + " Phazon token(s)."
            );
            var _opponent = game_state.players[1 - _entry.owner];
            if (array_length(_opponent.board.characters) > 0) {
                game_state.priority_player = _entry.owner;
                pending_choice = {
                    kind: "chozo_ghosts_target",
                    player_index: _entry.owner,
                    target_player_index: 1 - _entry.owner,
                    tokens: _tokens,
                    prompt: "Chozo Ghosts: select an opposing Character to receive "
                        + string(_tokens) + " Phazon token(s)."
                };
                return true;
            }
            array_push(
                game_state.event_log,
                "Chozo Ghosts had no opposing Character to receive its Phazon."
            );
        }
        chozo_ghosts_end_turn.index += 1;
        pending_choice = undefined;
        return continue_chozo_ghosts_end_turn();
    };

    resolve_chozo_ghosts_source = function(_card) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "chozo_ghosts_source"
        || is_undefined(_card)
        || _card.controller != pending_choice.player_index
        || _card.instance_id == pending_choice.ghost.instance_id
        || _card.phazon_tokens <= 0) return false;
        _card.phazon_tokens -= 1;
        pending_choice.ghost.phazon_tokens += 1;
        array_push(
            game_state.event_log,
            "Chozo Ghosts moved 1 Phazon token from "
                + _card.definition.name + "."
        );
        pending_choice = undefined;
        return resolve_chozo_ghosts_threshold();
    };

    resolve_chozo_ghosts_target = function(_card) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "chozo_ghosts_target"
        || pending_choice.target_player_index < 0
        || pending_choice.target_player_index
            >= array_length(game_state.players)) return false;
        var _target_characters = game_state.players[
            pending_choice.target_player_index
        ].board.characters;
        if (array_length(_target_characters) <= 0) {
            array_push(
                game_state.event_log,
                "Chozo Ghosts had no remaining opposing Character to receive its Phazon."
            );
            chozo_ghosts_end_turn.index += 1;
            pending_choice = undefined;
            return continue_chozo_ghosts_end_turn();
        }
        if (is_undefined(_card)) return false;
        var _target_index = raid_find_instance_index(
            _target_characters,
            _card.instance_id
        );
        if (_target_index < 0) return false;
        // Presence on the chosen player's Character board is authoritative. A
        // stale controller field must not make AI repeatedly reject the same
        // otherwise legal target.
        _card = _target_characters[_target_index];
        var _tokens = pending_choice.tokens;
        _card.phazon_tokens += _tokens;
        array_push(
            game_state.event_log,
            "Chozo Ghosts put " + string(_tokens) + " Phazon token(s) on "
                + _card.definition.name + "."
        );
        chozo_ghosts_end_turn.index += 1;
        pending_choice = undefined;
        return continue_chozo_ghosts_end_turn();
    };

    begin_chozo_ghosts_end_turn = function(_ends_final_round) {
        var _ghosts = [];
        var _ghost_owner = game_state.active_player;
        var _characters = game_state.players[_ghost_owner].board.characters;
        for (var _character_index = 0;
             _character_index < array_length(_characters);
             _character_index++) {
            if (_characters[_character_index].definition_id
            == "lop.chozo_ghosts") {
                array_push(_ghosts, {
                    owner: _ghost_owner,
                    card: _characters[_character_index]
                });
            }
        }
        if (array_length(_ghosts) <= 0) {
            return finish_end_turn_after_ghosts(_ends_final_round);
        }
        chozo_ghosts_end_turn = {
            ghosts: _ghosts,
            index: 0,
            ends_final_round: _ends_final_round
        };
        return continue_chozo_ghosts_end_turn();
    };

    end_turn_action = function() {
        if (game_state.phase != "action") {
            return false;
        }
        if (!is_undefined(pending_choice)
        && (pending_choice.kind == "raid"
        || pending_choice.kind == "queen_event"
        || pending_choice.kind == "chozo_ghosts_source"
        || pending_choice.kind == "chozo_ghosts_target")) {
            log_action_failure(
                "Resolve the current game-state event before ending the turn."
            );
            return false;
        }
        cancel_pending_choice();
        resolve_end_turn_attachments();
        if (game_state.mutation >= game_state.mutation_limit) {
            resolve_game_over();
            return true;
        }
        var _ending_player = game_state.players[game_state.active_player];
        var _ending_zones = [
            _ending_player.board.characters,
            _ending_player.board.ships,
            _ending_player.board.locations,
            _ending_player.board.relics
        ];
        for (var _zone_index = 0;
             _zone_index < array_length(_ending_zones);
             _zone_index++) {
            for (var _card_index = 0;
                 _card_index < array_length(_ending_zones[_zone_index]);
                 _card_index++) {
                var _ending_card = _ending_zones[_zone_index][_card_index];
                _ending_card.temporary_stat_bonus = 0;
                _ending_card.ai_readied_by_effect_this_turn = false;
                if (_ending_card.copy_until_end_turn) {
                    _ending_card.definition_id =
                        _ending_card.printed_definition_id;
                    _ending_card.definition = _ending_card.printed_definition;
                    _ending_card.copy_until_end_turn = false;
                }
            }
        }
        array_push(
            game_state.event_log,
            game_state.players[game_state.active_player].name
            + " ended their action phase."
        );
        if (guidance_is_local_player(game_state.active_player)) {
            queue_first_game_guidance(
                "end_turn", "ENDING THE TURN",
                "Ending the Action phase begins Containment. Check your Lab's total Hazard and keep enough Security available."
            );
        }
        var _ends_final_round = game_state.final_round_active
            && game_state.active_player == game_state.final_round_end_player;
        return begin_chozo_ghosts_end_turn(_ends_final_round);
    };

    confirm_turn_handoff = function() {
        if (!handoff_active || game_state.phase == "game_over") {
            return false;
        }
        handoff_active = false;
        array_push(
            game_state.event_log,
            game_state.players[game_state.active_player].name
            + " accepted control for turn "
            + string(game_state.turn_number) + "."
        );
        resolve_start_turn_researchers(
            game_state.players[game_state.active_player]
        );
        skip_empty_lab_containment();
        return true;
    };

}

