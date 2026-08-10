function loc_raids() {
    raid_array_contains = function(_array, _value) {
        for (var _index = 0; _index < array_length(_array); _index++) {
            if (_array[_index] == _value) {
                return true;
            }
        }
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
        for (var _selected_index = 0;
             _selected_index < array_length(_selected);
             _selected_index++) {
            if (_selected[_selected_index] == _character_index) {
                array_delete(_selected, _selected_index, 1);
                return true;
            }
        }
        array_push(_selected, _character_index);
        return true;
    };

    get_raid_cost = function(_player) {
        var _cost = 2;
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
        var _raid_cost = get_raid_cost(_attacker_player);
        if (_attacker_player.command_points < _raid_cost) {
            log_action_failure(
                "Need " + string(_raid_cost) + " CP to initiate this raid."
            );
            return false;
        }

        pending_choice = {
            kind: "raid",
            stage: "target",
            attacker_ship_index: _attacker_index,
            defender_ship_index: -1,
            attacker_characters: [],
            defender_characters: [],
            attacker_ability_bonus: 0,
            defender_ability_bonus: 0,
            interaction_mode: "abilities",
            ability_source_kind: "",
            ability_source_index: -1,
            ability_index: -1,
            raid_cost: _raid_cost,
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
        if (_attacker_player.command_points < pending_choice.raid_cost) {
            log_action_failure("The raid cost can no longer be paid.");
            pending_choice = undefined;
            return false;
        }

        var _attacker = _attacker_player.board.ships[
            pending_choice.attacker_ship_index
        ];
        _attacker_player.command_points -= pending_choice.raid_cost;
        _attacker_player.telemetry.raids_started += 1;
        _attacker.ready = false;
        if (card_discards_from_phazon(_attacker)) {
            var _corrupted_attacker_name = _attacker.definition.name;
            raid_discard_ship(
                _attacker_player,
                pending_choice.attacker_ship_index,
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
        pending_choice.defender_ship_index = _defender_ship_index;
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
            if ((!_raid_ability.cost_exhaust || _card.ready)
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
        if (pending_choice == _raid) raid_suspended_choice = undefined;
        _raid.ability_source_kind = "";
        _raid.ability_source_index = -1;
        _raid.ability_index = -1;
        return _resolved;
    };

    raid_exhaust_characters = function(_player, _selected) {
        var _strength = 0;
        for (var _selection_index = 0;
             _selection_index < array_length(_selected);
             _selection_index++) {
            var _character_index = _selected[_selection_index];
            if (_character_index >= 0
            && _character_index < array_length(_player.board.characters)) {
                var _character = _player.board.characters[_character_index];
                if (_character.ready) {
                    _strength += get_card_stat(_character, "raid_character");
                    _character.ready = false;
                }
            }
        }

        for (var _board_index = array_length(_player.board.characters) - 1;
             _board_index >= 0;
             _board_index--) {
            if (raid_array_contains(_selected, _board_index)
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
        var _winner_ship_index = _choice.winner_is_attacker
            ? _choice.attacker_ship_index
            : _choice.defender_ship_index;
        var _loser_ship_index = _choice.winner_is_attacker
            ? _choice.defender_ship_index
            : _choice.attacker_ship_index;
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
        return true;
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
        var _attacker = _attacker_player.board.ships[
            _raid.attacker_ship_index
        ];
        var _defender = _defender_player.board.ships[
            _raid.defender_ship_index
        ];
        var _attacker_total = get_card_stat(_attacker, "raid_attacker_ship")
            + raid_exhaust_characters(
                _attacker_player,
                _raid.attacker_characters
            )
            + _raid.attacker_ability_bonus;
        var _defender_total = get_card_stat(_defender, "raid_defender_ship")
            + raid_exhaust_characters(
                _defender_player,
                _raid.defender_characters
            )
            + _raid.defender_ability_bonus;

        if (_attacker_total > _defender_total) {
            _attacker_player.telemetry.raids_won += 1;
            _defender_player.telemetry.raids_lost += 1;
            var _raid_capacity_remaining =
                max(0, 1 - array_length(_attacker.cargo));
            if (_raid_capacity_remaining > 0
            && array_length(_defender.cargo) > _raid_capacity_remaining) {
                pending_choice = {
                    kind: "raid_cargo",
                    attacker_ship_index: _raid.attacker_ship_index,
                    defender_ship_index: _raid.defender_ship_index,
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
                _raid.defender_ship_index,
                _attacker
            );
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
                    attacker_ship_index: _raid.attacker_ship_index,
                    defender_ship_index: _raid.defender_ship_index,
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
                _raid.attacker_ship_index,
                _defender
            );
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
                _raid.attacker_ship_index,
                undefined
            );
            raid_discard_ship(
                _defender_player,
                _raid.defender_ship_index,
                undefined
            );
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
            _player.board.locations
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
        || is_undefined(_card)
        || _card.definition.type != "character"
        || _card.controller != pending_choice.target_player_index) return false;
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
        var _ending_player = game_state.players[game_state.active_player];
        var _ending_zones = [
            _ending_player.board.characters,
            _ending_player.board.ships,
            _ending_player.board.locations
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

