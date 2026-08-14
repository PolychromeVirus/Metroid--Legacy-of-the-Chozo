function loc_rules() {
    card_has_faction = function(_card, _faction) {
        for (var _faction_index = 0;
             _faction_index < array_length(_card.definition.factions);
             _faction_index++) {
            if (_card.definition.factions[_faction_index] == _faction) {
                return true;
            }
        }
        for (var _granted_faction_index = 0;
             _granted_faction_index < array_length(_card.granted_factions);
             _granted_faction_index++) {
            if (_card.granted_factions[_granted_faction_index] == _faction) {
                return true;
            }
        }
        for (var _faction_attachment_index = 0;
             _faction_attachment_index < array_length(_card.attachments);
             _faction_attachment_index++) {
            var _faction_attachment = _card.attachments[_faction_attachment_index];
            if (_faction_attachment.printed_definition_id
            == "loc.body_adaptation_machine"
            && _faction_attachment.granted_faction == _faction) {
                return true;
            }
        }
        if (_faction == "PZ") {
            for (var _attachment_index = 0;
                 _attachment_index < array_length(_card.attachments);
                 _attachment_index++) {
                if (_card.attachments[_attachment_index].definition_id
                == "lop.aurora_unit_217") {
                    return true;
                }
            }
        }
        return false;
    };

    // AI archetypes are deliberately separate from printed faction tags. They let
    // off-faction support cards participate in a focused acquisition strategy
    // without changing any rules-facing identity, interaction, or presentation.
    ai_archetypes_by_id = {};
    variable_struct_set(
        ai_archetypes_by_id,
        "lop.p_e_d_suit",
        ["PZ"]
    );

    card_matches_ai_profile = function(_card, _profile) {
        if (_profile == "") {
            return false;
        }
        if (card_has_faction(_card, _profile)) {
            return true;
        }
        if (is_undefined(_card)
        || !variable_struct_exists(_card, "definition_id")
        || !variable_struct_exists(ai_archetypes_by_id, _card.definition_id)) {
            return false;
        }
        var _archetypes = variable_struct_get(
            ai_archetypes_by_id,
            _card.definition_id
        );
        for (var _archetype_index = 0;
             _archetype_index < array_length(_archetypes);
             _archetype_index++) {
            if (_archetypes[_archetype_index] == _profile) {
                return true;
            }
        }
        return false;
    };

    card_is_in_play = function(_card) {
        return !is_undefined(_card)
            && (_card.zone == "board" || _card.zone == "attachment");
    };

    apply_phazon_interaction = function(_source, _target) {
        if (is_undefined(_source) || is_undefined(_target)) {
            return;
        }
        var _source_is_phazon = card_has_faction(_source, "PZ");
        var _target_is_phazon = card_has_faction(_target, "PZ");
        if (_source_is_phazon && card_is_in_play(_target)) {
            _target.phazon_tokens += 1;
            array_push(
                game_state.event_log,
                _target.definition.name
                + " gained a Phazon token from interacting with "
                + _source.definition.name + "."
            );
        }
        if (_target_is_phazon && card_is_in_play(_source)) {
            _source.phazon_tokens += 1;
            array_push(
                game_state.event_log,
                _source.definition.name
                + " gained a Phazon token from interacting with "
                + _target.definition.name + "."
            );
        }
        if (((_source_is_phazon && card_is_in_play(_target))
        || (_target_is_phazon && card_is_in_play(_source)))
        && (guidance_is_local_player(_source.controller)
            || guidance_is_local_player(_target.controller))) {
            queue_first_game_guidance(
                "phazon", "PHAZON CORRUPTION",
                "Most cards are discarded when they exhaust with at least three Phazon tokens. The paid effect still resolves after the card is discarded."
            );
        }
    };

    count_ready_faction_cards = function(_player, _faction) {
        var _count = 0;
        var _zones = [
            _player.board.characters,
            _player.board.ships,
            _player.board.locations
        ];
        for (var _zone_index = 0; _zone_index < 3; _zone_index++) {
            for (var _card_index = 0;
                 _card_index < array_length(_zones[_zone_index]);
                 _card_index++) {
                var _card = _zones[_zone_index][_card_index];
                if (_card.ready && card_has_faction(_card, _faction)) {
                    _count += 1;
                }
            }
        }
        return _count;
    };

    count_ready_faction_characters = function(_player, _faction) {
        var _count = 0;
        for (var _card_index = 0;
             _card_index < array_length(_player.board.characters);
             _card_index++) {
            var _card = _player.board.characters[_card_index];
            if (_card.ready && card_has_faction(_card, _faction)) {
                _count += 1;
            }
        }
        return _count;
    };

    get_latest_lab_research = function(_player) {
        var _latest_stage = -1;
        var _latest_research = 0;
        for (var _lab_index = 0;
             _lab_index < array_length(_player.lab);
             _lab_index++) {
            var _metroid = _player.lab[_lab_index];
            if (_metroid.definition.stage > _latest_stage) {
                _latest_stage = _metroid.definition.stage;
                _latest_research = _metroid.definition.research_value;
            }
        }
        return ceil(_latest_research);
    };

    get_card_stat = function(_card, _context = "") {
        var _uses_dynamic_stat = _card.definition_id == "loc.mother_brain"
            || _card.definition_id == "loc.zebesian_pirate"
            || _card.definition_id == "lop.corrupt_rundas";
        if (!variable_struct_exists(_card.definition, "stat")
        || is_undefined(_card.definition.stat)
        || (!is_real(_card.definition.stat.value) && !_uses_dynamic_stat)) {
            return 0;
        }
        var _attachment_bonus = 0;
        for (var _attachment_index = 0;
             _attachment_index < array_length(_card.attachments);
             _attachment_index++) {
            if (_card.attachments[_attachment_index].definition_id
            == "lop.aurora_unit_217") {
                _attachment_bonus += 1;
            }
        }
        var _base_stat = _uses_dynamic_stat
            ? 0
            : _card.definition.stat.value;
        var _controller_index = _card.controller >= 0
            ? _card.controller
            : game_state.active_player;
        var _controller = game_state.players[_controller_index];
        if (_card.definition_id == "loc.mother_brain") {
            _base_stat = get_latest_lab_research(_controller);
        } else if (_card.definition_id == "loc.zebesian_pirate") {
            _base_stat = count_ready_faction_cards(_controller, "SP");
        } else if (_card.definition_id == "lop.corrupt_rundas") {
            _base_stat = _card.phazon_tokens;
        }

        var _conditional_bonus = 0;
        if (_card.definition_id == "loc.beam_pirate"
        && _context == "containment_character") {
            _conditional_bonus += 1;
        }
        if (_card.definition_id == "loc.armoured_frigate"
        && (!_card.ready || _context == "containment_ship")) {
            _conditional_bonus += 2;
        }
        if (_card.definition_id == "loc.attack_vessel"
        && _context == "raid_attacker_ship") {
            _conditional_bonus += 2;
        }
        if (_card.definition_id == "loc.delano_7"
        && _context == "containment_ship") {
            _conditional_bonus += 2;
        }

        return _base_stat
            + _card.temporary_stat_bonus
            + _attachment_bonus
            + _conditional_bonus;
    };

    get_lab_metroid_hazard = function(_player, _metroid) {
        var _old_bird_active = false;
        for (var _character_index = 0;
             _character_index < array_length(_player.board.characters);
             _character_index++) {
            if (_player.board.characters[_character_index].definition_id
            == "loc.old_bird") {
                _old_bird_active = true;
                break;
            }
        }
        return _old_bird_active ? 3 : _metroid.definition.hazard;
    };

    get_lab_hazard = function(_player) {
        var _hazard = 0;
        for (var _i = 0; _i < array_length(_player.lab); _i++) {
            _hazard += get_lab_metroid_hazard(_player, _player.lab[_i]);
        }
        return _hazard;
    };

    get_display_lab_hazard = function(_player) {
        var _hazard = get_lab_hazard(_player);
        if (array_length(_player.lab) <= 0) return _hazard;

        if (!is_undefined(containment_resolution)
        && containment_resolution.player_index == _player.index) {
            return _hazard + containment_resolution.bonus_hazard;
        }

        if (!is_undefined(special_containment_sequence)
        && special_containment_sequence.index >= 0
        && special_containment_sequence.index
            < array_length(special_containment_sequence.entries)) {
            var _display_entry = special_containment_sequence.entries[
                special_containment_sequence.index
            ];
            if (_display_entry.player_index == _player.index) {
                return _hazard + _display_entry.bonus_hazard;
            }
        }
        return _hazard;
    };

    get_ready_character_strength = function(_player) {
        var _strength = 0;
        var _characters = _player.board.characters;
        for (var _i = 0; _i < array_length(_characters); _i++) {
            if (_characters[_i].ready) {
                _strength += get_card_stat(
                    _characters[_i],
                    "containment_character"
                );
            }
        }
        return _strength;
    };

    find_best_ready_ship = function(_player) {
        var _best_index = -1;
        var _best_security = -1;
        var _ships = _player.board.ships;
        for (var _i = 0; _i < array_length(_ships); _i++) {
            if (_ships[_i].ready) {
                var _security = get_card_stat(_ships[_i], "containment_ship");
                if (_security > _best_security) {
                    _best_security = _security;
                    _best_index = _i;
                }
            }
        }
        return _best_index;
    };

    discard_character_for_player = function(_player, _reason) {
        var _characters = _player.board.characters;
        if (array_length(_characters) <= 0) {
            array_push(
                game_state.event_log,
                _player.name + " had no Character to discard for " + _reason + "."
            );
            return;
        }

        // The owner chooses. The debug controller currently chooses the last Character.
        var _character = array_pop(_characters);
        clear_card_board_state(_character);
        _character.zone = "discard";
        array_push(_player.discard, _character);
        array_push(
            game_state.event_log,
            _player.name + " discarded " + _character.definition.name
            + " for " + _reason + "."
        );
    };

    resolve_metroid_breach = function(
        _player, _lab_index, _defer_character, _from_containment
    ) {
        var _metroid = _player.lab[_lab_index];
        if (_player.prevent_next_breach) {
            _player.prevent_next_breach = false;
            array_push(
                game_state.event_log,
                "Adam Malkovich prevented " + _metroid.definition.name
                + " from breaching."
            );
            return false;
        }
        array_delete(_player.lab, _lab_index, 1);
        _metroid.zone = "supply";
        queue_breach_presentation(_metroid, _player.index);
        array_push(
            game_state.event_log,
            _player.name + "'s " + _metroid.definition.name + " breached."
        );
        _player.telemetry.breaches += 1;

        if (_metroid.definition.id == "metroid.hunter") {
            for (var _i = 0;
                 _i < array_length(_player.board.characters);
                 _i++) {
                _player.board.characters[_i].phazon_tokens += 1;
                array_push(
                    game_state.event_log,
                    _player.board.characters[_i].definition.name
                        + " gained 1 Phazon token from a Hunter breach ("
                        + string(_player.board.characters[_i].phazon_tokens)
                        + " total)."
                );
            }
            array_push(
                game_state.event_log,
                "Hunter breach gave each of " + _player.name
                + "'s Characters a Phazon token."
            );
        }

        if (!is_undefined(_from_containment)
        && _from_containment
        && settings_experimental_breaching_mutation) {
            array_push(
                game_state.event_log,
                "Breaching Mutation caused a Mutation roll."
            );
            resolve_mutation_roll();
        }

        if (is_undefined(_defer_character) || !_defer_character) {
            discard_character_for_player(_player, "a breach");
            release_breach_presentation(
                presentation_last_breach_instance_id
            );
        }
        return true;
    };

    find_next_breaching_metroid = function(_player) {
        // Hunters always breach before normal stages.
        for (var _hunter_index = 0;
             _hunter_index < array_length(_player.lab);
             _hunter_index++) {
            if (_player.lab[_hunter_index].definition.id == "metroid.hunter") {
                return _hunter_index;
            }
        }

        var _best_index = -1;
        var _best_stage = -1;
        for (var _i = 0; _i < array_length(_player.lab); _i++) {
            var _stage = _player.lab[_i].definition.stage;
            if (is_real(_stage) && _stage > _best_stage) {
                _best_stage = _stage;
                _best_index = _i;
            }
        }
        return _best_index;
    };

    resolve_containment_for_player = function(
        _player_index,
        _bonus_hazard,
        _chosen_ship_index,
        _forced_breach
    ) {
        var _player = game_state.players[_player_index];
        var _character_strength = get_ready_character_strength(_player);
        var _hazard = get_lab_hazard(_player);
        if (array_length(_player.lab) > 0) {
            _hazard += _bonus_hazard;
        }
        var _has_omega = false;
        var _breach_count = 0;

        for (var _i = 0; _i < array_length(_player.lab); _i++) {
            if (_player.lab[_i].definition.id == "metroid.omega") {
                _has_omega = true;
                break;
            }
        }

        var _ship_index = -1;
        if (!is_undefined(_chosen_ship_index)) {
            if (_chosen_ship_index >= 0
            && _chosen_ship_index < array_length(_player.board.ships)
            && _player.board.ships[_chosen_ship_index].ready) {
                _ship_index = _chosen_ship_index;
            }
        } else if (_has_omega || _hazard > _character_strength) {
            // Non-turn procedures such as Queen currently use the best legal Ship.
            _ship_index = find_best_ready_ship(_player);
        }

        var _ship_security = 0;
        if (_ship_index >= 0) {
            var _ship = _player.board.ships[_ship_index];
            _ship.ready = false;
            _ship.used_for_containment_this_turn = true;
            _ship_security = get_card_stat(_ship, "containment_ship");
            if (_ship.definition_id == "loc.g_f_s_olympus") {
                for (var _character_index = 0;
                     _character_index < array_length(_player.board.characters);
                     _character_index++) {
                    var _character = _player.board.characters[_character_index];
                    if (!_character.ready
                    && card_has_faction(_character, "GF")) {
                        _character.ready = true;
                        array_push(
                            game_state.event_log,
                            "G.F.S. Olympus readied "
                            + _character.definition.name + "."
                        );
                        break;
                    }
                }
            }
            array_push(
                game_state.event_log,
                _player.name + " exhausted " + _ship.definition.name
                + " for " + string(_ship_security) + " containment Security."
            );
            if (card_discards_from_phazon(_ship)) {
                var _corrupted_containment_ship = _ship.definition.name;
                remove_ability_source(
                    _player_index == game_state.active_player
                        ? "ship"
                        : "opponent_ship",
                    _ship_index,
                    _ship,
                    false
                );
                array_push(
                    game_state.event_log,
                    _corrupted_containment_ship
                    + " was discarded after exhausting for containment."
                );
            }
        }

        if (!is_undefined(_forced_breach)
        && _forced_breach
        && array_length(_player.lab) > 0) {
            var _forced_index = find_next_breaching_metroid(_player);
            if (_forced_index >= 0
            && resolve_metroid_breach(
                _player, _forced_index, false, true
            )) {
                _breach_count += 1;
            }
        }

        if (_ship_index < 0) {
            // Every Omega is a distinct simultaneous breach instance.
            for (var _omega_index = array_length(_player.lab) - 1;
                 _omega_index >= 0;
                 _omega_index--) {
                if (_player.lab[_omega_index].definition.id == "metroid.omega") {
                    if (resolve_metroid_breach(
                        _player, _omega_index, false, true
                    )) {
                        _breach_count += 1;
                    }
                }
            }
        }

        var _containment_strength = get_ready_character_strength(_player)
            + _ship_security;
        var _effective_hazard = get_lab_hazard(_player);
        if (array_length(_player.lab) > 0) {
            _effective_hazard += _bonus_hazard;
        }
        if (_effective_hazard > _containment_strength
        && guidance_is_local_player(_player.index)) {
            queue_first_game_guidance(
                "breach", "CONTAINMENT FAILED",
                "Your Security did not contain the Hazard in your Lab. Metroids will breach one at a time until the sequence is complete."
            );
        }

        while (_effective_hazard > _containment_strength) {
            var _breach_index = find_next_breaching_metroid(_player);
            if (_breach_index < 0) {
                // Bonus Hazard can exceed containment after the Lab has emptied.
                if (array_length(_player.lab) > 0) {
                    array_push(
                        setup_errors,
                        "Containment failed but no valid Metroid could breach."
                    );
                }
                break;
            }
            if (!resolve_metroid_breach(
                _player, _breach_index, false, true
            )) {
                break;
            }
            _breach_count += 1;
            _containment_strength = get_ready_character_strength(_player)
                + _ship_security;
            _effective_hazard = get_lab_hazard(_player);
            if (array_length(_player.lab) > 0) {
                _effective_hazard += _bonus_hazard;
            }
        }

        if (_breach_count > 0) {
            var _guard_count = 0;
            for (var _guard_index = 0;
                 _guard_index < array_length(_player.board.characters);
                 _guard_index++) {
                if (_player.board.characters[_guard_index].definition_id
                == "loc.security_guard") {
                    _guard_count += 1;
                }
            }
            var _guard_cp = _guard_count * _breach_count;
            if (_guard_cp > 0) {
                _player.command_points += _guard_cp;
                telemetry_update_max_cp(_player);
                array_push(
                    game_state.event_log,
                    "Security Guard generated " + string(_guard_cp)
                    + " CP from contained breach instances."
                );
            }
        }

        array_push(
            game_state.event_log,
            _player.name + " passed containment at "
            + string(_containment_strength) + " Strength vs "
            + string(_effective_hazard) + " Hazard."
        );
    };

    finish_containment_sequence = function() {
        var _context = containment_resolution;
        var _player = game_state.players[_context.player_index];
        var _strength = get_ready_character_strength(_player)
            + _context.ship_security;
        var _hazard = get_lab_hazard(_player);
        if (array_length(_player.lab) > 0) {
            _hazard += _context.bonus_hazard;
        }
        if (_context.breach_count > 0) {
            var _guard_count = 0;
            for (var _guard_index = 0;
                 _guard_index < array_length(_player.board.characters);
                 _guard_index++) {
                if (_player.board.characters[_guard_index].definition_id
                == "loc.security_guard") {
                    _guard_count += 1;
                }
            }
            var _guard_cp = _guard_count * _context.breach_count;
            if (_guard_cp > 0) {
                _player.command_points += _guard_cp;
                telemetry_update_max_cp(_player);
                array_push(
                    game_state.event_log,
                    "Security Guard generated " + string(_guard_cp)
                    + " CP from contained breach instances."
                );
            }
        }
        array_push(
            game_state.event_log,
            _player.name + " passed containment at "
            + string(_strength) + " Strength vs "
            + string(_hazard) + " Hazard."
        );
        var _continuation = _context.continuation;
        containment_resolution = undefined;
        pending_choice = undefined;
        if (_continuation == "turn") {
            if (game_state.phase != "game_over") {
                game_state.phase = "gain_cp";
                resolve_gain_cp_phase();
                resolve_ready_phase();
            }
        } else if (_continuation == "special") {
            advance_special_containment();
        }
        return true;
    };

    continue_containment_sequence = function() {
        if (is_undefined(containment_resolution)) {
            return false;
        }
        var _context = containment_resolution;
        var _player = game_state.players[_context.player_index];
        var _containment_steps = 0;
        var _containment_step_limit = max(1, array_length(_player.lab) + 1);
        while (true) {
            _containment_steps += 1;
            if (_containment_steps > _containment_step_limit) {
                array_push(
                    setup_errors,
                    "Containment resolution stopped because it did not make progress."
                );
                return finish_containment_sequence();
            }
            var _breach_index = -1;
            if (_context.forced_breach
            && array_length(_player.lab) > 0) {
                _context.forced_breach = false;
                _breach_index = find_next_breaching_metroid(_player);
            } else if (!_context.ship_used) {
                for (var _omega_index = array_length(_player.lab) - 1;
                     _omega_index >= 0;
                     _omega_index--) {
                    if (_player.lab[_omega_index].definition_id
                    == "metroid.omega") {
                        _breach_index = _omega_index;
                        break;
                    }
                }
            }
            if (_breach_index < 0) {
                var _strength = get_ready_character_strength(_player)
                    + _context.ship_security;
                var _hazard = get_lab_hazard(_player);
                if (array_length(_player.lab) > 0) {
                    _hazard += _context.bonus_hazard;
                }
                if (_hazard > _strength) {
                    _breach_index = find_next_breaching_metroid(_player);
                }
            }
            if (_breach_index < 0) {
                return finish_containment_sequence();
            }

            if (guidance_is_local_player(_context.player_index)) {
                queue_first_game_guidance(
                    "breach", "CONTAINMENT FAILED",
                    "Your Security did not contain the Hazard in your Lab. Metroids will breach one at a time until the sequence is complete."
                );
            }

            if (!resolve_metroid_breach(
                _player, _breach_index, true, true
            )) {
                return finish_containment_sequence();
            }
            _context.breach_count += 1;
            if (array_length(_player.board.characters) <= 0) {
                array_push(
                    game_state.event_log,
                    _player.name
                        + " had no Character to discard for a breach."
                );
                release_breach_presentation(
                    presentation_last_breach_instance_id
                );
                continue;
            }
            game_state.priority_player = _context.player_index;
            pending_choice = {
                kind: "breach_character",
                player_index: _context.player_index,
                breach_instance_id: presentation_last_breach_instance_id,
                prompt: _player.name
                    + ": choose a Character to discard for the breach."
            };
            ui_selected_kind = "";
            ui_selected_index = -1;
            return true;
        }
    };

    resolve_breach_character_choice = function(_character_index) {
        if (!is_undefined(pending_choice)
        && pending_choice.kind == "breach_character"
        && variable_struct_exists(pending_choice, "gf_soldier_breach")
        && pending_choice.gf_soldier_breach) {
            return resolve_gf_soldier_breach_character(_character_index);
        }
        if (is_undefined(pending_choice)
        || pending_choice.kind != "breach_character"
        || is_undefined(containment_resolution)) {
            return false;
        }
        var _player_index = pending_choice.player_index;
        var _player = game_state.players[_player_index];
        if (_character_index < 0
        || _character_index >= array_length(_player.board.characters)) {
            return false;
        }
        var _character = _player.board.characters[_character_index];
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
            _player.name + " discarded " + _character.definition.name
            + " for a breach."
        );
        release_breach_presentation(pending_choice.breach_instance_id);
        pending_choice = undefined;
        return continue_containment_sequence();
    };

    resolve_olympus_ready_choice = function(_character_index) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "olympus_ready"
        || is_undefined(containment_resolution)) {
            return false;
        }
        var _player = game_state.players[pending_choice.player_index];
        if (_character_index < 0
        || _character_index >= array_length(_player.board.characters)) {
            return false;
        }
        var _character = _player.board.characters[_character_index];
        if (_character.ready || !card_has_faction(_character, "GF")) {
            return false;
        }
        _character.ready = true;
        array_push(
            game_state.event_log,
            "G.F.S. Olympus readied " + _character.definition.name + "."
        );
        pending_choice = undefined;
        return continue_containment_sequence();
    };

    begin_containment_sequence = function(
        _player_index,
        _bonus_hazard,
        _chosen_ship_index,
        _forced_breach,
        _continuation
    ) {
        var _player = game_state.players[_player_index];
        var _ship_index = -1;
        var _ship_security = 0;
        var _ship_used = false;
        var _ship = undefined;
        if (_chosen_ship_index >= 0
        && _chosen_ship_index < array_length(_player.board.ships)
            && _player.board.ships[_chosen_ship_index].ready) {
            _ship_index = _chosen_ship_index;
            _ship = _player.board.ships[_ship_index];
            _ship.ready = false;
            _ship.used_for_containment_this_turn = true;
            _ship_security = get_card_stat(_ship, "containment_ship");
            _ship_used = true;
            array_push(
                game_state.event_log,
                _player.name + " exhausted " + _ship.definition.name
                + " for " + string(_ship_security)
                + " containment Security."
            );
            if (card_discards_from_phazon(_ship)) {
                var _corrupted_ship_name = _ship.definition.name;
                remove_ability_source(
                    _player_index == game_state.active_player
                        ? "ship"
                        : "opponent_ship",
                    _ship_index,
                    _ship,
                    false
                );
                array_push(
                    game_state.event_log,
                    _corrupted_ship_name
                    + " was discarded after exhausting for containment."
                );
            }
        }
        containment_resolution = {
            player_index: _player_index,
            bonus_hazard: _bonus_hazard,
            ship_security: _ship_security,
            ship_used: _ship_used,
            forced_breach: !is_undefined(_forced_breach) && _forced_breach,
            breach_count: 0,
            continuation: _continuation
        };
        if (_ship_index >= 0
        && _ship.definition_id == "loc.g_f_s_olympus") {
            for (var _gf_index = 0;
                 _gf_index < array_length(_player.board.characters);
                 _gf_index++) {
                var _gf_character = _player.board.characters[_gf_index];
                if (!_gf_character.ready
                && card_has_faction(_gf_character, "GF")) {
                    game_state.priority_player = _player_index;
                    pending_choice = {
                        kind: "olympus_ready",
                        player_index: _player_index,
                        prompt: _player.name
                            + ": choose an exhausted GF Character to ready."
                    };
                    return true;
                }
            }
        }
        return continue_containment_sequence();
    };

    resolve_containment_phase = function() {
        return resolve_turn_containment(-1);
    };

    finish_turn_containment = function(_ship_index) {
        return begin_containment_sequence(
            game_state.active_player,
            0,
            _ship_index,
            false,
            "turn"
        );
    };

    skip_empty_lab_containment = function() {
        if (game_state.phase != "containment") {
            return false;
        }
        var _player = game_state.players[game_state.active_player];
        if (array_length(_player.lab) > 0) {
            return false;
        }
        array_push(
            game_state.event_log,
            _player.name + " skipped containment because their Lab is empty."
        );
        game_state.phase = "gain_cp";
        resolve_gain_cp_phase();
        resolve_ready_phase();
        return true;
    };

    advance_special_containment = function() {
        special_containment_sequence.index += 1;
        while (special_containment_sequence.index
            < array_length(special_containment_sequence.entries)
        && array_length(
            game_state.players[
                special_containment_sequence.entries[
                    special_containment_sequence.index
                ].player_index
            ].lab
        ) <= 0) {
            special_containment_sequence.index += 1;
        }
        if (special_containment_sequence.index
        >= array_length(special_containment_sequence.entries)) {
            var _continuation = special_containment_sequence.continuation;
            var _queen_shop_index = special_containment_sequence.queen_shop_index;
            special_containment_sequence = undefined;
            game_state.priority_player = game_state.active_player;
            if (_continuation == "queen") {
                finish_queen_containment_resolution(_queen_shop_index);
            } else {
                pending_choice = undefined;
                array_push(
                    game_state.event_log,
                    "SA-X Breaks Out containment finished for both players."
                );
            }
            return true;
        }

        var _entry = special_containment_sequence.entries[
            special_containment_sequence.index
        ];
        var _special_hazard = get_lab_hazard(
            game_state.players[_entry.player_index]
        );
        if (array_length(game_state.players[_entry.player_index].lab) > 0) {
            _special_hazard += _entry.bonus_hazard;
        }
        if (guidance_is_local_player(_entry.player_index)) {
            queue_blocking_notice(
                "QUEEN METROID AWAKENS",
                "Containment breach imminent. Hazard level "
                    + string(_special_hazard) + "."
            );
        }
        game_state.priority_player = _entry.player_index;
        ui_selected_kind = "";
        ui_selected_index = -1;
        pending_choice = {
            kind: "special_containment_ship",
            player_index: _entry.player_index,
            prompt: game_state.players[_entry.player_index].name
                + ": choose a ready Ship for containment, or continue without one."
        };
        return true;
    };

    begin_special_containment = function(
        _entries,
        _continuation,
        _queen_shop_index
    ) {
        special_containment_sequence = {
            entries: _entries,
            index: -1,
            continuation: _continuation,
            queen_shop_index: _queen_shop_index
        };
        return advance_special_containment();
    };

    special_containment_will_breach = function(_entry, _ship_index) {
        var _player = game_state.players[_entry.player_index];
        if (_entry.forced_breach && array_length(_player.lab) > 0) {
            return true;
        }
        var _strength = get_ready_character_strength(_player);
        var _uses_ship = _ship_index >= 0
            && _ship_index < array_length(_player.board.ships)
            && _player.board.ships[_ship_index].ready;
        if (_uses_ship) {
            _strength += get_card_stat(
                _player.board.ships[_ship_index],
                "containment_ship"
            );
        }
        if (!_uses_ship) {
            for (var _omega_index = 0;
                 _omega_index < array_length(_player.lab);
                 _omega_index++) {
                if (_player.lab[_omega_index].definition_id == "metroid.omega") {
                    return true;
                }
            }
        }
        return get_lab_hazard(_player)
            + (array_length(_player.lab) > 0 ? _entry.bonus_hazard : 0)
            > _strength;
    };

    resolve_special_containment_now = function(_ship_index) {
        var _entry = special_containment_sequence.entries[
            special_containment_sequence.index
        ];
        pending_choice = undefined;
        return begin_containment_sequence(
            _entry.player_index,
            _entry.bonus_hazard,
            _ship_index,
            _entry.forced_breach,
            "special"
        );
    };

    choose_special_containment_ship = function(_ship_index) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "special_containment_ship"
        || is_undefined(special_containment_sequence)) {
            return false;
        }
        var _entry = special_containment_sequence.entries[
            special_containment_sequence.index
        ];
        var _player = game_state.players[_entry.player_index];
        if (_ship_index >= 0
        && (_ship_index >= array_length(_player.board.ships)
            || !_player.board.ships[_ship_index].ready)) {
            return false;
        }

        if (special_containment_will_breach(_entry, _ship_index)) {
            for (var _adam_index = 0;
                 _adam_index < array_length(_player.board.characters);
                 _adam_index++) {
                if (_player.board.characters[_adam_index].definition_id
                == "loc.adam_malkovich") {
                    pending_choice = {
                        kind: "adam_breach",
                        special: true,
                        player_index: _entry.player_index,
                        ship_index: _ship_index,
                        prompt: "A Metroid will breach. Destroy Adam Malkovich to prevent that breach?"
                    };
                    return true;
                }
            }
        }
        return resolve_special_containment_now(_ship_index);
    };

    resolve_adam_breach_choice = function(_use_adam) {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "adam_breach") {
            return false;
        }
        var _choice = pending_choice;
        pending_choice = undefined;
        var _player = game_state.players[_choice.player_index];
        if (_use_adam) {
            for (var _adam_index = 0;
                 _adam_index < array_length(_player.board.characters);
                 _adam_index++) {
                var _adam = _player.board.characters[_adam_index];
                if (_adam.definition_id == "loc.adam_malkovich") {
                    remove_ability_source(
                        _choice.player_index == game_state.active_player
                            ? "character"
                            : "opponent_character",
                        _adam_index,
                        _adam,
                        true
                    );
                    _player.prevent_next_breach = true;
                    array_push(
                        game_state.event_log,
                        "Adam Malkovich was destroyed to prevent the next breach."
                    );
                    break;
                }
            }
        }
        if (variable_struct_exists(_choice, "special") && _choice.special) {
            return resolve_special_containment_now(_choice.ship_index);
        }
        return finish_turn_containment(_choice.ship_index);
    };

    resolve_turn_containment = function(_ship_index) {
        if (game_state.phase != "containment") {
            return false;
        }
        var _player = game_state.players[game_state.active_player];
        var _strength = get_ready_character_strength(_player);
        var _uses_ship = _ship_index >= 0
            && _ship_index < array_length(_player.board.ships)
            && _player.board.ships[_ship_index].ready;
        if (_uses_ship) {
            _strength += get_card_stat(
                _player.board.ships[_ship_index],
                "containment_ship"
            );
        }
        var _will_breach = get_lab_hazard(_player) > _strength;
        if (!_uses_ship) {
            for (var _omega_check = 0;
                 _omega_check < array_length(_player.lab);
                 _omega_check++) {
                if (_player.lab[_omega_check].definition_id == "metroid.omega") {
                    _will_breach = true;
                    break;
                }
            }
        }
        if (_will_breach) {
            for (var _adam_check = 0;
                 _adam_check < array_length(_player.board.characters);
                 _adam_check++) {
                if (_player.board.characters[_adam_check].definition_id
                == "loc.adam_malkovich") {
                    pending_choice = {
                        kind: "adam_breach",
                        player_index: game_state.active_player,
                        ship_index: _ship_index,
                        prompt: "A Metroid will breach. Destroy Adam Malkovich to prevent that breach?"
                    };
                    return true;
                }
            }
        }
        return finish_turn_containment(_ship_index);
    };

    get_turn_income = function() {
        if (game_state.mutation >= 7) {
            return 7;
        }
        if (game_state.mutation >= 5) {
            return 6;
        }
        if (game_state.mutation >= 3) {
            return 5;
        }
        return 4;
    };

    trigger_final_round = function(_reason) {
        if (game_state.phase == "game_over"
        || game_state.final_round_active) {
            return false;
        }
        game_state.final_round_active = true;
        game_state.final_round_end_player = 1 - game_state.active_player;
        game_state.final_round_reason = _reason;
        array_push(
            game_state.event_log,
            "FINAL ROUND: " + _reason + " "
                + game_state.players[game_state.active_player].name
                + " finishes this turn, then "
                + game_state.players[game_state.final_round_end_player].name
                + " takes the final turn."
        );
        return true;
    };

    check_alternate_end_conditions = function() {
        if (game_state.phase == "game_over"
        || game_state.final_round_active) {
            return false;
        }
        for (var _mercy_player_index = 0;
             _mercy_player_index < array_length(game_state.players);
             _mercy_player_index++) {
            if (array_length(game_state.players[_mercy_player_index].lab) >= 10) {
                return trigger_final_round(
                    game_state.players[_mercy_player_index].name
                    + " reached 10 Metroids in their Lab."
                );
            }
        }
        if (game_state.turn_number >= 50) {
            return trigger_final_round("Turn 50 was reached.");
        }
        return false;
    };

    resolve_gain_cp_phase = function() {
        var _player = game_state.players[game_state.active_player];
        var _income = get_turn_income();
        _player.command_points += _income;
        telemetry_update_max_cp(_player);
        array_push(
            game_state.event_log,
            _player.name + " gained " + string(_income) + " CP ("
            + string(_player.command_points) + " total)."
        );
        resolve_lab_intake();
    };

    resolve_lab_intake = function() {
        var _player = game_state.players[game_state.active_player];
        var _transported = 0;
        for (var _ship_index = 0;
             _ship_index < array_length(_player.board.ships);
             _ship_index++) {
            var _ship = _player.board.ships[_ship_index];
            if (settings_experimental_loaded_ships_exhausted
            && array_length(_ship.cargo) > 0) {
                _ship.skip_ready_after_lab_intake = true;
            }
            while (array_length(_ship.cargo) > 0) {
                var _metroid = array_pop(_ship.cargo);
                if (game_state.game_mode != "batch"
                && _metroid.ui_position_initialized) {
                    var _intake_transit_start = current_time + 280;
                    var _intake_transit_duration = 680;
                    array_push(presentation_card_transits, {
                        card: _metroid,
                        player_index: _player.index,
                        kind: "metroid_to_lab",
                        start_x: _metroid.ui_x,
                        start_y: _metroid.ui_y,
                        started_at_ms: _intake_transit_start,
                        duration_ms: _intake_transit_duration
                    });
                    _metroid.ui_lab_arrival_ms =
                        _intake_transit_start + _intake_transit_duration;
                    presentation_lab_intake_player = _player.index;
                    presentation_lab_intake_close_at_ms = max(
                        presentation_lab_intake_close_at_ms,
                        current_time + 1100
                    );
                    presentation_lab_intake_until_ms = max(
                        presentation_lab_intake_until_ms,
                        current_time + 1450
                    );
                }
                _metroid.zone = "lab";
                array_push(_player.lab, _metroid);
                _transported += 1;
            }
        }
        array_push(
            game_state.event_log,
            string(_transported) + " Metroid(s) moved from "
            + _player.name + "'s Ships to their Lab."
        );
        check_alternate_end_conditions();
        game_state.phase = "ready";
    };

    ready_card_array = function(_cards, _is_ship) {
        for (var _i = 0; _i < array_length(_cards); _i++) {
            var _card = _cards[_i];
            if (_card.definition_id == "lop.leviathan") {
                continue;
            }
            var _skip_ready = _is_ship
                && variable_struct_exists(_card, "used_for_containment_this_turn")
                && _card.used_for_containment_this_turn;
            var _loaded_ship_stays_exhausted = _is_ship
                && variable_struct_exists(
                    _card, "skip_ready_after_lab_intake"
                )
                && _card.skip_ready_after_lab_intake;
            if (_skip_ready) {
                _card.used_for_containment_this_turn = false;
            }
            if (_loaded_ship_stays_exhausted) {
                _card.skip_ready_after_lab_intake = false;
            }
            if (!_skip_ready && !_loaded_ship_stays_exhausted) {
                _card.ready = true;
            }
        }
    };

    resolve_ready_phase = function() {
        var _player = game_state.players[game_state.active_player];
        ready_card_array(_player.board.characters, false);
        ready_card_array(_player.board.ships, true);
        ready_card_array(_player.board.locations, false);
        array_push(
            game_state.event_log,
            _player.name + " readied their available cards."
        );
        game_state.phase = "action";
    };

    create_metroid_for_stage = function(_stage) {
        var _stage_ids = [
            "metroid.larva",
            "metroid.alpha",
            "metroid.gamma",
            "metroid.zeta",
            "metroid.omega"
        ];
        var _definition = get_metroid_definition(_stage_ids[_stage - 1]);
        if (is_undefined(_definition)) {
            return undefined;
        }
        return make_metroid_instance(_definition, "sr388");
    };

    evolve_sr388_slot = function(_slot) {
        var _metroid = game_state.sr388[_slot];
        if (is_undefined(_metroid)) {
            array_push(
                game_state.event_log,
                "SR388 slot " + string(_slot + 1)
                + " was empty; no evolution occurred."
            );
            return;
        }

        var _name = _metroid.definition.name;
        var _stage = _metroid.definition.stage;

        if (_stage == 5) {
            _metroid.zone = "cavern";
            array_push(game_state.cavern, _metroid);
            game_state.sr388[_slot] = create_metroid_for_stage(1);
            array_push(
                game_state.event_log,
                "SR388 slot " + string(_slot + 1) + ": Omega moved to the cavern."
            );
        } else {
            var _next_stage = _stage + 1;
            var _evolved_metroid = create_metroid_for_stage(_next_stage);
            _evolved_metroid.ui_position_initialized =
                _metroid.ui_position_initialized;
            _evolved_metroid.ui_x = _metroid.ui_x;
            _evolved_metroid.ui_y = _metroid.ui_y;
            _evolved_metroid.ui_zone = _metroid.ui_zone;
            if (game_state.game_mode != "batch"
            && game_state.game_mode != "network") {
                _evolved_metroid.evolution_old_definition =
                    _metroid.definition;
                _evolved_metroid.evolution_started_ms = current_time;
                presentation_evolution_until_ms = max(
                    presentation_evolution_until_ms,
                    current_time + _evolved_metroid.evolution_duration_ms
                );
            }
            game_state.sr388[_slot] = _evolved_metroid;
            array_push(
                game_state.event_log,
                "SR388 slot " + string(_slot + 1) + ": "
                + _name + " evolved into "
                + game_state.sr388[_slot].definition.name + "."
            );
            if (_stage == 1 && _next_stage == 2) {
                queue_first_game_guidance(
                    "evolution", "METROID EVOLUTION",
                    "Metroids evolve into stronger stages with more Research and Hazard. The evolved Metroid replaces its previous stage."
                );
            }

            if (_next_stage == 4 || _next_stage == 5) {
                var _mutation_advance = _next_stage == 5
                    && game_state.mutation >= 4 ? 2 : 1;
                game_state.mutation = min(
                    game_state.mutation + _mutation_advance,
                    game_state.mutation_limit
                );
                array_push(
                    game_state.event_log,
                    "Mutation advanced " + string(_mutation_advance)
                    + " space(s) to " + string(game_state.mutation)
                    + "/" + string(game_state.mutation_limit) + "."
                );
                queue_first_game_guidance(
                    "mutation", "MUTATION ADVANCED",
                    "When a Metroid evolves into a Zeta or Omega Metroid, the Mutation tracker advances. When it reaches 8, the game ends immediately."
                );
            }
        }
    };

    resolve_mutation_roll = function() {
        var _slot = irandom_range(0, 3);
        evolve_sr388_slot(_slot);

        for (var _refill_slot = 0; _refill_slot < 4; _refill_slot++) {
            if (is_undefined(game_state.sr388[_refill_slot])) {
                game_state.sr388[_refill_slot] = create_metroid_for_stage(1);
                array_push(
                    game_state.event_log,
                    "SR388 slot " + string(_refill_slot + 1)
                    + " refilled with a Larva."
                );
            }
        }

        if (game_state.mutation >= game_state.mutation_limit) {
            resolve_game_over();
        }
    };

    resolve_mutation_phase = function() {
        resolve_mutation_roll();
        if (game_state.phase != "game_over") {
            game_state.phase = "pass_turn";
        }
    };

    get_player_research = function(_player) {
        var _research = 0;
        for (var _i = 0; _i < array_length(_player.lab); _i++) {
            _research += _player.lab[_i].definition.research_value;
        }
        return floor(_research);
    };

    event_log_entry_text = function(_entry) {
        if (is_struct(_entry) && variable_struct_exists(_entry, "text")) {
            return string(_entry.text);
        }
        return string(_entry);
    };

    event_log_entry_is_game_event = function(_entry) {
        return !is_struct(_entry)
            || !variable_struct_exists(_entry, "kind")
            || _entry.kind != "chat";
    };

    count_event_log_matches = function(_needle) {
        var _count = 0;
        var _needle_lower = string_lower(_needle);
        for (var _event_index = 0;
             _event_index < array_length(game_state.event_log);
             _event_index++) {
            var _event_entry = game_state.event_log[_event_index];
            if (event_log_entry_is_game_event(_event_entry)
            && string_pos(
                _needle_lower,
                string_lower(event_log_entry_text(_event_entry))
            ) > 0) {
                _count += 1;
            }
        }
        return _count;
    };

    count_event_log_prefix = function(_prefix) {
        var _count = 0;
        var _prefix_lower = string_lower(_prefix);
        var _prefix_length = string_length(_prefix_lower);
        for (var _event_index = 0;
             _event_index < array_length(game_state.event_log);
             _event_index++) {
            var _event_entry = game_state.event_log[_event_index];
            if (event_log_entry_is_game_event(_event_entry)
            && string_copy(
                string_lower(event_log_entry_text(_event_entry)),
                1,
                _prefix_length
            ) == _prefix_lower) {
                _count += 1;
            }
        }
        return _count;
    };

    get_player_metroid_stage_summary = function(_player) {
        var _counts = [0, 0, 0, 0, 0, 0];
        for (var _lab_index = 0;
             _lab_index < array_length(_player.lab);
             _lab_index++) {
            var _stage_value = _player.lab[_lab_index].definition.stage;
            var _stage = is_real(_stage_value)
                ? clamp(floor(_stage_value), 1, 5)
                : 0;
            _counts[_stage] += 1;
        }
        return "Larva " + string(_counts[1])
            + ", Alpha " + string(_counts[2])
            + ", Gamma " + string(_counts[3])
            + ", Zeta " + string(_counts[4])
            + ", Omega " + string(_counts[5])
            + ", Hunter " + string(_counts[0]);
    };

    build_match_summary = function() {
        var _p0 = game_state.players[0];
        var _p1 = game_state.players[1];
        var _result = game_state.winner < 0
            ? "Draw"
            : game_state.players[game_state.winner].name + " won";
        var _summary = "LEGACY OF THE CHOZO - MATCH SUMMARY\n";
        _summary += "Seed: " + string(game_state.seed)
            + " | Mode: " + string_upper(game_state.game_mode)
            + " | Turns: " + string(game_state.turn_number)
            + " | Mutation: " + string(game_state.mutation)
            + "/" + string(game_state.mutation_limit) + "\n";
        _summary += "Elapsed: "
            + string_format(
                max(0, current_time - game_state.started_at_ms) / 1000,
                0,
                1
            ) + " seconds"
            + " | Card pool: "
            + string(card_database.totals.definitions) + " definitions / "
            + string(card_database.totals.copies) + " copies\n";
        _summary += "Result: " + _result + "\n\n";
        var _summary_players = [_p0, _p1];
        for (var _player_index = 0;
             _player_index < 2;
             _player_index++) {
            var _summary_player = _summary_players[_player_index];
            _summary += "PLAYER " + string(_player_index + 1)
                + " - " + _summary_player.name + "\n";
            _summary += "Research: "
                + string(get_player_research(_summary_player))
                + " | CP: " + string(_summary_player.command_points)
                + " | Lab: " + string(array_length(_summary_player.lab))
                + " Metroids / " + string(get_lab_hazard(_summary_player))
                + " Hazard\n";
            _summary += "Lab stages: "
                + get_player_metroid_stage_summary(_summary_player) + "\n";
            _summary += "Cards: Deck "
                + string(array_length(_summary_player.deck))
                + ", Hand " + string(array_length(_summary_player.hand))
                + ", Discard " + string(array_length(_summary_player.discard))
                + ", Characters "
                + string(array_length(_summary_player.board.characters))
                + ", Ships "
                + string(array_length(_summary_player.board.ships))
                + ", Locations "
                + string(array_length(_summary_player.board.locations))
                + "\n\n";
        }
        _summary += "TEMPO EVENTS\n";
        _summary += "Captures: "
            + string(count_event_log_matches(" captured ")) + "\n";
        _summary += "Raid initiations: "
            + string(count_event_log_matches("initiated a raid")) + "\n";
        _summary += "Raid results: "
            + string(count_event_log_prefix("Raid ")) + "\n";
        _summary += "Breaches: "
            + string(count_event_log_matches(" breached")) + "\n";
        _summary += "Evolution events: "
            + string(count_event_log_matches(" evolved")) + "\n";
        _summary += "Mutation advancements: "
            + string(count_event_log_matches("Mutation advanced")) + "\n";
        _summary += "Deployments: "
            + string(count_event_log_matches(" deployed ")) + "\n";
        _summary += "Reservations: "
            + string(count_event_log_matches(" reserved ")) + "\n";
        _summary += "Shop refreshes: "
            + string(count_event_log_matches("refreshed the Shop")) + "\n";
        _summary += "Hand refreshes: "
            + string(count_event_log_matches(" hand card(s) for 1 CP"))
            + "\n";
        _summary += "Queen resolutions: "
            + string(count_event_log_matches(
                "Queen Metroid Awakens evolved"
            )) + "\n";
        _summary += "Total rules events: "
            + string(array_length(game_state.event_log)) + "\n";
        return _summary;
    };

    create_balance_live_log = function() {
        if (game_state.balance_log_path != "") {
            return game_state.balance_log_path;
        }
        var _now = date_current_datetime();
        var _month = date_get_month(_now);
        var _day = date_get_day(_now);
        var _hour = date_get_hour(_now);
        var _minute = date_get_minute(_now);
        var _second = date_get_second(_now);
        var _stamp = string(date_get_year(_now))
            + (_month < 10 ? "0" : "") + string(_month)
            + (_day < 10 ? "0" : "") + string(_day)
            + "_"
            + (_hour < 10 ? "0" : "") + string(_hour)
            + (_minute < 10 ? "0" : "") + string(_minute)
            + (_second < 10 ? "0" : "") + string(_second);
        var _filename_base = "loc_balance_" + _stamp
            + "_seed_" + string(game_state.seed);
        var _filename = _filename_base + ".txt";
        var _path = working_directory + _filename;
        var _run_suffix = 2;
        while (file_exists(_path)) {
            _filename = _filename_base + "_run_"
                + string(_run_suffix) + ".txt";
            _path = working_directory + _filename;
            _run_suffix += 1;
        }
        game_state.balance_log_path = _path;
        balance_journal_lines = [];
        balance_live_event_count = 0;
        balance_live_ai_count = 0;
        return _path;
    };

    sync_balance_live_log = function() {
        var _path = create_balance_live_log();
        if (_path == "") {
            return false;
        }
        var _event_total = array_length(game_state.event_log);
        var _ai_total = array_length(ai_trace_log);
        if (_event_total <= balance_live_event_count
        && _ai_total <= balance_live_ai_count) {
            return true;
        }
        for (var _event_index = balance_live_event_count;
             _event_index < _event_total;
             _event_index++) {
            array_push(
                balance_journal_lines,
                "[EVENT " + string(_event_index + 1) + "] "
                    + event_log_entry_text(game_state.event_log[_event_index])
                    + "\n"
            );
        }
        for (var _ai_index = balance_live_ai_count;
             _ai_index < _ai_total;
             _ai_index++) {
            array_push(
                balance_journal_lines,
                "[TRACE] " + ai_trace_log[_ai_index] + "\n"
            );
        }
        balance_live_event_count = _event_total;
        balance_live_ai_count = _ai_total;
        return true;
    };

    write_balance_match_log = function() {
        if (!sync_balance_live_log()) {
            return "";
        }
        var _path = game_state.balance_log_path;
        var _file = file_text_open_write(_path);
        if (_file < 0) {
            show_debug_message(
                "[BALANCE] Could not write match log: " + _path
            );
            return "";
        }
        file_text_write_string(
            _file,
            "LEGACY OF THE CHOZO - MATCH JOURNAL\n"
            + "Seed: " + string(game_state.seed) + "\n"
            + "Status: COMPLETE\n\n"
        );
        for (var _journal_index = 0;
             _journal_index < array_length(balance_journal_lines);
             _journal_index++) {
            file_text_write_string(
                _file,
                balance_journal_lines[_journal_index]
            );
        }
        file_text_write_string(
            _file,
            "\nFINAL MATCH SUMMARY\n" + game_state.match_summary + "\n"
        );
        file_text_close(_file);
        if (game_state.game_mode == "batch") {
            var _console_winner = game_state.winner < 0
                ? "DRAW"
                : game_state.players[game_state.winner].name;
            show_debug_message(
                "[BATCH MATCH] " + _console_winner
                + " | Final Research "
                + string(get_player_research(game_state.players[0]))
                + "-"
                + string(get_player_research(game_state.players[1]))
            );
        } else {
            show_debug_message(
                "[BALANCE] Match log finalized at "
                + get_export_display_path(_path)
            );
        }
        return _path;
    };

    resolve_game_over = function() {
        if (game_state.phase == "game_over"
        && game_state.match_summary != "") {
            return false;
        }
        var _research_0 = get_player_research(game_state.players[0]);
        var _research_1 = get_player_research(game_state.players[1]);
        game_state.phase = "game_over";
        game_state.winner = -1;

        if (_research_0 > _research_1) {
            game_state.winner = 0;
        } else if (_research_1 > _research_0) {
            game_state.winner = 1;
        } else if (game_state.players[0].command_points
        > game_state.players[1].command_points) {
            game_state.winner = 0;
        } else if (game_state.players[1].command_points
        > game_state.players[0].command_points) {
            game_state.winner = 1;
        }

        var _result = game_state.winner < 0
            ? "The game ended in a draw."
            : game_state.players[game_state.winner].name + " won the game.";
        array_push(
            game_state.event_log,
            "Final Research: Player 1 " + string(_research_0)
            + ", Player 2 " + string(_research_1) + ". " + _result
        );
        // Analytics must never prevent the game-over state from resolving.
        try {
            game_state.match_summary = build_match_summary();
        } catch (_match_summary_error) {
            game_state.match_summary = "MATCH COMPLETE\n\n"
                + _result + "\n"
                + "Final Research: Player 1 " + string(_research_0)
                + ", Player 2 " + string(_research_1) + ".";
            show_debug_message(
                "[BALANCE] Match summary failed: "
                + string(_match_summary_error)
            );
        }
        var _write_detailed_match_log = game_state.game_mode != "batch"
            || global.loc_batch_state.detailed_logs
            || global.loc_batch_state.replay_active;
        if (_write_detailed_match_log) {
            try {
                game_state.balance_log_path = write_balance_match_log();
            } catch (_balance_log_error) {
                game_state.balance_log_path = "";
                show_debug_message(
                    "[BALANCE] Match log failed: "
                    + string(_balance_log_error)
                );
            }
        }
        return true;
    };

    begin_queen_shop_event = function(_shop_index) {
        pending_choice = {
            kind: "queen_event",
            stage: "revealed",
            shop_index: _shop_index,
            prompt:
                "QUEEN METROID AWAKENS appeared. Advance to resolve containment "
                + "and evolve every Metroid on SR388."
        };
        array_push(
            game_state.event_log,
            "Queen Metroid Awakens appeared in the Shop and began resolving."
        );
        return resolve_queen_shop_event();
    };

    resolve_queen_shop_event = function() {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "queen_event"
        || pending_choice.stage != "revealed") {
            return false;
        }
        var _queen_shop_index = pending_choice.shop_index;
        return begin_special_containment(
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
            _queen_shop_index
        );
    };

    finish_queen_containment_resolution = function(_queen_shop_index) {
        for (var _slot = 0; _slot < 4; _slot++) {
            evolve_sr388_slot(_slot);
        }

        pending_choice = {
            kind: "queen_event",
            stage: "resolved",
            shop_index: _queen_shop_index,
            prompt: "Queen Metroid Awakens is returning to the Shop deck."
        };
        array_push(
            game_state.event_log,
            "Queen Metroid Awakens evolved all four SR388 slots."
        );

        // Returning Queen is part of resolving the Event, not a separate player
        // confirmation. Leaving it face-up makes a completed Event behave like a
        // purchasable Shop card and lets a later refresh discard it.
        var _queen_returned = finish_queen_shop_event();

        if (game_state.mutation >= game_state.mutation_limit) {
            resolve_game_over();
        }
        return _queen_returned;
    };

    finish_queen_shop_event = function() {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "queen_event"
        || pending_choice.stage != "resolved") {
            return false;
        }
        var _quarantined_queens = [];
        for (var _queen_row_index = array_length(game_state.shop_row) - 1;
             _queen_row_index >= 0;
             _queen_row_index--) {
            if (game_state.shop_row[_queen_row_index].definition_id
            != "loc.queen_metroid_awakens") continue;
            var _row_queen = game_state.shop_row[_queen_row_index];
            array_delete(game_state.shop_row, _queen_row_index, 1);
            _row_queen.zone = "shop_deck";
            array_push(_quarantined_queens, _row_queen);
        }
        if (array_length(_quarantined_queens) <= 0) {
            pending_choice = undefined;
            array_push(
                game_state.event_log,
                "Queen Metroid could not be found in the Shop during resolution."
            );
            return false;
        }

        // Temporarily quarantine every other Queen as well. This prevents a
        // replacement draw from revealing another copy while Queen resolution
        // is cleaning and refilling the Shop.
        for (var _queen_deck_index = array_length(game_state.shop_deck) - 1;
             _queen_deck_index >= 0;
             _queen_deck_index--) {
            if (game_state.shop_deck[_queen_deck_index].definition_id
            != "loc.queen_metroid_awakens") continue;
            array_push(
                _quarantined_queens,
                game_state.shop_deck[_queen_deck_index]
            );
            array_delete(game_state.shop_deck, _queen_deck_index, 1);
        }
        for (var _queen_discard_index =
                 array_length(game_state.shop_discard) - 1;
             _queen_discard_index >= 0;
             _queen_discard_index--) {
            if (game_state.shop_discard[_queen_discard_index].definition_id
            != "loc.queen_metroid_awakens") continue;
            var _discard_queen = game_state.shop_discard[
                _queen_discard_index
            ];
            array_delete(
                game_state.shop_discard, _queen_discard_index, 1
            );
            _discard_queen.zone = "shop_deck";
            array_push(_quarantined_queens, _discard_queen);
        }

        pending_choice = undefined;
        refill_shop();
        for (var _queen_return_index = 0;
             _queen_return_index < array_length(_quarantined_queens);
             _queen_return_index++) {
            var _returning_queen = _quarantined_queens[_queen_return_index];
            _returning_queen.zone = "shop_deck";
            array_push(game_state.shop_deck, _returning_queen);
        }
        shuffle_array(game_state.shop_deck);
        array_push(
            game_state.event_log,
            string(array_length(_quarantined_queens))
                + " Queen Metroid card(s) were cleared from the Shop and shuffled back into its deck."
        );
        return true;
    };

}

