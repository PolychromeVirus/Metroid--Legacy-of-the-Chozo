function loc_abilities() {
    get_activated_abilities = function(_card) {
        var _abilities = [];
        if (is_undefined(_card)) {
            return _abilities;
        }

        switch (_card.definition_id) {
            case "loc.gandrayda":
                array_push(_abilities, {
                    label: "PAY 1: COPY CHARACTER",
                    cost_cp: 1,
                    cost_exhaust: false,
                    cost_destroy: false,
                    target_kind: "another_character",
                    prompt: "Select another Character controlled by either player.",
                    effect_kind: "copy_until_end_turn"
                });
                break;

            case "loc.gf_marine":
            case "loc.g_f_s_tyr":
                array_push(_abilities, {
                    label: "EXHAUST: +1 CP",
                    cost_cp: 0,
                    cost_exhaust: true,
                    cost_destroy: false,
                    target_kind: "",
                    prompt: "",
                    effect_kind: "gain_cp"
                });
                break;

            case "loc.admiral_dane":
                array_push(_abilities, {
                    label: "PAY 1: READY SHIP",
                    cost_cp: 1,
                    cost_exhaust: false,
                    cost_destroy: false,
                    target_kind: "ship",
                    prompt: "Select one of your Ships to ready.",
                    effect_kind: "ready_ship"
                });
                break;

            case "loc.gf_soldier":
                array_push(_abilities, {
                    label: "PAY 1 + EXHAUST",
                    cost_cp: 1,
                    cost_exhaust: true,
                    cost_destroy: false,
                    target_kind: "ship",
                    prompt: "Select one of your Ships to gain +1 Security this turn.",
                    effect_kind: "ship_security_1"
                });
                break;

            case "loc.samus_aran":
                array_push(_abilities, {
                    label: "EXHAUST: +2 SECURITY",
                    cost_cp: 0,
                    cost_exhaust: true,
                    cost_destroy: false,
                    target_kind: "ship",
                    prompt: "Select a Ship to gain +2 Security this turn.",
                    effect_kind: "ship_security_2"
                });
                array_push(_abilities, {
                    label: "PAY 1: +1 RAID DEFENSE",
                    cost_cp: 1,
                    cost_exhaust: false,
                    cost_destroy: false,
                    target_kind: "",
                    prompt: "",
                    effect_kind: "raid_defense_1"
                });
                break;

            case "loc.quiet_robe":
                array_push(_abilities, {
                    label: "PAY 1 + EXHAUST: PLACE 2",
                    cost_cp: 1,
                    cost_exhaust: true,
                    cost_destroy: false,
                    target_kind: "ready_ship",
                    prompt: "Select a ready Ship to receive two Metroids.",
                    effect_kind: "quiet_robe_place"
                });
                break;

            case "loc.body_adaptation_machine":
                array_push(_abilities, {
                    label: "PAY 1: ATTACH + FACTION",
                    cost_cp: 1,
                    cost_exhaust: false,
                    cost_destroy: false,
                    target_kind: "own_other_character",
                    prompt: "Select another Character you control.",
                    effect_kind: "attach_choose_faction"
                });
                break;

            case "loc.rundas":
                array_push(_abilities, {
                    label: "PAY 1 + EXHAUST: CHARACTER",
                    cost_cp: 1,
                    cost_exhaust: true,
                    cost_destroy: false,
                    target_kind: "any_character",
                    prompt: "Select a Character controlled by either player to exhaust.",
                    effect_kind: "exhaust_card"
                });
                array_push(_abilities, {
                    label: "PAY 2 + EXHAUST: SHIP",
                    cost_cp: 2,
                    cost_exhaust: true,
                    cost_destroy: false,
                    target_kind: "any_ship",
                    prompt: "Select a Ship controlled by either player to exhaust.",
                    effect_kind: "exhaust_card"
                });
                break;

            case "loc.raven_beak":
                array_push(_abilities, {
                    label: "PAY 2 + EXHAUST: DISCARD",
                    cost_cp: 2,
                    cost_exhaust: true,
                    cost_destroy: false,
                    target_kind: "any_character",
                    prompt: "Select a Character controlled by either player to discard.",
                    effect_kind: "discard_card"
                });
                break;

            case "loc.mawkin_starship":
                array_push(_abilities, {
                    label: "PAY 3 + EXHAUST: DISCARD",
                    cost_cp: 3,
                    cost_exhaust: true,
                    cost_destroy: false,
                    target_kind: "opponent_permanent",
                    prompt: "Select a permanent your opponent controls to discard.",
                    effect_kind: "discard_card"
                });
                break;

            case "loc.the_baby":
                array_push(_abilities, {
                    label: "EXHAUST: ATTACH",
                    cost_cp: 0,
                    cost_exhaust: true,
                    cost_destroy: false,
                    target_kind: "another_character",
                    prompt: "Select another Character to attach The Baby to.",
                    effect_kind: "attach_source"
                });
                break;

            case "lop.aurora_unit_217":
                array_push(_abilities, {
                    label: "EXHAUST: ATTACH TO SHIP",
                    cost_cp: 0,
                    cost_exhaust: true,
                    cost_destroy: false,
                    target_kind: "any_ship",
                    prompt: "Select a Ship to attach Aurora Unit 217 to.",
                    effect_kind: "attach_source"
                });
                array_push(_abilities, {
                    label: "DESTROY: CORRUPT ALL",
                    cost_cp: 0,
                    cost_exhaust: false,
                    cost_destroy: true,
                    target_kind: "",
                    prompt: "",
                    effect_kind: "corrupt_all"
                });
                break;

            case "lop.dark_samus":
                array_push(_abilities, {
                    label: "PAY 1 + EXHAUST: DISCARD",
                    cost_cp: 1,
                    cost_exhaust: true,
                    cost_destroy: false,
                    target_kind: "dark_samus_character",
                    prompt: "Select any number of Characters whose total Strength does not exceed the Phazon tokens removed.",
                    effect_kind: "dark_samus_discard"
                });
                array_push(_abilities, {
                    label: "EXHAUST: CONSOLIDATE",
                    cost_cp: 0,
                    cost_exhaust: true,
                    cost_destroy: false,
                    target_kind: "own_phazon_source",
                    prompt: "Select another card you control with a Phazon token.",
                    effect_kind: "dark_samus_consolidate"
                });
                break;

            case "lop.corrupt_gandrayda":
                array_push(_abilities, {
                    label: "PAY 2: EXHAUST + COPY",
                    cost_cp: 2,
                    cost_exhaust: false,
                    cost_destroy: false,
                    target_kind: "another_permanent",
                    prompt: "Select another Character, Ship, or Location controlled by either player.",
                    effect_kind: "corrupt_copy"
                });
                break;

            case "lop.leviathan":
                array_push(_abilities, {
                    label: "PAY 1 + EXHAUST: ATTACH",
                    cost_cp: 1,
                    cost_exhaust: true,
                    cost_destroy: false,
                    target_kind: "any_location",
                    prompt: "Select a Location controlled by either player.",
                    effect_kind: "leviathan_attach"
                });
                break;

            case "lop.p_e_d_suit":
                array_push(_abilities, {
                    label: "EXHAUST: ATTACH",
                    cost_cp: 0,
                    cost_exhaust: true,
                    cost_destroy: false,
                    target_kind: "another_character",
                    prompt: "Select another Character to attach P.E.D. Suit to.",
                    effect_kind: "attach_source"
                });
                break;

            case "loc.ghor":
                array_push(_abilities, {
                    label: "PAY 1 + DESTROY",
                    cost_cp: 1,
                    cost_exhaust: false,
                    cost_destroy: true,
                    target_kind: "shop_ship",
                    prompt: "Select a Ship in the Shop to deploy for free.",
                    effect_kind: "deploy_shop_ship"
                });
                break;

            case "loc.ready_room":
                array_push(_abilities, {
                    label: "EXHAUST: BH REFUND",
                    cost_cp: 0,
                    cost_exhaust: true,
                    cost_destroy: false,
                    target_kind: "",
                    prompt: "",
                    effect_kind: "prepare_bh_refund"
                });
                break;

            case "loc.galactic_federation_hq":
                array_push(_abilities, {
                    label: "EXHAUST: DOUBLE GF",
                    cost_cp: 0,
                    cost_exhaust: true,
                    cost_destroy: false,
                    target_kind: "",
                    prompt: "",
                    effect_kind: "prepare_gf_double"
                });
                break;

            case "loc.biologic_space_laboratories":
                array_push(_abilities, {
                    label: "PAY 1 + EXHAUST: EVENT",
                    cost_cp: 1,
                    cost_exhaust: true,
                    cost_destroy: false,
                    target_kind: "shop_event",
                    prompt: "Select an Event in the Shop to reserve for free.",
                    effect_kind: "reserve_shop_event_free"
                });
                break;

            case "loc.space_pirate_homeworld":
                array_push(_abilities, {
                    label: "EXHAUST: DEMAND PAYMENT",
                    cost_cp: 0,
                    cost_exhaust: true,
                    cost_destroy: false,
                    target_kind: "",
                    prompt: "",
                    effect_kind: "space_pirate_payment"
                });
                break;
        }
        for (var _ped_attachment_index = 0;
             _ped_attachment_index < array_length(_card.attachments);
             _ped_attachment_index++) {
            if (_card.attachments[_ped_attachment_index].printed_definition_id
            == "lop.p_e_d_suit") {
                array_push(_abilities, {
                    label: "PAY 2: SPEND PHAZON",
                    cost_cp: 2,
                    cost_exhaust: false,
                    cost_destroy: false,
                    target_kind: "",
                    prompt: "",
                    effect_kind: "ped_strength"
                });
            }
        }
        return _abilities;
    };

    get_ability_source = function(_source_kind, _source_index) {
        var _opponent_source = string_copy(_source_kind, 1, 9) == "opponent_";
        var _player_index = _opponent_source
            ? 1 - game_state.active_player
            : game_state.active_player;
        var _base_kind = _opponent_source
            ? string_delete(_source_kind, 1, 9)
            : _source_kind;
        var _player = game_state.players[_player_index];
        if (_base_kind == "character"
        && _source_index >= 0
        && _source_index < array_length(_player.board.characters)) {
            return _player.board.characters[_source_index];
        }
        if (_base_kind == "ship"
        && _source_index >= 0
        && _source_index < array_length(_player.board.ships)) {
            return _player.board.ships[_source_index];
        }
        if (_base_kind == "location"
        && _source_index >= 0
        && _source_index < array_length(_player.board.locations)) {
            return _player.board.locations[_source_index];
        }
        return undefined;
    };

    // Board-region names are relative to the viewing player, while rules-engine
    // ability sources are relative to the active player. Normalize a visible card
    // by its actual controller before storing or transmitting a raid selection.
    get_raid_source_kind = function(_source_kind, _card) {
        var _base_kind = string_copy(_source_kind, 1, 9) == "opponent_"
            ? string_delete(_source_kind, 1, 9)
            : _source_kind;
        return _card.controller == game_state.active_player
            ? _base_kind
            : "opponent_" + _base_kind;
    };

    can_activate_selected_ability = function(
        _source_kind,
        _source_index,
        _ability_index
    ) {
        if (game_state.phase != "action"
        && game_state.phase != "containment") {
            return false;
        }
        var _source = get_ability_source(_source_kind, _source_index);
        var _abilities = get_activated_abilities(_source);
        if (_ability_index < 0 || _ability_index >= array_length(_abilities)) {
            return false;
        }
        var _ability = _abilities[_ability_index];
        var _shared_bsl = _ability.effect_kind == "reserve_shop_event_free";
        if (_source.controller != game_state.priority_player && !_shared_bsl) {
            return false;
        }
        var _payer_index = _shared_bsl
            ? game_state.priority_player
            : _source.controller;
        var _controller = game_state.players[_payer_index];
        if (_ability.effect_kind == "raid_defense_1") {
            return !is_undefined(pending_choice)
                && pending_choice.kind == "raid"
                && pending_choice.stage == "defenders"
                && game_state.priority_player == _source.controller;
        }
        if (_ability.cost_exhaust && !_source.ready) {
            return false;
        }
        if (_controller.command_points < _ability.cost_cp) {
            return false;
        }
        if (_ability.target_kind == "ship"
        && array_length(_controller.board.ships) <= 0) {
            return false;
        }
        if (_ability.target_kind == "ready_ship") {
            var _has_ready_ship = false;
            for (var _ready_ship_index = 0;
                 _ready_ship_index < array_length(_controller.board.ships);
                 _ready_ship_index++) {
                if (_controller.board.ships[_ready_ship_index].ready) {
                    _has_ready_ship = true;
                    break;
                }
            }
            if (!_has_ready_ship) {
                return false;
            }
        }
        if (_ability.target_kind == "dark_samus_character"
        && _source.phazon_tokens <= 0) {
            return false;
        }
        if (_ability.target_kind == "own_phazon_source") {
            var _phazon_zones = [
                _controller.board.characters,
                _controller.board.ships,
                _controller.board.locations
            ];
            var _has_phazon_source = false;
            for (var _phazon_zone_index = 0;
                 _phazon_zone_index < array_length(_phazon_zones);
                 _phazon_zone_index++) {
                var _phazon_zone = _phazon_zones[_phazon_zone_index];
                for (var _phazon_card_index = 0;
                     _phazon_card_index < array_length(_phazon_zone);
                     _phazon_card_index++) {
                    var _phazon_card = _phazon_zone[_phazon_card_index];
                    if (_phazon_card.instance_id != _source.instance_id
                    && _phazon_card.phazon_tokens > 0) {
                        _has_phazon_source = true;
                        break;
                    }
                }
                if (_has_phazon_source) break;
            }
            if (!_has_phazon_source) return false;
        }
        if (_ability.target_kind == "shop_ship") {
            var _has_shop_ship = false;
            for (var _shop_index = 0;
                 _shop_index < array_length(game_state.shop_row);
                 _shop_index++) {
                if (game_state.shop_row[_shop_index].definition.type == "ship") {
                    _has_shop_ship = true;
                    break;
                }
            }
            if (!_has_shop_ship) {
                return false;
            }
        }
        if (_ability.target_kind == "shop_event") {
            var _has_shop_event = false;
            for (var _event_shop_index = 0;
                 _event_shop_index < array_length(game_state.shop_row);
                 _event_shop_index++) {
                if (game_state.shop_row[_event_shop_index].definition.type
                == "event") {
                    _has_shop_event = true;
                    break;
                }
            }
            if (!_has_shop_event) {
                return false;
            }
        }
        return true;
    };

    remove_ability_source = function(
        _source_kind,
        _source_index,
        _source,
        _destroyed
    ) {
        var _player = game_state.players[_source.controller];
        var _base_kind = string_copy(_source_kind, 1, 9) == "opponent_"
            ? string_delete(_source_kind, 1, 9)
            : _source_kind;
        if (_base_kind == "character") {
            array_delete(_player.board.characters, _source_index, 1);
        } else if (_base_kind == "ship") {
            array_delete(_player.board.ships, _source_index, 1);
        } else if (_base_kind == "location") {
            array_delete(_player.board.locations, _source_index, 1);
        } else if (_base_kind == "attachment") {
            var _attachment_zones = [
                _player.board.characters,
                _player.board.ships,
                _player.board.locations
            ];
            for (var _host_zone_index = 0;
                 _host_zone_index < 3;
                 _host_zone_index++) {
                for (var _host_index = 0;
                     _host_index < array_length(
                        _attachment_zones[_host_zone_index]
                     );
                     _host_index++) {
                    var _host = _attachment_zones[
                        _host_zone_index
                    ][_host_index];
                    for (var _host_attachment_index =
                            array_length(_host.attachments) - 1;
                         _host_attachment_index >= 0;
                         _host_attachment_index--) {
                        if (_host.attachments[
                            _host_attachment_index
                        ].instance_id == _source.instance_id) {
                            array_delete(
                                _host.attachments,
                                _host_attachment_index,
                                1
                            );
                        }
                    }
                }
            }
        }

        while (array_length(_source.attachments) > 0) {
            var _attachment = _source.attachments[0];
            array_delete(_source.attachments, 0, 1);
            _attachment.zone = "discard";
            clear_card_board_state(_attachment);
            array_push(
                game_state.players[_attachment.owner].discard,
                _attachment
            );
            array_push(
                game_state.event_log,
                _attachment.definition.name
                    + " was discarded because its host left play."
            );
        }
        while (array_length(_source.cargo) > 0) {
            var _lost_cargo = _source.cargo[0];
            array_delete(_source.cargo, 0, 1);
            _lost_cargo.zone = "supply";
            _lost_cargo.host_ship_instance_id = -1;
        }
        clear_card_board_state(_source);
        if (_destroyed) {
            queue_card_destruction(_source, _base_kind);
            _source.zone = "removed";
            array_push(game_state.removed_cards, _source);
        } else {
            _source.zone = "discard";
            array_push(game_state.players[_source.owner].discard, _source);
        }
    };

    card_discards_from_phazon = function(_card) {
        return !is_undefined(_card)
            && _card.phazon_tokens >= 3
            && _card.definition_id != "lop.dark_samus";
    };

    get_ability_target_card = function(_target_kind, _target_index) {
        if (_target_kind == "shop") {
            if (_target_index >= 0
            && _target_index < array_length(game_state.shop_row)) {
                return game_state.shop_row[_target_index];
            }
            return undefined;
        }
        if (_target_kind == "attachment"
        || _target_kind == "opponent_attachment") {
            var _attachment_player_index =
                _target_kind == "opponent_attachment"
                    ? 1 - game_state.active_player
                    : game_state.active_player;
            var _attachment_player =
                game_state.players[_attachment_player_index];
            var _target_zones = [
                _attachment_player.board.characters,
                _attachment_player.board.ships,
                _attachment_player.board.locations
            ];
            for (var _target_zone_index = 0;
                 _target_zone_index < 3;
                 _target_zone_index++) {
                for (var _target_host_index = 0;
                     _target_host_index < array_length(
                        _target_zones[_target_zone_index]
                     );
                     _target_host_index++) {
                    var _target_host = _target_zones[
                        _target_zone_index
                    ][_target_host_index];
                    for (var _target_attachment_index = 0;
                         _target_attachment_index
                            < array_length(_target_host.attachments);
                         _target_attachment_index++) {
                        var _target_attachment = _target_host.attachments[
                            _target_attachment_index
                        ];
                        if (_target_attachment.instance_id == _target_index) {
                            return _target_attachment;
                        }
                    }
                }
            }
            return undefined;
        }
        return get_ability_source(_target_kind, _target_index);
    };

    move_source_to_attachment = function(
        _source_kind,
        _source_index,
        _source,
        _target
    ) {
        if (_source.zone != "board") {
            return false;
        }
        var _player = game_state.players[_source.controller];
        var _base_kind = string_copy(_source_kind, 1, 9) == "opponent_"
            ? string_delete(_source_kind, 1, 9)
            : _source_kind;
        if (_base_kind == "character") {
            array_delete(_player.board.characters, _source_index, 1);
        } else if (_base_kind == "ship") {
            array_delete(_player.board.ships, _source_index, 1);
        } else if (_base_kind == "location") {
            array_delete(_player.board.locations, _source_index, 1);
        } else {
            return false;
        }
        _source.zone = "attachment";
        _source.host_instance_id = _target.instance_id;
        array_push(_target.attachments, _source);
        if (guidance_is_local_player(_source.controller)) {
            queue_first_game_guidance(
                "attachment", "ATTACHMENT",
                "An attached card remains beneath its host and grants its listed effects. It leaves play with that host unless an effect says otherwise."
            );
        }
        return true;
    };

    consume_activation_modifiers = function(_source, _ability) {
        var _player = game_state.players[_source.controller];
        var _resolution_count = 1;
        if (_source.definition.type == "character"
        && card_has_faction(_source, "BH")
        && _player.next_bounty_hunter_refund) {
            _player.next_bounty_hunter_refund = false;
            _player.command_points += 1;
            telemetry_update_max_cp(_player);
            array_push(
                game_state.event_log,
                "Ready Room refunded 1 CP for "
                + _source.definition.name + "'s activation."
            );
        }
        if (_source.definition.type == "character"
        && card_has_faction(_source, "GF")
        && _ability.cost_exhaust
        && _player.next_gf_ability_double) {
            _player.next_gf_ability_double = false;
            _resolution_count = 2;
            array_push(
                game_state.event_log,
                "Galactic Federation HQ doubled "
                + _source.definition.name + "'s activation."
            );
        }
        return _resolution_count;
    };

    pay_activated_ability_cost = function(
        _source_kind,
        _source_index,
        _source,
        _ability
    ) {
        var _payer_index = _ability.effect_kind == "reserve_shop_event_free"
            ? game_state.priority_player
            : _source.controller;
        var _player = game_state.players[_payer_index];
        _player.command_points -= _ability.cost_cp;
        if (_ability.cost_exhaust) {
            _source.ready = false;
            if (card_discards_from_phazon(_source)) {
                remove_ability_source(
                    _source_kind,
                    _source_index,
                    _source,
                    false
                );
                array_push(
                    game_state.event_log,
                    _source.definition.name
                    + " was discarded after exhausting while corrupted."
                );
            }
        } else if (_ability.cost_destroy) {
            remove_ability_source(
                _source_kind,
                _source_index,
                _source,
                true
            );
            array_push(
                game_state.event_log,
                _source.definition.name + " was destroyed as an activation cost."
            );
        }
    };

    resolve_activated_ability = function(
        _source,
        _ability,
        _target_kind,
        _target_index
    ) {
        var _player = game_state.players[_source.controller];
        var _target = get_ability_target_card(_target_kind, _target_index);
        // Targeted effects may resolve after their source leaves the same array
        // as an activation cost, or may receive a second resolution after their
        // first resolution removed the target. Treat a vanished target as an
        // exhausted resolution rather than dereferencing an invalid array slot.
        if (_target_kind != "" && is_undefined(_target)) {
            array_push(
                game_state.event_log,
                _source.definition.name
                + "'s additional resolution had no remaining legal target."
            );
            return false;
        }
        switch (_ability.effect_kind) {
            case "copy_until_end_turn":
                _source.definition_id = _target.definition_id;
                _source.definition = _target.definition;
                _source.copy_until_end_turn = true;
                array_push(
                    game_state.event_log,
                    "Gandrayda became a copy of " + _target.definition.name
                    + " until end of turn."
                );
                return true;

            case "gain_cp":
                _player.command_points += 1;
                telemetry_update_max_cp(_player);
                array_push(
                    game_state.event_log,
                    _source.definition.name + " generated 1 CP."
                );
                return true;

            case "prepare_bh_refund":
                _player.next_bounty_hunter_refund = true;
                array_push(
                    game_state.event_log,
                    "Ready Room will refund 1 CP on the next Bounty Hunter activation."
                );
                return true;

            case "prepare_gf_double":
                _player.next_gf_ability_double = true;
                array_push(
                    game_state.event_log,
                    "Galactic Federation HQ will double the next GF Character ability paid by exhaustion."
                );
                return true;

            case "space_pirate_payment":
                var _payment_player = 1 - _source.controller;
                pending_choice = {
                    kind: "space_pirate_payment",
                    source: _source,
                    owner_index: _source.controller,
                    payer_index: _payment_player,
                    prompt: game_state.players[_payment_player].name
                        + ": pay 1 CP, or allow a Space Pirate Character to ready?"
                };
                game_state.priority_player = _payment_player;
                return true;

            case "ready_ship":
                var _ready_target = _target;
                _ready_target.ready = true;
                if (game_state.players[_source.controller].is_ai) {
                    _ready_target.ai_readied_by_effect_this_turn = true;
                }
                array_push(
                    game_state.event_log,
                    _source.definition.name + " readied "
                    + _ready_target.definition.name + "."
                );
                return true;

            case "ship_security_1":
                var _security_target = _target;
                _security_target.temporary_stat_bonus += 1;
                array_push(
                    game_state.event_log,
                    _security_target.definition.name
                    + " gained +1 Security this turn."
                );
                return true;

            case "ship_security_2":
                var _security_target_2 = _target;
                _security_target_2.temporary_stat_bonus += 2;
                array_push(
                    game_state.event_log,
                    _security_target_2.definition.name
                    + " gained +2 Security this turn."
                );
                return true;

            case "raid_defense_1":
                if (is_undefined(pending_choice)
                || pending_choice.kind != "raid"
                || pending_choice.stage != "defenders") {
                    return false;
                }
                pending_choice.defender_ability_bonus += 1;
                array_push(
                    game_state.event_log,
                    _source.definition.name
                    + " added +1 Strength to the raid defense."
                );
                return true;

            case "quiet_robe_place":
                pending_choice = {
                    kind: "quiet_robe_metroids",
                    source: _source,
                    ship: _target,
                    selected_hazard: 0,
                    remaining: 2,
                    prompt: "Quiet Robe: select two Metroids whose combined Hazard does not exceed "
                        + string(get_card_stat(_target)) + "."
                };
                return true;

            case "exhaust_card":
                _target.ready = false;
                array_push(
                    game_state.event_log,
                    _source.definition.name + " exhausted "
                    + _target.definition.name + "."
                );
                if (card_discards_from_phazon(_target)) {
                    var _exhausted_discard_name = _target.definition.name;
                    remove_ability_source(
                        _target_kind,
                        _target_index,
                        _target,
                        false
                    );
                    array_push(
                        game_state.event_log,
                        _exhausted_discard_name
                            + " was discarded after being exhausted while corrupted."
                    );
                }
                return true;

            case "discard_card":
                var _discarded_name = _target.definition.name;
                remove_ability_source(
                    _target_kind,
                    _target_index,
                    _target,
                    false
                );
                array_push(
                    game_state.event_log,
                    _source.definition.name + " discarded " + _discarded_name + "."
                );
                return true;

            case "dark_samus_discard":
                if (_source.zone == "board") {
                    _source.phazon_tokens = 0;
                }
                var _dark_target_name = _target.definition.name;
                remove_ability_source(
                    _target_kind,
                    _target_index,
                    _target,
                    false
                );
                array_push(
                    game_state.event_log,
                    "Dark Samus removed " + string(_ability.phazon_spent)
                    + " Phazon token(s) and discarded " + _dark_target_name + "."
                );
                return true;

            case "dark_samus_consolidate":
                _target.phazon_tokens -= 1;
                _source.phazon_tokens += 1;
                array_push(
                    game_state.event_log,
                    "Dark Samus moved 1 Phazon token from "
                    + _target.definition.name + " to herself."
                );
                return true;

            case "corrupt_copy":
                var _copied_definition_id = _target.definition_id;
                var _copied_definition = _target.definition;
                _target.phazon_tokens += 1;
                array_push(
                    game_state.event_log,
                    _target.definition.name
                        + " gained 1 Phazon token from Corrupt Gandrayda ("
                        + string(_target.phazon_tokens) + " total)."
                );
                _target.ready = false;
                if (card_discards_from_phazon(_target)) {
                    var _corrupt_copy_discard_name = _target.definition.name;
                    remove_ability_source(
                        _target_kind,
                        _target_index,
                        _target,
                        false
                    );
                    array_push(
                        game_state.event_log,
                        _corrupt_copy_discard_name
                            + " was discarded after Corrupt Gandrayda exhausted it while corrupted."
                    );
                }
                _source.definition_id = _copied_definition_id;
                _source.definition = _copied_definition;
                _source.copy_until_end_turn = false;
                array_push(
                    game_state.event_log,
                    "Corrupt Gandrayda exhausted and copied "
                    + _copied_definition.name + "."
                );
                return true;

            case "attach_source":
                if (!move_source_to_attachment(
                    pending_ability_source_kind,
                    pending_ability_source_index,
                    _source,
                    _target
                )) {
                    array_push(
                        game_state.event_log,
                        _source.definition.name
                        + " could not attach because it left play."
                    );
                    return false;
                }
                array_push(
                    game_state.event_log,
                    _source.definition.name + " attached to "
                    + _target.definition.name + "."
                );
                return true;

            case "attach_choose_faction":
                if (!move_source_to_attachment(
                    pending_ability_source_kind,
                    pending_ability_source_index,
                    _source,
                    _target
                )) {
                    return false;
                }
                pending_choice = {
                    kind: "choose_faction",
                    host: _target,
                    prompt: "Choose the faction Body Adaptation Machine grants."
                };
                return true;

            case "leviathan_attach":
                if (!move_source_to_attachment(
                    pending_ability_source_kind,
                    pending_ability_source_index,
                    _source,
                    _target
                )) {
                    return false;
                }
                _target.phazon_tokens += 1;
                array_push(
                    game_state.event_log,
                    "Leviathan attached to " + _target.definition.name
                    + " and gave it a Phazon token."
                );
                return true;

            case "ped_strength":
                var _spent_phazon = _source.phazon_tokens;
                _source.phazon_tokens = 0;
                _source.temporary_stat_bonus += _spent_phazon;
                array_push(
                    game_state.event_log,
                    _source.definition.name + " removed "
                    + string(_spent_phazon)
                    + " Phazon token(s) for +" + string(_spent_phazon)
                    + " Strength this turn."
                );
                return true;

            case "corrupt_all":
                for (var _corrupt_player_index = 0;
                     _corrupt_player_index < 2;
                     _corrupt_player_index++) {
                    var _corrupt_player = game_state.players[_corrupt_player_index];
                    var _corrupt_zones = [
                        _corrupt_player.board.characters,
                        _corrupt_player.board.ships
                    ];
                    for (var _corrupt_zone_index = 0;
                         _corrupt_zone_index < 2;
                         _corrupt_zone_index++) {
                        for (var _corrupt_card_index = 0;
                             _corrupt_card_index
                                < array_length(
                                    _corrupt_zones[_corrupt_zone_index]
                                );
                             _corrupt_card_index++) {
                            var _corrupted_card = _corrupt_zones[
                                _corrupt_zone_index
                            ][_corrupt_card_index];
                            _corrupted_card.phazon_tokens += 3;
                            array_push(
                                game_state.event_log,
                                _corrupted_card.definition.name
                                    + " gained 3 Phazon tokens from Aurora Unit 217 ("
                                    + string(_corrupted_card.phazon_tokens)
                                    + " total)."
                            );
                        }
                    }
                }
                array_push(
                    game_state.event_log,
                    "Aurora Unit 217 gave every Ship and Character 3 Phazon tokens."
                );
                return true;

            case "deploy_shop_ship":
                var _shop_ship = game_state.shop_row[_target_index];
                array_delete(game_state.shop_row, _target_index, 1);
                _shop_ship.owner = game_state.active_player;
                _shop_ship.controller = game_state.active_player;
                put_card_in_play(_player, _shop_ship);
                refill_shop();
                array_push(
                    game_state.event_log,
                    _source.definition.name + " deployed "
                    + _shop_ship.definition.name + " from the Shop for free."
                );
                return true;

            case "reserve_shop_event_free":
                var _reserving_player =
                    game_state.players[game_state.priority_player];
                var _event_card = game_state.shop_row[_target_index];
                array_delete(game_state.shop_row, _target_index, 1);
                _event_card.owner = _reserving_player.index;
                _event_card.controller = _reserving_player.index;
                clear_card_board_state(_event_card);
                _event_card.zone = "discard";
                array_push(_reserving_player.discard, _event_card);
                refill_shop();
                array_push(
                    game_state.event_log,
                    _reserving_player.name + " used Biologic Space Laboratories to reserve "
                    + _event_card.definition.name + " without its Reserve cost."
                );
                return true;
        }
        return false;
    };

    activate_selected_ability = function(
        _source_kind,
        _source_index,
        _ability_index
    ) {
        if (!can_activate_selected_ability(
            _source_kind,
            _source_index,
            _ability_index
        )) {
            log_action_failure("That activated ability cannot be used now.");
            return false;
        }

        var _source = get_ability_source(_source_kind, _source_index);
        var _source_abilities = get_activated_abilities(_source);
        var _ability = _source_abilities[_ability_index];
        if (_ability.target_kind != "") {
            pending_choice = {
                kind: "ability_target",
                source_kind: _source_kind,
                source_index: _source_index,
                source: _source,
                ability: _ability,
                target_kind: _ability.target_kind,
                prompt: _ability.prompt,
                multi_select: _ability.effect_kind == "dark_samus_discard",
                selected_targets: [],
                selected_strength: 0,
                selected_pz_bonus: 0
            };
            return true;
        }

        var _resolution_count = consume_activation_modifiers(_source, _ability);
        pay_activated_ability_cost(
            _source_kind,
            _source_index,
            _source,
            _ability
        );
        pending_ability_source_kind = _source_kind;
        pending_ability_source_index = _source_index;
        var _resolved = false;
        for (var _resolution_index = 0;
             _resolution_index < _resolution_count;
             _resolution_index++) {
            _resolved = resolve_activated_ability(_source, _ability, "", -1)
                || _resolved;
        }
        return _resolved;
    };

    can_resolve_ability_target = function(_choice, _target_kind, _target_index) {
        var _target = get_ability_target_card(_target_kind, _target_index);
        if (_choice.target_kind == "ship") {
            return !is_undefined(_target)
                && _target.definition.type == "ship"
                && _target.controller == _choice.source.controller;
        }
        if (_choice.target_kind == "ready_ship") {
            return !is_undefined(_target)
                && _target.definition.type == "ship"
                && _target.controller == _choice.source.controller
                && _target.ready
                && (_choice.ability.effect_kind != "quiet_robe_place"
                    || quiet_robe_pair_exists(_target));
        }
        if (_choice.target_kind == "shop_ship") {
            return _target_kind == "shop"
                && _target_index >= 0
                && _target_index < array_length(game_state.shop_row)
                && game_state.shop_row[_target_index].definition.type == "ship";
        }
        if (_choice.target_kind == "shop_event") {
            return _target_kind == "shop"
                && _target_index >= 0
                && _target_index < array_length(game_state.shop_row)
                && game_state.shop_row[_target_index].definition.type == "event";
        }
        if (_choice.target_kind == "any_ship") {
            return (_target_kind == "ship"
                || _target_kind == "opponent_ship")
                && !is_undefined(_target);
        }
        if (_choice.target_kind == "any_character") {
            return (_target_kind == "character"
                || _target_kind == "opponent_character")
                && !is_undefined(_target);
        }
        if (_choice.target_kind == "dark_samus_character") {
            if ((_target_kind != "character"
            && _target_kind != "opponent_character")
            || is_undefined(_target)) {
                return false;
            }
            if (variable_struct_exists(_choice, "multi_select")
            && _choice.multi_select) {
                if (raid_array_contains(
                    _choice.selected_targets,
                    _target.instance_id
                )) return true;
                var _prospective_budget = _choice.source.phazon_tokens
                    + _choice.selected_pz_bonus
                    + ((card_has_faction(_target, "PZ")
                        && _target.instance_id != _choice.source.instance_id)
                        ? 1 : 0);
                return _choice.selected_strength + get_card_stat(_target)
                    <= _prospective_budget;
            }
            var _dark_samus_tokens = _choice.source.phazon_tokens
                + (card_has_faction(_target, "PZ") ? 1 : 0);
            return get_card_stat(_target) <= _dark_samus_tokens;
        }
        if (_choice.target_kind == "own_phazon_source") {
            return !is_undefined(_target)
                && _target.controller == _choice.source.controller
                && _target.instance_id != _choice.source.instance_id
                && _target.phazon_tokens > 0;
        }
        if (_choice.target_kind == "any_location") {
            return (_target_kind == "location"
                || _target_kind == "opponent_location")
                && !is_undefined(_target);
        }
        if (_choice.target_kind == "another_character") {
            return (_target_kind == "character"
                || _target_kind == "opponent_character")
                && !is_undefined(_target)
                && _target.instance_id != _choice.source.instance_id;
        }
        if (_choice.target_kind == "own_other_character") {
            return !is_undefined(_target)
                && _target.definition.type == "character"
                && _target.controller == _choice.source.controller
                && _target.instance_id != _choice.source.instance_id;
        }
        if (_choice.target_kind == "another_permanent") {
            return (_target_kind == "character"
                || _target_kind == "ship"
                || _target_kind == "location"
                || _target_kind == "opponent_character"
                || _target_kind == "opponent_ship"
                || _target_kind == "opponent_location")
                && !is_undefined(_target)
                && _target.instance_id != _choice.source.instance_id;
        }
        if (_choice.target_kind == "opponent_permanent") {
            return !is_undefined(_target)
                && _target.controller != _choice.source.controller;
        }
        return false;
    };

    toggle_dark_samus_discard_target = function(_target_kind, _target_index) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "ability_target"
        || !pending_choice.multi_select
        || !can_resolve_ability_target(
            pending_choice,
            _target_kind,
            _target_index
        )) return false;
        var _target = get_ability_target_card(_target_kind, _target_index);
        var _selected_position = -1;
        for (var _selected_index = 0;
             _selected_index < array_length(pending_choice.selected_targets);
             _selected_index++) {
            if (pending_choice.selected_targets[_selected_index]
            == _target.instance_id) {
                _selected_position = _selected_index;
                break;
            }
        }
        var _strength = get_card_stat(_target);
        var _adds_source_phazon = card_has_faction(_target, "PZ")
            && _target.instance_id != pending_choice.source.instance_id;
        if (_selected_position >= 0) {
            array_delete(
                pending_choice.selected_targets,
                _selected_position,
                1
            );
            pending_choice.selected_strength -= _strength;
            if (_adds_source_phazon) pending_choice.selected_pz_bonus -= 1;
        } else {
            array_push(pending_choice.selected_targets, _target.instance_id);
            pending_choice.selected_strength += _strength;
            if (_adds_source_phazon) pending_choice.selected_pz_bonus += 1;
        }
        return true;
    };

    confirm_dark_samus_discard = function() {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "ability_target"
        || !pending_choice.multi_select
        || array_length(pending_choice.selected_targets) <= 0) {
            return false;
        }
        var _choice = pending_choice;
        var _targets = [];
        for (var _player_index = 0; _player_index < 2; _player_index++) {
            var _characters = game_state.players[_player_index].board.characters;
            for (var _character_index = 0;
                 _character_index < array_length(_characters);
                 _character_index++) {
                var _character = _characters[_character_index];
                if (raid_array_contains(
                    _choice.selected_targets,
                    _character.instance_id
                )) array_push(_targets, _character);
            }
        }
        if (array_length(_targets) <= 0) return false;
        for (var _interaction_index = 0;
             _interaction_index < array_length(_targets);
             _interaction_index++) {
            if (_targets[_interaction_index].instance_id
            != _choice.source.instance_id) {
                apply_phazon_interaction(
                    _choice.source,
                    _targets[_interaction_index]
                );
            }
        }
        var _tokens_removed = _choice.source.phazon_tokens;
        if (_choice.selected_strength > _tokens_removed) return false;
        consume_activation_modifiers(_choice.source, _choice.ability);
        pay_activated_ability_cost(
            _choice.source_kind,
            _choice.source_index,
            _choice.source,
            _choice.ability
        );
        if (_choice.source.zone == "board") {
            _choice.source.phazon_tokens = 0;
        }
        var _discarded_names = "";
        for (var _discard_player_index = 0;
             _discard_player_index < 2;
             _discard_player_index++) {
            var _discard_characters = game_state.players[
                _discard_player_index
            ].board.characters;
            for (var _discard_index = array_length(_discard_characters) - 1;
                 _discard_index >= 0;
                 _discard_index--) {
                var _discard_target = _discard_characters[_discard_index];
                if (!raid_array_contains(
                    _choice.selected_targets,
                    _discard_target.instance_id
                )) continue;
                _discarded_names += (_discarded_names == "" ? "" : ", ")
                    + _discard_target.definition.name;
                remove_ability_source(
                    _discard_player_index == game_state.active_player
                        ? "character" : "opponent_character",
                    _discard_index,
                    _discard_target,
                    false
                );
            }
        }
        array_push(
            game_state.event_log,
            "Dark Samus removed " + string(_tokens_removed)
            + " Phazon token(s) and discarded " + _discarded_names + "."
        );
        pending_choice = undefined;
        ui_selected_kind = "";
        ui_selected_index = -1;
        return true;
    };

    resolve_ability_target_choice = function(_target_kind, _target_index) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "ability_target") {
            return false;
        }
        var _choice = pending_choice;
        if (variable_struct_exists(_choice, "multi_select")
        && _choice.multi_select) {
            return toggle_dark_samus_discard_target(
                _target_kind,
                _target_index
            );
        }
        if (!can_resolve_ability_target(
            _choice,
            _target_kind,
            _target_index
        )) {
            return false;
        }

        var _target = get_ability_target_card(_target_kind, _target_index);
        if (!presentation_target_effect_committing
        && !debug_headless_to_game_over_active
        && game_state.game_mode != "batch"
        && game_state.game_mode != "network"
        && game_state.game_mode != "regression") {
            presentation_target_effect = {
                source: _choice.source,
                target: _target,
                target_kind: _target_kind,
                target_index: _target_index,
                started_at_ms: current_time,
                resolve_at_ms: current_time + 440
            };
            return true;
        }
        if (_choice.ability.effect_kind != "dark_samus_consolidate") {
            apply_phazon_interaction(_choice.source, _target);
        }
        if (_choice.ability.effect_kind == "dark_samus_discard") {
            _choice.ability.phazon_spent = _choice.source.phazon_tokens;
        }
        var _resolution_count = consume_activation_modifiers(
            _choice.source,
            _choice.ability
        );
        var _resolved_target_index = _target_index;
        var _source_leaves_zone = _choice.ability.cost_destroy
            || (_choice.ability.cost_exhaust
                && card_discards_from_phazon(_choice.source));
        if (_source_leaves_zone
        && _choice.source_kind == _target_kind
        && _choice.source_index < _target_index) {
            // Removing the source shifts all later cards in the same board array.
            _resolved_target_index -= 1;
        }
        pay_activated_ability_cost(
            _choice.source_kind,
            _choice.source_index,
            _choice.source,
            _choice.ability
        );
        pending_ability_source_kind = _choice.source_kind;
        pending_ability_source_index = _choice.source_index;
        pending_choice = undefined;
        var _resolved = false;
        for (var _resolution_index = 0;
             _resolution_index < _resolution_count;
             _resolution_index++) {
            _resolved = resolve_activated_ability(
                _choice.source,
                _choice.ability,
                _target_kind,
                _resolved_target_index
            ) || _resolved;
        }
        return _resolved;
    };

    resolve_space_pirate_payment = function(_pay) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "space_pirate_payment") {
            return false;
        }
        var _choice = pending_choice;
        var _payer = game_state.players[_choice.payer_index];
        if (_pay && _payer.command_points >= 1) {
            _payer.command_points -= 1;
            pending_choice = undefined;
            game_state.priority_player = game_state.active_player;
            array_push(
                game_state.event_log,
                _payer.name + " paid 1 CP to Space Pirate Homeworld."
            );
            return true;
        }

        var _owner = game_state.players[_choice.owner_index];
        var _has_target = false;
        for (var _pirate_index = 0;
             _pirate_index < array_length(_owner.board.characters);
             _pirate_index++) {
            var _pirate = _owner.board.characters[_pirate_index];
            if (!_pirate.ready && card_has_faction(_pirate, "SP")) {
                _has_target = true;
                break;
            }
        }
        game_state.priority_player = _choice.owner_index;
        if (_has_target) {
            pending_choice = {
                kind: "space_pirate_ready",
                owner_index: _choice.owner_index,
                prompt: "Select one exhausted Space Pirate Character to ready."
            };
        } else {
            pending_choice = undefined;
            game_state.priority_player = game_state.active_player;
            array_push(
                game_state.event_log,
                "Space Pirate Homeworld had no eligible Character to ready."
            );
        }
        return true;
    };

    resolve_space_pirate_ready = function(_target_kind, _target_index) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "space_pirate_ready") {
            return false;
        }
        var _choice = pending_choice;
        var _expected_kind = _choice.owner_index == game_state.active_player
            ? "character"
            : "opponent_character";
        if (_target_kind != _expected_kind) {
            return false;
        }
        var _target = get_ability_target_card(_target_kind, _target_index);
        if (is_undefined(_target)
        || _target.ready
        || !card_has_faction(_target, "SP")) {
            return false;
        }
        _target.ready = true;
        pending_choice = undefined;
        game_state.priority_player = game_state.active_player;
        array_push(
            game_state.event_log,
            "Space Pirate Homeworld readied " + _target.definition.name + "."
        );
        return true;
    };

    resolve_faction_choice = function(_faction) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "choose_faction") {
            return false;
        }
        if (_faction != "GF"
        && _faction != "SP"
        && _faction != "CZ"
        && _faction != "BH"
        && _faction != "PZ") {
            return false;
        }
        var _host = pending_choice.host;
        for (var _attachment_index = array_length(_host.attachments) - 1;
             _attachment_index >= 0;
             _attachment_index--) {
            var _attachment = _host.attachments[_attachment_index];
            if (_attachment.printed_definition_id
            == "loc.body_adaptation_machine"
            && _attachment.granted_faction == "") {
                _attachment.granted_faction = _faction;
                break;
            }
        }
        pending_choice = undefined;
        array_push(
            game_state.event_log,
            "Body Adaptation Machine granted " + _host.definition.name
            + " the " + _faction + " faction."
        );
        return true;
    };

}

