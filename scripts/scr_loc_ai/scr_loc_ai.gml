function loc_ai() {
    ai_eval_cache_active = false;
    ai_eval_utility_cache = {};
    ai_planner_collecting = false;
    // AI values are denominated in capture value (CV): 1 CV is the value of
    // safely moving one Research worth of Metroid cargo toward the Lab.  These
    // helpers intentionally derive value from rules-visible state rather than
    // card names, factions, or the mere presence of effect text.
    ai_effect_profile = function(_card) {
        var _profile = {
            removal: false,
            buff_strength: false,
            buff_security: false,
            cleanse: false,
            phazon: false,
            metroid: false,
            economy: false,
            ready: false
        };
        if (is_undefined(_card)) return _profile;
        var _abilities = get_activated_abilities(_card);
        for (var _ability_index = 0;
             _ability_index < array_length(_abilities);
             _ability_index++) {
            var _kind = _abilities[_ability_index].effect_kind;
            _profile.removal = _profile.removal
                || _kind == "discard_card"
                || _kind == "dark_samus_discard"
                || _kind == "exhaust_card";
            _profile.buff_strength = _profile.buff_strength
                || _kind == "ped_strength"
                || _kind == "raid_defense_1";
            _profile.buff_security = _profile.buff_security
                || _kind == "ship_security_1"
                || _kind == "ship_security_2";
            _profile.cleanse = _profile.cleanse
                || _kind == "dark_samus_consolidate";
            _profile.phazon = _profile.phazon
                || _kind == "corrupt_all"
                || _kind == "corrupt_copy"
                || _kind == "dark_samus_consolidate";
            _profile.metroid = _profile.metroid
                || _kind == "teleport_metroid"
                || _kind == "quiet_robe_place";
            _profile.economy = _profile.economy || _kind == "gain_cp";
            _profile.ready = _profile.ready
                || _kind == "ready_ship"
                || _kind == "space_pirate_payment";
        }
        var _text = variable_struct_exists(_card.definition, "effect")
            && !is_undefined(_card.definition.effect)
            ? string_lower(string(_card.definition.effect))
            : "";
        _profile.removal = _profile.removal
            || string_pos("discard", _text) > 0
            || string_pos("destroy", _text) > 0;
        _profile.buff_strength = _profile.buff_strength
            || string_pos("strength", _text) > 0;
        _profile.buff_security = _profile.buff_security
            || string_pos("security", _text) > 0;
        _profile.cleanse = _profile.cleanse
            || string_pos("remove", _text) > 0
                && string_pos("phazon", _text) > 0;
        _profile.phazon = _profile.phazon
            || string_pos("phazon", _text) > 0;
        _profile.metroid = _profile.metroid
            || string_pos("metroid", _text) > 0;
        _profile.economy = _profile.economy
            || string_pos("gain", _text) > 0 && string_pos("cp", _text) > 0;
        return _profile;
    };

    ai_ready_strength = function(_player) {
        var _total = 0;
        for (var _index = 0;
             _index < array_length(_player.board.characters);
             _index++) {
            var _card = _player.board.characters[_index];
            if (_card.ready) {
                _total += get_card_stat(_card, "containment_character");
            }
        }
        return _total;
    };

    ai_best_ready_ship_security = function(_player) {
        var _best = 0;
        for (var _index = 0;
             _index < array_length(_player.board.ships);
             _index++) {
            var _ship = _player.board.ships[_index];
            var _loaded_stays_exhausted =
                settings_experimental_loaded_ships_exhausted
                && array_length(_ship.cargo) > 0;
            if (_ship.ready && !_loaded_stays_exhausted) {
                _best = max(_best, get_card_stat(_ship, "containment_ship"));
            }
        }
        return _best;
    };

    ai_containment_loss_at = function(
        _player, _character_strength, _ship_security, _extra_metroid,
        _excluded_metroid_id
    ) {
        var _metroids = [];
        for (var _existing_index = 0;
             _existing_index < array_length(_player.lab);
             _existing_index++) {
            var _lab_metroid = _player.lab[_existing_index];
            if (is_undefined(_excluded_metroid_id)
            || _lab_metroid.instance_id != _excluded_metroid_id) {
                array_push(_metroids, _lab_metroid);
            }
        }
        // Ship cargo enters the Lab before containment. Treat every Metroid the
        // player already controls as part of the same projected containment,
        // even while it is still visibly aboard a Ship.
        for (var _cargo_ship_index = 0;
             _cargo_ship_index < array_length(_player.board.ships);
             _cargo_ship_index++) {
            var _cargo_ship = _player.board.ships[_cargo_ship_index];
            for (var _cargo_index = 0;
                 _cargo_index < array_length(_cargo_ship.cargo);
                 _cargo_index++) {
                var _owned_cargo = _cargo_ship.cargo[_cargo_index];
                if (is_undefined(_excluded_metroid_id)
                || _owned_cargo.instance_id != _excluded_metroid_id) {
                    array_push(_metroids, _owned_cargo);
                }
            }
        }
        if (!is_undefined(_extra_metroid)) {
            array_push(_metroids, _extra_metroid);
        }
        if (array_length(_metroids) <= 0) return 0;
        var _remaining = array_create(array_length(_metroids), true);
        var _remaining_count = array_length(_metroids);
        var _hazard = 0;
        for (var _hazard_index = 0;
             _hazard_index < array_length(_metroids);
             _hazard_index++) {
            _hazard += _metroids[_hazard_index].definition.hazard;
        }
        var _loss = 0;
        var _discard_position = array_length(_player.board.characters) - 1;

        // Omegas require one Ship commitment for the containment as a whole.
        if (_ship_security <= 0) {
            for (var _omega_index = 0;
                 _omega_index < array_length(_metroids);
                 _omega_index++) {
                var _omega = _metroids[_omega_index];
                if (_omega.definition.id == "metroid.omega") {
                    _remaining[_omega_index] = false;
                    _remaining_count -= 1;
                    _hazard -= _omega.definition.hazard;
                    _loss += _omega.definition.research_value;
                }
            }
        }

        var _capacity = _character_strength + _ship_security;
        while (_remaining_count > 0 && _hazard > _capacity) {
            // Match find_next_breaching_metroid: Hunter first, otherwise the
            // highest stage. A breach also discards the last Character.
            var _breach_index = -1;
            var _highest_stage = -1;
            for (var _lab_index = 0;
                 _lab_index < array_length(_metroids);
                 _lab_index++) {
                if (!_remaining[_lab_index]) continue;
                var _candidate = _metroids[_lab_index];
                if (_candidate.definition.id == "metroid.hunter") {
                    _breach_index = _lab_index;
                    break;
                }
                if (_candidate.definition.stage > _highest_stage) {
                    _highest_stage = _candidate.definition.stage;
                    _breach_index = _lab_index;
                }
            }
            if (_breach_index < 0) break;
            var _breach = _metroids[_breach_index];
            _remaining[_breach_index] = false;
            _remaining_count -= 1;
            _hazard -= _breach.definition.hazard;
            _loss += _breach.definition.research_value;

            if (_discard_position >= 0) {
                var _discarded = _player.board.characters[_discard_position];
                if (_discarded.ready) {
                    var _discarded_strength = get_card_stat(
                        _discarded, "containment_character"
                    );
                    _character_strength = max(
                        0, _character_strength - _discarded_strength
                    );
                }
                // Losing the body is an additional real state loss.
                _loss += 0.08 + max(0, get_card_stat(_discarded)) * 0.09;
                _discard_position -= 1;
                _capacity = _character_strength + _ship_security;
            }
        }
        return _loss;
    };

    ai_lab_failure_cost = function(_player) {
        return ai_containment_loss_at(
            _player,
            ai_ready_strength(_player),
            ai_best_ready_ship_security(_player)
        );
    };

    ai_containment_strength_delta = function(_player, _added_strength) {
        var _strength = ai_ready_strength(_player);
        var _ship = ai_best_ready_ship_security(_player);
        return ai_containment_loss_at(_player, _strength, _ship)
            - ai_containment_loss_at(
                _player, max(0, _strength + _added_strength), _ship
            );
    };

    ai_containment_ship_delta = function(_player, _new_security) {
        var _strength = ai_ready_strength(_player);
        var _ship = ai_best_ready_ship_security(_player);
        return ai_containment_loss_at(_player, _strength, _ship)
            - ai_containment_loss_at(
                _player, _strength, max(_ship, _new_security)
            );
    };

    ai_best_other_ship_security = function(_player, _excluded_id) {
        var _best = 0;
        for (var _index = 0;
             _index < array_length(_player.board.ships);
             _index++) {
            var _ship = _player.board.ships[_index];
            var _loaded_stays_exhausted =
                settings_experimental_loaded_ships_exhausted
                && array_length(_ship.cargo) > 0;
            if (_ship.ready && !_loaded_stays_exhausted
            && _ship.instance_id != _excluded_id) {
                _best = max(_best, get_card_stat(_ship, "containment_ship"));
            }
        }
        return _best;
    };

    ai_containment_exhaust_cost = function(_player, _source) {
        if (!_source.ready) return 0;
        var _possessed_metroids = array_length(_player.lab);
        for (var _possession_ship_index = 0;
             _possession_ship_index < array_length(_player.board.ships);
             _possession_ship_index++) {
            _possessed_metroids += array_length(
                _player.board.ships[_possession_ship_index].cargo
            );
        }
        if (_possessed_metroids <= 0) return 0;
        var _strength = ai_ready_strength(_player);
        var _ship = ai_best_ready_ship_security(_player);
        var _after_strength = _strength;
        var _after_ship = _ship;
        if (_source.definition.type == "character") {
            _after_strength = max(
                0,
                _strength - get_card_stat(_source, "containment_character")
            );
        } else if (_source.definition.type == "ship") {
            _after_ship = ai_best_other_ship_security(
                _player, _source.instance_id
            );
        }
        return max(
            0,
            ai_containment_loss_at(_player, _after_strength, _after_ship)
                - ai_containment_loss_at(_player, _strength, _ship)
        );
    };

    ai_board_has_phazon_plan = function(_player) {
        var _zones = [
            _player.board.characters,
            _player.board.ships,
            _player.board.locations
        ];
        for (var _zone_index = 0;
             _zone_index < array_length(_zones);
             _zone_index++) {
            for (var _index = 0;
                 _index < array_length(_zones[_zone_index]);
                 _index++) {
                var _card = _zones[_zone_index][_index];
                var _profile = ai_effect_profile(_card);
                if (_profile.phazon || _card.phazon_tokens > 0) return true;
            }
        }
        // Deck and discard establish future access, not immediate activation.
        // This boolean only gates a discounted option value later.
        var _future_zones = [_player.deck, _player.discard];
        for (var _future_zone = 0;
             _future_zone < array_length(_future_zones);
             _future_zone++) {
            for (var _future_index = 0;
                 _future_index < array_length(_future_zones[_future_zone]);
                 _future_index++) {
                if (ai_effect_profile(
                    _future_zones[_future_zone][_future_index]
                ).phazon) return true;
            }
        }
        return false;
    };

    ai_best_opposing_card_value = function(_player) {
        var _enemy = game_state.players[1 - _player.index];
        var _best = 0;
        var _zones = [
            _enemy.board.characters,
            _enemy.board.ships,
            _enemy.board.locations
        ];
        for (var _zone_index = 0;
             _zone_index < array_length(_zones);
             _zone_index++) {
            for (var _index = 0;
                 _index < array_length(_zones[_zone_index]);
                 _index++) {
                var _target = _zones[_zone_index][_index];
                var _target_profile = ai_effect_profile(_target);
                var _target_value = get_card_stat(_target) * 0.09;
                _target_value += _target_profile.removal ? 0.55 : 0;
                _target_value += _target_profile.metroid ? 0.35 : 0;
                _target_value += _target_profile.economy ? 0.3 : 0;
                if (_target.definition.type == "ship") {
                    _target_value += 0.25;
                    if (array_length(_enemy.board.ships) == 1) {
                        // Removing the final Ship also removes all immediate
                        // capture/transport access from the opposing board.
                        var _last_ship_security = get_card_stat(_target);
                        for (var _metroid_index = 0;
                             _metroid_index < 5;
                             _metroid_index++) {
                            var _available_metroid = _metroid_index == 4
                                ? (array_length(game_state.cavern) > 0
                                    ? game_state.cavern[
                                        array_length(game_state.cavern) - 1
                                      ]
                                    : undefined)
                                : game_state.sr388[_metroid_index];
                            if (!is_undefined(_available_metroid)
                            && _available_metroid.definition.hazard
                                <= _last_ship_security) {
                                _target_value = max(
                                    _target_value,
                                    _available_metroid.definition.research_value
                                        + 0.25
                                );
                            }
                        }
                    }
                    for (var _cargo_index = 0;
                         _cargo_index < array_length(_target.cargo);
                         _cargo_index++) {
                        _target_value +=
                            _target.cargo[_cargo_index].definition.research_value;
                    }
                }
                _best = max(_best, _target_value);
            }
        }
        return _best;
    };

    ai_deployed_intrinsic_value = function(_card) {
        if (is_undefined(_card)) return 0;
        var _stat = max(0, get_card_stat(_card));
        var _value = 0.08 + _stat * 0.08;
        if (_card.definition.type == "ship") _value += 0.08;
        var _profile = ai_effect_profile(_card);
        _value += _profile.removal ? 0.30 : 0;
        _value += _profile.metroid ? 0.22 : 0;
        _value += _profile.economy ? 0.18 : 0;
        _value += _profile.buff_strength || _profile.buff_security ? 0.14 : 0;
        _value += _profile.cleanse || _profile.phazon ? 0.12 : 0;
        _value += _profile.ready ? 0.10 : 0;
        return _value;
    };

    ai_ready_raid_total = function(_player, _context, _excluded_id) {
        var _total = 0;
        for (var _character_index = 0;
             _character_index < array_length(_player.board.characters);
             _character_index++) {
            var _character = _player.board.characters[_character_index];
            if (_character.ready && _character.instance_id != _excluded_id) {
                _total += get_card_stat(
                    _character,
                    _context == "attack"
                        ? "raid_attacker_character"
                        : "raid_defender_character"
                );
            }
        }
        for (var _ship_index = 0;
             _ship_index < array_length(_player.board.ships);
             _ship_index++) {
            var _ship = _player.board.ships[_ship_index];
            if (_ship.ready && _ship.instance_id != _excluded_id) {
                _total += get_card_stat(
                    _ship,
                    _context == "attack"
                        ? "raid_attacker_ship"
                        : "raid_defender_ship"
                );
            }
        }
        return _total;
    };

    ai_removal_raid_delta = function(_card, _owner) {
        if (!_card.ready) return 0;
        var _enemy = game_state.players[1 - _owner.index];
        var _before_attack = ai_ready_raid_total(_owner, "attack", -1);
        var _after_attack = ai_ready_raid_total(
            _owner, "attack", _card.instance_id
        );
        var _before_defense = ai_ready_raid_total(_owner, "defense", -1);
        var _after_defense = ai_ready_raid_total(
            _owner, "defense", _card.instance_id
        );
        var _enemy_defense = ai_ready_raid_total(_enemy, "defense", -1);
        var _enemy_attack = ai_ready_raid_total(_enemy, "attack", -1);
        var _value = ((_before_attack - _after_attack)
            + (_before_defense - _after_defense)) * 0.045;
        if (_before_attack > _enemy_defense
        && _after_attack <= _enemy_defense) _value += 0.42;
        if (_before_defense >= _enemy_attack
        && _after_defense < _enemy_attack) _value += 0.42;
        return _value;
    };

    ai_removal_containment_delta = function(_card, _owner) {
        if (!_card.ready) return 0;
        var _strength = ai_ready_strength(_owner);
        var _ship = ai_best_ready_ship_security(_owner);
        var _after_strength = _strength;
        var _after_ship = _ship;
        if (_card.definition.type == "character") {
            _after_strength = max(
                0,
                _strength - get_card_stat(_card, "containment_character")
            );
        } else if (_card.definition.type == "ship") {
            _after_ship = ai_best_other_ship_security(
                _owner, _card.instance_id
            );
        }
        var _excluded_cargo_id = undefined;
        if (_card.definition.type == "ship"
        && array_length(_card.cargo) > 0) {
            _excluded_cargo_id = _card.cargo[0].instance_id;
        }
        return max(
            0,
            ai_containment_loss_at(
                _owner,
                _after_strength,
                _after_ship,
                undefined,
                _excluded_cargo_id
            )
                - ai_containment_loss_at(_owner, _strength, _ship)
        );
    };

    ai_expected_cargo_denial = function(_ship, _owner) {
        var _value = 0;
        var _strength = ai_ready_strength(_owner);
        var _security = ai_best_ready_ship_security(_owner);
        for (var _cargo_index = 0;
             _cargo_index < array_length(_ship.cargo);
             _cargo_index++) {
            var _cargo = _ship.cargo[_cargo_index];
            var _without_cargo_loss = ai_containment_loss_at(
                _owner,
                _strength,
                _security,
                undefined,
                _cargo.instance_id
            );
            var _with_cargo_loss = ai_containment_loss_at(
                _owner, _strength, _security
            );
            var _expected_research = max(
                0,
                _cargo.definition.research_value
                    - max(0, _with_cargo_loss - _without_cargo_loss)
            );
            _value += _expected_research
                * ai_cargo_survival_probability(_owner, _ship);
        }
        return _value;
    };

    ai_board_card_removal_value = function(_card, _owner) {
        if (is_undefined(_card)) return 0;
        var _value = ai_deployed_intrinsic_value(_card);
        _value += ai_removal_containment_delta(_card, _owner);
        _value += ai_removal_raid_delta(_card, _owner);
        for (var _attachment_index = 0;
             _attachment_index < array_length(_card.attachments);
             _attachment_index++) {
            var _attachment = _card.attachments[_attachment_index];
            // Only attachments controlled by the host's controller are treated
            // as value lost. Removing an opposing harmful attachment is not a
            // bonus for the remover.
            if (_attachment.controller == _owner.index) {
                _value += max(0, ai_deployed_intrinsic_value(_attachment));
            }
        }
        if (_card.definition.type == "ship") {
            _value += ai_expected_cargo_denial(_card, _owner);
            if (array_length(_owner.board.ships) == 1) {
                var _best_reachable_research = 0;
                var _security = get_card_stat(_card);
                for (var _metroid_index = 0;
                     _metroid_index < 5;
                     _metroid_index++) {
                    var _metroid = _metroid_index == 4
                        ? (array_length(game_state.cavern) > 0
                            ? game_state.cavern[
                                array_length(game_state.cavern) - 1
                              ]
                            : undefined)
                        : game_state.sr388[_metroid_index];
                    if (!is_undefined(_metroid)
                    && _metroid.definition.hazard <= _security) {
                        _best_reachable_research = max(
                            _best_reachable_research,
                            _metroid.definition.research_value
                        );
                    }
                }
                _value += _best_reachable_research;
            }
        }
        return _value;
    };

    ai_discard_recovery_probability = function(_player, _turn_horizon) {
        // Discard cards cannot be drawn until the personal deck empties. Use the
        // actual zone sizes to estimate whether a newly discarded card can cycle
        // back within the bounded response horizon.
        var _draws_per_turn = max(1, 5 - array_length(_player.hand));
        var _projected_draws = _draws_per_turn * _turn_horizon;
        var _deck_count = array_length(_player.deck);
        if (_projected_draws <= _deck_count) return 0;
        var _post_shuffle_draws = _projected_draws - _deck_count;
        var _shuffle_pool = array_length(_player.discard) + 1;
        return min(1, _post_shuffle_draws / max(1, _shuffle_pool));
    };

    ai_card_utility = function(_card, _player) {
        if (is_undefined(_card)) {
            return -1000;
        }
        var _cache_key = "";
        if (ai_eval_cache_active
        && variable_struct_exists(_card, "instance_id")) {
            _cache_key = "p" + string(_player.index) + "_c"
                + string(_card.instance_id);
            if (variable_struct_exists(ai_eval_utility_cache, _cache_key)) {
                return variable_struct_get(ai_eval_utility_cache, _cache_key);
            }
        }
        var _type = _card.definition.type;
        var _stat = max(0, get_card_stat(_card));
        var _profile = ai_effect_profile(_card);
        var _value = 0;

        // A body has only a small floor. Most of its value is supplied by the
        // thresholds it crosses in the current position.
        if (_type == "character") {
            _value += 0.08 + (_stat * 0.09);
            _value += ai_containment_strength_delta(_player, _stat);
            var _combat_enemy = game_state.players[1 - _player.index];
            var _own_combat = ai_ready_strength(_player);
            var _enemy_combat = ai_ready_strength(_combat_enemy);
            if (_own_combat <= _enemy_combat
            && _own_combat + _stat > _enemy_combat) {
                // Crossing the current raid/defense threshold creates an option;
                // its payoff remains bounded below a safe capture until cargo is
                // actually exposed.
                _value += 0.42;
            }
        } else if (_type == "ship") {
            _value += 0.16 + (_stat * 0.08);
            _value += ai_containment_ship_delta(_player, _stat);
            // Derive first/extra Ship value from reachable Metroids rather than
            // assigning a flat prerequisite bonus.
            var _best_capture = 0;
            for (var _metroid_index = 0; _metroid_index < 5; _metroid_index++) {
                var _metroid = _metroid_index == 4
                    ? (array_length(game_state.cavern) > 0
                        ? game_state.cavern[array_length(game_state.cavern) - 1]
                        : undefined)
                    : game_state.sr388[_metroid_index];
                if (!is_undefined(_metroid)
                && _metroid.definition.hazard <= _stat) {
                    _best_capture = max(
                        _best_capture,
                        _metroid.definition.research_value
                    );
                }
            }
            _value += _best_capture;
            if (array_length(_player.board.ships) > 0) {
                _value *= 0.65;
            }
        } else if (_type == "location") {
            _value += 0.12;
        } else if (_type == "event") {
            _value += 0;
        }

        // Semantic option values are bounded fractions of a safe capture. They
        // only appear when the board state makes that option relevant.
        if (_profile.removal) {
            _value += min(1.25, ai_best_opposing_card_value(_player) * 0.6);
        }
        if (_profile.buff_strength) {
            var _enemy = game_state.players[1 - _player.index];
            var _own_strength = ai_ready_strength(_player);
            var _enemy_strength = ai_ready_strength(_enemy);
            _value += _own_strength <= _enemy_strength ? 0.28 : 0.06;
        }
        if (_profile.buff_security) {
            _value += array_length(_player.board.ships) > 0 ? 0.24 : 0.03;
        }
        if (_profile.cleanse) {
            var _cleanse_need = 0;
            var _cleanse_zones = [
                _player.board.characters,
                _player.board.ships,
                _player.board.locations
            ];
            for (var _cleanse_zone = 0;
                 _cleanse_zone < array_length(_cleanse_zones);
                 _cleanse_zone++) {
                for (var _cleanse_index = 0;
                     _cleanse_index < array_length(_cleanse_zones[_cleanse_zone]);
                     _cleanse_index++) {
                    var _cleanse_target = _cleanse_zones[_cleanse_zone][_cleanse_index];
                    if (_cleanse_target.phazon_tokens > 0) {
                        _cleanse_need = max(
                            _cleanse_need,
                            _cleanse_target.phazon_tokens >= 3 ? 0.9 : 0.18
                        );
                    }
                }
            }
            // This is long-term option value only. Immediate value is calculated
            // by the ability scorer after deploy/event timing and CP are legal.
            var _enemy_has_phazon = ai_board_has_phazon_plan(
                game_state.players[1 - _player.index]
            );
            _value += (_cleanse_need * 0.25)
                + (_enemy_has_phazon ? 0.06 : 0);
        }
        if (_profile.phazon && ai_board_has_phazon_plan(_player)) {
            _value += 0.18;
        }
        if (_profile.metroid) {
            var _controlled_metroids = array_length(_player.lab);
            for (var _ship_index = 0;
                 _ship_index < array_length(_player.board.ships);
                 _ship_index++) {
                _controlled_metroids += array_length(
                    _player.board.ships[_ship_index].cargo
                );
            }
            _value += min(0.8, _controlled_metroids * 0.24);
        }
        if (_profile.economy) {
            _value += 0.22;
        }
        if (_profile.ready) {
            _value += 0.12;
        }
        if (_cache_key != "") {
            variable_struct_set(ai_eval_utility_cache, _cache_key, _value);
        }
        return _value;
    };

    ai_hand_card_keep_value = function(_card, _player) {
        // Affordability is handled by the turn planner. Penalizing a card here
        // for its full Reserve cost made valuable future plays look like refresh
        // fodder, especially in the Mawkin starter.
        return ai_card_utility(_card, _player);
    };

    ai_plan_hand_refresh = function(_player) {
        var _plan = {
            indices: [],
            expected_draw_value: 0,
            improvement: 0,
            score: -100000,
            ship_search: false
        };
        if (_player.command_points < 1) {
            return _plan;
        }
        if (variable_struct_exists(_player, "ai_hand_refresh_turn")
        && _player.ai_hand_refresh_turn == game_state.turn_number) {
            return _plan;
        }

        // The AI knows which cards remain in its deck, but deliberately reduces
        // them to an average value. It never inspects or predicts their order.
        var _draw_pool = _player.deck;
        if (array_length(_draw_pool) <= 0) {
            _draw_pool = _player.discard;
        }
        if (array_length(_draw_pool) <= 0) {
            return _plan;
        }
        var _draw_total = 0;
        for (var _draw_index = 0;
             _draw_index < array_length(_draw_pool);
             _draw_index++) {
            _draw_total += ai_hand_card_keep_value(
                _draw_pool[_draw_index],
                _player
            );
        }
        _plan.expected_draw_value =
            _draw_total / array_length(_draw_pool);
        var _missing_cards = max(0, 5 - array_length(_player.hand));
        _plan.improvement = _missing_cards * _plan.expected_draw_value;

        var _needs_first_ship = array_length(_player.board.ships) <= 0;
        var _has_playable_ship_option = false;
        if (_needs_first_ship) {
            for (var _ship_hand_index = 0;
                 _ship_hand_index < array_length(_player.hand);
                 _ship_hand_index++) {
                if (_player.hand[_ship_hand_index].definition.type == "ship"
                && can_play_hand_card(_ship_hand_index)) {
                    _has_playable_ship_option = true;
                    break;
                }
            }
            if (!_has_playable_ship_option) {
                for (var _ship_shop_index = 0;
                     _ship_shop_index < array_length(game_state.shop_row);
                     _ship_shop_index++) {
                    var _ship_shop_card = game_state.shop_row[_ship_shop_index];
                    if (_ship_shop_card.definition.type != "ship") continue;
                    var _ship_deploy_cost = get_modified_deploy_cost(
                        _player,
                        _ship_shop_card
                    );
                    var _ship_reserve_cost = get_modified_reserve_cost(
                        _player,
                        _ship_shop_card
                    );
                    if ((is_real(_ship_deploy_cost)
                        && _player.command_points >= _ship_deploy_cost)
                    || (is_real(_ship_reserve_cost)
                        && _player.command_points >= _ship_reserve_cost)) {
                        _has_playable_ship_option = true;
                        break;
                    }
                }
            }
        }
        var _searched_this_turn = variable_struct_exists(
            _player,
            "ai_ship_search_turn"
        ) && _player.ai_ship_search_turn == game_state.turn_number;
        if (_needs_first_ship
        && !_has_playable_ship_option
        && !_searched_this_turn) {
            // Cycle the supporting cards once this turn, but retain any Ship the
            // AI has already found and may simply need more CP to play.
            for (var _ship_search_index = 0;
                 _ship_search_index < array_length(_player.hand);
                 _ship_search_index++) {
                if (_player.hand[_ship_search_index].definition.type != "ship") {
                    array_push(_plan.indices, _ship_search_index);
                }
            }
            if (array_length(_plan.indices) > 0 || _missing_cards > 0) {
                _plan.improvement += 1;
                _plan.score = _plan.improvement
                    - ai_cp_spend_cost(_player, 1);
                _plan.ship_search = true;
                return _plan;
            }
        }

        for (var _hand_index = 0;
             _hand_index < array_length(_player.hand);
             _hand_index++) {
            var _keep_value = ai_hand_card_keep_value(
                _player.hand[_hand_index],
                _player
            );
            var _gain = _plan.expected_draw_value - _keep_value;
            if (_gain > 0.25) {
                array_push(_plan.indices, _hand_index);
                _plan.improvement += _gain;
            }
        }
        if (array_length(_plan.indices) > 0 || _missing_cards > 0) {
            // One CP refreshes every selected card, so broader weak hands make the
            // action increasingly efficient.
            _plan.score = _plan.improvement
                - ai_cp_spend_cost(_player, 1);
            if (_missing_cards <= 0 && _plan.improvement <= 0.25) {
                _plan.score = -100000;
                _plan.indices = [];
            }
        }
        return _plan;
    };

    ai_shop_acquisition_score = function(_card, _player, _available_cp) {
        if (is_undefined(_card)
        || _card.definition_id == "loc.queen_metroid_awakens"
        || _card.definition_id == "loc.sa_x_breaks_out") {
            return -100000;
        }
        var _card_value = ai_card_utility(_card, _player);
        var _best = -100000;
        var _deploy_cost = get_modified_deploy_cost(_player, _card);
        if (_card.definition.type != "event"
        && is_real(_deploy_cost)
        && _available_cp >= _deploy_cost) {
            _best = max(
                _best,
                _card_value - ai_cp_spend_cost(_player, _deploy_cost)
            );
        }
        var _reserve_cost = get_modified_reserve_cost(_player, _card);
        if (is_real(_reserve_cost)
        && _available_cp >= _reserve_cost) {
            _best = max(
                _best,
                (_card_value * 0.35)
                    - ai_cp_spend_cost(_player, _reserve_cost)
            );
        }
        return _best;
    };

    ai_combination = function(_n, _k) {
        if (_k < 0 || _k > _n) return 0;
        _k = min(_k, _n - _k);
        var _result = 1;
        for (var _index = 1; _index <= _k; _index++) {
            _result = _result * (_n - _k + _index) / _index;
        }
        return _result;
    };

    ai_score_shop_refresh = function(_player, _visible_best_score) {
        if (_player.command_points < 1) {
            return -100000;
        }
        if (variable_struct_exists(_player, "ai_shop_refresh_turn")
        && _player.ai_shop_refresh_turn == game_state.turn_number) {
            return -100000;
        }
        var _future_cp = _player.command_points - 1;
        var _pool = [];
        for (var _deck_index = 0;
             _deck_index < array_length(game_state.shop_deck);
             _deck_index++) {
            array_push(_pool, game_state.shop_deck[_deck_index]);
        }
        // If fewer than five cards remain, refill will eventually shuffle the
        // public Shop discard together with the row being refreshed.
        if (array_length(_pool) < 5) {
            for (var _discard_index = 0;
                 _discard_index < array_length(game_state.shop_discard);
                 _discard_index++) {
                array_push(_pool, game_state.shop_discard[_discard_index]);
            }
            for (var _row_index = 0;
                 _row_index < array_length(game_state.shop_row);
                 _row_index++) {
                array_push(_pool, game_state.shop_row[_row_index]);
            }
        }
        if (array_length(_pool) <= 0) {
            return -100000;
        }

        var _score_count = 0;
        var _scores = [];
        for (var _pool_index = 0;
             _pool_index < array_length(_pool);
             _pool_index++) {
            var _candidate_score = ai_shop_acquisition_score(
                _pool[_pool_index],
                _player,
                _future_cp
            );
            if (_candidate_score > -100000) {
                array_push(_scores, max(0, _candidate_score));
                _score_count += 1;
            }
        }
        if (_score_count <= 0) {
            return -100000;
        }
        // Exact expected maximum of an unordered five-card sample. The AI uses
        // pool composition but never consults or predicts card order.
        array_sort(_scores, true);
        var _draw_count = min(5, array_length(_scores));
        var _denominator = ai_combination(
            array_length(_scores), _draw_count
        );
        var _expected_best = 0;
        for (var _rank = _draw_count - 1;
             _rank < array_length(_scores);
             _rank++) {
            _expected_best += _scores[_rank]
                * ai_combination(_rank, _draw_count - 1)
                / _denominator;
        }
        return _expected_best - max(0, _visible_best_score)
            - ai_cp_spend_cost(_player, 1);
    };

    ai_cp_option_value = function(_player, _available_cp) {
        var _best = 0;
        for (var _hand_index = 0;
             _hand_index < array_length(_player.hand);
             _hand_index++) {
            var _hand_card = _player.hand[_hand_index];
            var _hand_cost = _hand_card.definition.type == "event"
                ? 0
                : max(0, _hand_card.definition.costs.reserve
                    - get_zebes_discount(_player, _hand_card));
            if (_hand_cost <= _available_cp) {
                _best = max(_best, ai_card_utility(_hand_card, _player));
            }
        }
        for (var _shop_index = 0;
             _shop_index < array_length(game_state.shop_row);
             _shop_index++) {
            var _shop_card = game_state.shop_row[_shop_index];
            if (_shop_card.definition_id == "loc.queen_metroid_awakens"
            || _shop_card.definition_id == "loc.sa_x_breaks_out") continue;
            var _deploy = get_modified_deploy_cost(_player, _shop_card);
            var _reserve = get_modified_reserve_cost(_player, _shop_card);
            if ((is_real(_deploy) && _deploy <= _available_cp)
            || (is_real(_reserve) && _reserve <= _available_cp)) {
                _best = max(_best, ai_card_utility(_shop_card, _player));
            }
        }
        // Capturing a safe one-Research Metroid defines one CV.
        if (array_length(_player.board.ships) > 0
        && _available_cp >= get_capture_cost(_player)) {
            for (var _ship_index = 0;
                 _ship_index < array_length(_player.board.ships);
                 _ship_index++) {
                var _ship = _player.board.ships[_ship_index];
                if (!_ship.ready || array_length(_ship.cargo) > 0) continue;
                var _security = get_card_stat(_ship);
                for (var _metroid_index = 0;
                     _metroid_index < 5;
                     _metroid_index++) {
                    var _metroid = _metroid_index == 4
                        ? (array_length(game_state.cavern) > 0
                            ? game_state.cavern[
                                array_length(game_state.cavern) - 1
                              ]
                            : undefined)
                        : game_state.sr388[_metroid_index];
                    if (!is_undefined(_metroid)
                    && _metroid.definition.hazard <= _security) {
                        _best = max(
                            _best,
                            _metroid.definition.research_value
                        );
                    }
                }
            }
        }
        return _best;
    };

    ai_cp_spend_cost = function(_player, _cost) {
        if (ai_planner_collecting) return 0;
        if (_cost <= 0) return 0;
        var _before = ai_cp_option_value(
            _player,
            _player.command_points + 4
        );
        var _after = ai_cp_option_value(
            _player,
            max(0, _player.command_points - _cost) + 4
        );
        return max(0, _before - _after);
    };

    ai_plan_groups_conflict = function(_used, _candidate, _phase) {
        for (var _group_index = 0;
             _group_index < array_length(_candidate.groups);
             _group_index++) {
            if (raid_array_contains(_used, _candidate.groups[_group_index])) {
                return true;
            }
        }
        var _phase_event = "event_phase_" + string(_phase);
        return _candidate.is_event
            && raid_array_contains(_used, _phase_event);
    };

    ai_plan_clone_array = function(_source) {
        var _length = array_length(_source);
        var _clone = array_create(_length);
        if (_length > 0) {
            array_copy(_clone, 0, _source, 0, _length);
        }
        return _clone;
    };

    ai_plan_add_groups = function(_used, _candidate, _phase) {
        var _result = ai_plan_clone_array(_used);
        for (var _group_index = 0;
             _group_index < array_length(_candidate.groups);
             _group_index++) {
            array_push(_result, _candidate.groups[_group_index]);
        }
        if (_candidate.is_event) {
            array_push(_result, "event_phase_" + string(_phase));
        }
        return _result;
    };

    ai_plan_state_key = function(_state) {
        var _groups = ai_plan_clone_array(_state.used);
        array_sort(_groups, true);
        var _key = string(_state.phase) + "|" + string(_state.cp)
            + "|" + string(_state.depth) + "|" + string(_state.steps);
        for (var _group_index = 0;
             _group_index < array_length(_groups);
             _group_index++) {
            _key += "|" + _groups[_group_index];
        }
        return _key;
    };

    ai_plan_turn = function(_candidates, _starting_cp) {
        var _beam = [{
            cp: _starting_cp,
            phase: 0,
            depth: 0,
            steps: 0,
            value: 0,
            first: -1,
            used: [],
            sequence: []
        }];
        var _best = _beam[0];
        var _beam_width = 48;
        var _max_paid_actions = 3;
        var _max_steps = 5;
        // Each wave adds one action. Free actions do not consume the three-paid
        // action horizon, but the five-step cap and resource groups prevent
        // repeatable zero-cost lines from growing without bound.
        // A one-way phase transition represents
        // ending this turn, receiving the normal 4 CP income, and considering
        // discounted next-turn access without searching an opponent response.
        for (var _wave = 0; _wave <= _max_steps; _wave++) {
            var _expanded = [];
            for (var _state_index = 0;
                 _state_index < array_length(_beam);
                 _state_index++) {
                var _state = _beam[_state_index];
                array_push(_expanded, _state);
                if (_state.value > _best.value) _best = _state;
                if (_state.phase == 0) {
                    array_push(_expanded, {
                        cp: _state.cp + 4,
                        phase: 1,
                        depth: _state.depth,
                        steps: _state.steps,
                        value: _state.value,
                        first: _state.first,
                        used: ai_plan_clone_array(_state.used),
                        sequence: ai_plan_clone_array(_state.sequence)
                    });
                }
                if (_state.steps >= _max_steps) continue;
                for (var _candidate_index = 0;
                     _candidate_index < array_length(_candidates);
                     _candidate_index++) {
                    var _candidate = _candidates[_candidate_index];
                    var _earliest_phase = variable_struct_exists(
                        _candidate, "earliest_phase"
                    ) ? _candidate.earliest_phase : 0;
                    if (_state.phase < _earliest_phase
                    || _candidate.cost > _state.cp
                    || (_candidate.cost > 0
                        && _state.depth >= _max_paid_actions)
                    || (_candidate.value <= 0.02
                        && (!variable_struct_exists(_candidate, "cp_gain")
                            || _candidate.cp_gain <= 0))
                    || ai_plan_groups_conflict(
                        _state.used, _candidate, _state.phase
                    )) continue;
                    var _sequence = ai_plan_clone_array(_state.sequence);
                    array_push(_sequence, _candidate_index);
                    array_push(_expanded, {
                        cp: _state.cp - _candidate.cost
                            + (variable_struct_exists(_candidate, "cp_gain")
                                ? _candidate.cp_gain : 0),
                        phase: _state.phase,
                        depth: _state.depth + (_candidate.cost > 0 ? 1 : 0),
                        steps: _state.steps + 1,
                        value: _state.value + _candidate.value
                            * (_state.phase == 0 ? 1 : 0.7),
                        first: _state.first >= 0
                            ? _state.first
                            : (_state.phase == 0 ? _candidate_index : -1),
                        used: ai_plan_add_groups(
                            _state.used, _candidate, _state.phase
                        ),
                        sequence: _sequence
                    });
                }
            }
            // Exact-state memoization discards paths that reach the same phase,
            // CP, depth, and consumed resources with a lower projected value.
            var _memo = {};
            var _unique = [];
            for (var _expanded_index = 0;
                 _expanded_index < array_length(_expanded);
                 _expanded_index++) {
                var _expanded_state = _expanded[_expanded_index];
                var _state_key = ai_plan_state_key(_expanded_state);
                if (!variable_struct_exists(_memo, _state_key)) {
                    variable_struct_set(_memo, _state_key, array_length(_unique));
                    array_push(_unique, _expanded_state);
                } else {
                    var _memo_index = variable_struct_get(_memo, _state_key);
                    if (_expanded_state.value > _unique[_memo_index].value) {
                        _unique[_memo_index] = _expanded_state;
                    }
                }
            }
            array_sort(_unique, function(_left, _right) {
                return _right.value - _left.value;
            });
            if (array_length(_unique) > _beam_width) {
                array_resize(_unique, _beam_width);
            }
            _beam = _unique;
        }
        for (var _final_index = 0;
             _final_index < array_length(_beam);
             _final_index++) {
            if (_beam[_final_index].value > _best.value) {
                _best = _beam[_final_index];
            }
        }
        return _best;
    };

    ai_cargo_survival_probability = function(_player, _ship) {
        var _enemy = game_state.players[1 - _player.index];
        var _defense = get_card_stat(_ship, "raid_defender_ship")
            + ai_ready_strength(_player);
        var _best_attack = 0;
        var _affordable_raid = false;
        for (var _ship_index = 0;
             _ship_index < array_length(_enemy.board.ships);
             _ship_index++) {
            var _attacker = _enemy.board.ships[_ship_index];
            if (!_attacker.ready || array_length(_attacker.cargo) > 0) continue;
            if (_enemy.command_points + 4 >= get_raid_cost(_enemy, _ship)) {
                _affordable_raid = true;
                _best_attack = max(
                    _best_attack,
                    get_card_stat(_attacker, "raid_attacker_ship")
                        + ai_ready_strength(_enemy)
                );
            }
        }
        if (!_affordable_raid) return 0.94;
        if (_best_attack > _defense) return 0.38;
        if (_best_attack == _defense) return 0.68;
        return 0.86;
    };

    ai_capture_delta = function(_player, _ship, _metroid, _cost) {
        var _survival = ai_cargo_survival_probability(_player, _ship);
        var _strength = ai_ready_strength(_player);
        var _security = ai_best_ready_ship_security(_player);
        var _current_loss = ai_containment_loss_at(
            _player, _strength, _security
        );
        var _loaded_loss = ai_containment_loss_at(
            _player, _strength, _security, _metroid
        );
        var _added_containment_risk = max(0, _loaded_loss - _current_loss);
        return (_metroid.definition.research_value * _survival)
            - _added_containment_risk
            - ai_cp_spend_cost(_player, _cost);
    };

    ai_score_bank_cp = function(_player) {
        var _cp = _player.command_points;
        var _plan = {
            score: 0,
            unlock_name: "",
            reaction_cp: 0
        };
        if (_cp <= 0) return _plan;

        // Ending the turn is the unchanged-state baseline.  The useful value of
        // retained CP is charged to actions through ai_cp_spend_cost; it must not
        // also be counted here or it would be paid twice.
        _plan.score = 0;
        var _future_cp = _cp + 4;
        var _best_unlock_bonus = 0;
        for (var _hand_index = 0;
             _hand_index < array_length(_player.hand);
             _hand_index++) {
            var _hand_card = _player.hand[_hand_index];
            if (_hand_card.definition.type == "event") continue;
            var _hand_cost = max(
                0,
                _hand_card.definition.costs.reserve
                    - get_zebes_discount(_player, _hand_card)
            );
            if (_hand_cost > _cp && _hand_cost <= _future_cp) {
                var _hand_unlock_bonus = ai_card_utility(
                    _hand_card, _player
                );
                if (_hand_unlock_bonus > _best_unlock_bonus) {
                    _best_unlock_bonus = _hand_unlock_bonus;
                    _plan.unlock_name = _hand_card.definition.name;
                }
            }
        }
        for (var _shop_index = 0;
             _shop_index < array_length(game_state.shop_row);
             _shop_index++) {
            var _shop_card = game_state.shop_row[_shop_index];
            var _shop_cost = get_modified_deploy_cost(
                _player, _shop_card
            );
            if (!is_real(_shop_cost)
            || _shop_card.definition.type == "event") {
                _shop_cost = get_modified_reserve_cost(
                    _player, _shop_card
                );
            }
            if (is_real(_shop_cost)
            && _shop_cost > _cp
            && _shop_cost <= _future_cp) {
                var _shop_unlock_bonus = ai_card_utility(
                    _shop_card, _player
                );
                if (_shop_unlock_bonus > _best_unlock_bonus) {
                    _best_unlock_bonus = _shop_unlock_bonus;
                    _plan.unlock_name = _shop_card.definition.name;
                }
            }
        }
        // Keep the explanation, but not a second competing score.

        var _zones = [
            _player.board.characters,
            _player.board.ships,
            _player.board.locations
        ];
        for (var _zone_index = 0;
             _zone_index < array_length(_zones);
             _zone_index++) {
            for (var _card_index = 0;
                 _card_index < array_length(_zones[_zone_index]);
                 _card_index++) {
                var _abilities = get_activated_abilities(
                    _zones[_zone_index][_card_index]
                );
                for (var _ability_index = 0;
                     _ability_index < array_length(_abilities);
                     _ability_index++) {
                    if (_abilities[_ability_index].cost_cp > 0
                    && !_abilities[_ability_index].cost_exhaust) {
                        _plan.reaction_cp = max(
                            _plan.reaction_cp,
                            _abilities[_ability_index].cost_cp
                        );
                    }
                }
            }
        }
        return _plan;
    };

    ai_choose_containment_ship = function(_player) {
        var _hazard = get_lab_hazard(_player);
        var _strength = get_ready_character_strength(_player);
        var _has_omega = false;
        for (var _omega_index = 0;
             _omega_index < array_length(_player.lab);
             _omega_index++) {
            if (_player.lab[_omega_index].definition_id == "metroid.omega") {
                _has_omega = true;
                break;
            }
        }
        if (!_has_omega && _hazard <= _strength) {
            ai_debug_log(
                "Containment: " + string(_strength) + " Strength vs "
                + string(_hazard) + " Hazard; no Ship is necessary."
            );
            return -1;
        }
        var _best_index = -1;
        var _best_waste = 100000;
        var _largest_security = -1;
        for (var _ship_index = 0;
             _ship_index < array_length(_player.board.ships);
             _ship_index++) {
            var _ship = _player.board.ships[_ship_index];
            if (!_ship.ready) {
                continue;
            }
            var _security = get_card_stat(_ship, "containment_ship");
            if (_security > _largest_security) {
                _largest_security = _security;
                if (_best_index < 0) {
                    _best_index = _ship_index;
                }
            }
            if (_strength + _security >= _hazard) {
                var _waste = (_strength + _security) - _hazard;
                if (_waste < _best_waste) {
                    _best_waste = _waste;
                    _best_index = _ship_index;
                }
            } else if (_best_waste >= 100000
            && _security == _largest_security) {
                _best_index = _ship_index;
            }
        }
        ai_debug_log(
            "Containment: " + string(_strength) + " Strength vs "
            + string(_hazard) + " Hazard"
            + (_has_omega ? " with an Omega present." : ".")
            + " Chose Ship index " + string(_best_index)
            + (_best_index >= 0
                ? " (" + _player.board.ships[_best_index].definition.name
                    + ", Security "
                    + string(get_card_stat(
                        _player.board.ships[_best_index],
                        "containment_ship"
                    )) + ")."
                : "; no ready Ship was available.")
        );
        return _best_index;
    };

    ai_choose_weakest_character = function(_player, _require_gf_exhausted) {
        var _best_index = -1;
        var _best_value = 100000;
        for (var _index = 0;
             _index < array_length(_player.board.characters);
             _index++) {
            var _character = _player.board.characters[_index];
            if (_require_gf_exhausted
            && (_character.ready || !card_has_faction(_character, "GF"))) {
                continue;
            }
            var _value = ai_card_utility(_character, _player);
            if (_value < _best_value) {
                _best_value = _value;
                _best_index = _index;
            }
        }
        return _best_index;
    };

    ai_score_ability_target = function(_choice, _kind, _index, _player) {
        var _target = get_ability_target_card(_kind, _index);
        if (is_undefined(_target)) {
            return -100000;
        }
        var _opponent_target = string_copy(_kind, 1, 9) == "opponent_";
        var _target_owner = _opponent_target
            ? game_state.players[1 - _player.index]
            : _player;
        var _value = ai_board_card_removal_value(_target, _target_owner);
        switch (_choice.ability.effect_kind) {
            case "ready_ship":
                if (_target.ready
                || _target.ai_readied_by_effect_this_turn) {
                    return -100000;
                }
                // Dane -> GFS Tyr -> +1 CP recreates the exact starting state.
                // Only consider it when HQ will double Tyr's activation, making
                // the sequence a real net gain.
                if (_target.definition_id == "loc.g_f_s_tyr"
                && !_player.next_gf_ability_double) {
                    return -100000;
                }
                return _value + 0.18;
            case "ship_security_1":
            case "ship_security_2":
                return _kind == "ship" && _target.ready
                    ? _value + array_length(_target.cargo) * 0.45
                    : -100000;
            case "exhaust_card":
                if (!_opponent_target || !_target.ready) return -100000;
                return _value + (_target.phazon_tokens >= 3 ? 0.8 : 0);
            case "discard_card":
            case "dark_samus_discard":
                return _opponent_target
                    ? _value
                    : -100000;
            case "dark_samus_consolidate":
                return !_opponent_target
                    ? (_target.phazon_tokens * 0.3) + (_value * 0.15)
                    : -100000;
            case "copy_until_end_turn":
            case "corrupt_copy":
                return _value + (_opponent_target ? 0.08 : 0);
            case "attach_source":
            case "attach_choose_faction":
                return !_opponent_target ? _value : -100000;
            case "leviathan_attach":
                return _opponent_target ? _value + 0.2 : -100000;
            case "quiet_robe_place":
                return _kind == "ship" && _target.ready
                    ? get_card_stat(_target) * 0.12
                    : -100000;
            case "teleport_metroid":
                var _teleport_score = array_length(_target.cargo) > 0
                    ? _target.cargo[0].definition.research_value
                    : -100000;
                if (!is_undefined(raid_suspended_choice)
                && (_target.instance_id
                    == raid_suspended_choice.attacker_ship_id
                    || _target.instance_id
                    == raid_suspended_choice.defender_ship_id)) {
                    _teleport_score += 1;
                }
                return _teleport_score;
            case "deploy_shop_ship":
            case "reserve_shop_event_free":
                return ai_card_utility(_target, _player);
        }
        return _value;
    };

    ai_find_ability_target = function(_choice, _player) {
        var _best = {
            kind: "",
            index: -1,
            score: -100000
        };
        var _target_groups = [
            ["character", game_state.players[game_state.active_player].board.characters],
            ["ship", game_state.players[game_state.active_player].board.ships],
            ["location", game_state.players[game_state.active_player].board.locations],
            ["opponent_character", game_state.players[1 - game_state.active_player].board.characters],
            ["opponent_ship", game_state.players[1 - game_state.active_player].board.ships],
            ["opponent_location", game_state.players[1 - game_state.active_player].board.locations],
            ["shop", game_state.shop_row]
        ];
        for (var _group_index = 0;
             _group_index < array_length(_target_groups);
             _group_index++) {
            var _group_kind = _target_groups[_group_index][0];
            var _group_cards = _target_groups[_group_index][1];
            for (var _target_index = 0;
                 _target_index < array_length(_group_cards);
                 _target_index++) {
                if (!can_resolve_ability_target(
                    _choice,
                    _group_kind,
                    _target_index
                )) {
                    continue;
                }
                var _target_score = ai_score_ability_target(
                    _choice,
                    _group_kind,
                    _target_index,
                    _player
                );
                if (_target_score > _best.score) {
                    _best.kind = _group_kind;
                    _best.index = _target_index;
                    _best.score = _target_score;
                }
            }
        }
        return _best;
    };

    ai_score_ability = function(_source, _ability, _player) {
        var _score = -ai_cp_spend_cost(_player, _ability.cost_cp);
        var _containment_exhaust_cost = _ability.cost_exhaust
            ? ai_containment_exhaust_cost(_player, _source)
            : 0;
        switch (_ability.effect_kind) {
            case "gain_cp": return max(
                0,
                ai_cp_option_value(_player, _player.command_points + 1)
                    - ai_cp_option_value(_player, _player.command_points)
            ) - _containment_exhaust_cost;
            case "prepare_bh_refund":
                if (_player.next_bounty_hunter_refund) return -100000;
                var _has_bh_followup = false;
                for (var _bh_index = 0;
                     _bh_index < array_length(_player.board.characters);
                     _bh_index++) {
                    var _bh_card = _player.board.characters[_bh_index];
                    if (card_has_faction(_bh_card, "BH")
                    && array_length(get_activated_abilities(_bh_card)) > 0) {
                        _has_bh_followup = true;
                        break;
                    }
                }
                return _has_bh_followup
                    ? 0.22 - _containment_exhaust_cost : -100000;
            case "prepare_gf_double":
                if (_player.next_gf_ability_double) return -100000;
                var _has_gf_followup = false;
                for (var _gf_index = 0;
                     _gf_index < array_length(_player.board.characters);
                     _gf_index++) {
                    var _gf_card = _player.board.characters[_gf_index];
                    var _gf_abilities = get_activated_abilities(_gf_card);
                    if (card_has_faction(_gf_card, "GF") && _gf_card.ready) {
                        for (var _gf_ability_index = 0;
                             _gf_ability_index < array_length(_gf_abilities);
                             _gf_ability_index++) {
                            if (_gf_abilities[_gf_ability_index].cost_exhaust) {
                                _has_gf_followup = true;
                                break;
                            }
                        }
                    }
                    if (_has_gf_followup) break;
                }
                return _has_gf_followup
                    ? 0.3 - _containment_exhaust_cost : -100000;
            case "space_pirate_payment":
                var _best_exhausted_pirate_value = -1;
                for (var _pirate_index = 0;
                     _pirate_index < array_length(_player.board.characters);
                     _pirate_index++) {
                    var _pirate = _player.board.characters[_pirate_index];
                    if (!_pirate.ready && card_has_faction(_pirate, "SP")) {
                        _best_exhausted_pirate_value = max(
                            _best_exhausted_pirate_value,
                            ai_card_utility(_pirate, _player)
                        );
                    }
                }
                return _best_exhausted_pirate_value >= 0
                    ? 0.12 + (_best_exhausted_pirate_value * 0.35)
                        - _containment_exhaust_cost
                    : -100000;
            case "ped_strength":
                return _source.phazon_tokens > 0
                    ? (_source.phazon_tokens * 0.12)
                        - ai_cp_spend_cost(_player, _ability.cost_cp)
                        - _containment_exhaust_cost
                    : -100000;
            case "corrupt_all":
                var _own_count = array_length(_player.board.characters)
                    + array_length(_player.board.ships);
                var _enemy = game_state.players[1 - _player.index];
                var _enemy_count = array_length(_enemy.board.characters)
                    + array_length(_enemy.board.ships);
                return ((_enemy_count - _own_count) * 0.12)
                    - _containment_exhaust_cost;
            case "raid_defense_1": return -100000;
        }
        if (_ability.target_kind != "") {
            var _preview_choice = {
                source: _source,
                ability: _ability,
                target_kind: _ability.target_kind
            };
            var _target = ai_find_ability_target(_preview_choice, _player);
            if (_target.index < 0) {
                return -100000;
            }
            _score += _target.score * (
                _ability.effect_kind == "discard_card"
                || _ability.effect_kind == "dark_samus_discard"
                    ? 1
                    : 0.35
            );
        } else {
            _score += 0.08;
        }
        if (_ability.cost_destroy) {
            _score -= ai_card_utility(_source, _player);
        }
        if (_ability.cost_exhaust) {
            _score -= get_card_stat(_source) * 0.03;
            _score -= _containment_exhaust_cost;
        }
        return _score;
    };

    ai_choose_synergy_faction = function(_player) {
        var _factions = ["GF", "SP", "CZ", "BH", "PZ"];
        var _best_faction = "GF";
        var _best_count = -1;
        var _zones = [
            _player.board.characters,
            _player.board.ships,
            _player.board.locations
        ];
        for (var _faction_index = 0;
             _faction_index < array_length(_factions);
             _faction_index++) {
            var _count = 0;
            for (var _zone_index = 0;
                 _zone_index < array_length(_zones);
                 _zone_index++) {
                for (var _card_index = 0;
                     _card_index < array_length(_zones[_zone_index]);
                     _card_index++) {
                    _count += card_has_faction(
                        _zones[_zone_index][_card_index],
                        _factions[_faction_index]
                    ) ? 1 : 0;
                }
            }
            if (_count > _best_count) {
                _best_count = _count;
                _best_faction = _factions[_faction_index];
            }
        }
        return _best_faction;
    };

    ai_raid_exhaustion_score = function(_attacker_index, _defender_index) {
        var _attacker_player = game_state.players[game_state.active_player];
        var _defender_player = game_state.players[1 - game_state.active_player];
        if (_attacker_index < 0
        || _attacker_index >= array_length(_attacker_player.board.ships)
        || _defender_index < 0
        || _defender_index >= array_length(_defender_player.board.ships)
        || array_length(_defender_player.lab) <= 0) {
            return -100000;
        }
        var _attacker = _attacker_player.board.ships[_attacker_index];
        var _defender = _defender_player.board.ships[_defender_index];
        if (!_attacker.ready || array_length(_attacker.cargo) > 0) {
            return -100000;
        }
        var _raid_cost = get_raid_cost(_attacker_player, _defender);
        if (_attacker_player.command_points < _raid_cost) {
            return -100000;
        }

        var _attacker_ship_strength = get_card_stat(
            _attacker,
            "raid_attacker_ship"
        );
        var _attacker_max = _attacker_ship_strength;
        for (var _own_character_index = 0;
             _own_character_index
                < array_length(_attacker_player.board.characters);
             _own_character_index++) {
            var _own_character =
                _attacker_player.board.characters[_own_character_index];
            if (_own_character.ready) {
                _attacker_max += get_card_stat(
                    _own_character,
                    "raid_attacker_character"
                );
            }
        }

        var _defender_base = get_card_stat(
            _defender,
            "raid_defender_ship"
        );
        _defender_base += raid_tyr_support_potential(
            _defender_player, _defender
        );
        var _ready_defender_strength = 0;
        var _defender_strengths = [];
        for (var _defender_character_index = 0;
             _defender_character_index
                < array_length(_defender_player.board.characters);
             _defender_character_index++) {
            var _defender_character =
                _defender_player.board.characters[_defender_character_index];
            if (_defender_character.ready) {
                var _defender_strength = raid_character_contribution(
                    _defender_character,
                    _defender
                );
                _ready_defender_strength += _defender_strength;
                array_push(_defender_strengths, _defender_strength);
            }
        }

        // If committing every attacker could win, use the ordinary raid plan.
        // Tactical raids are specifically sacrificial pressure plays.
        if (_attacker_max > _defender_base + _ready_defender_strength) {
            return -100000;
        }

        // Mirror the defending AI: it commits its strongest ready Character until
        // its Ship plus contributors strictly beats the unsupported attacker.
        var _defense_total = _defender_base;
        var _committed_strength = 0;
        var _committed_count = 0;
        while (_defense_total <= _attacker_ship_strength
        && array_length(_defender_strengths) > 0) {
            var _strongest_position = 0;
            var _strongest_value = _defender_strengths[0];
            for (var _strength_position = 1;
                 _strength_position < array_length(_defender_strengths);
                 _strength_position++) {
                if (_defender_strengths[_strength_position] > _strongest_value) {
                    _strongest_value = _defender_strengths[_strength_position];
                    _strongest_position = _strength_position;
                }
            }
            array_delete(_defender_strengths, _strongest_position, 1);
            _defense_total += _strongest_value;
            _committed_strength += _strongest_value;
            _committed_count += 1;
        }
        if (_committed_count <= 0 || _defense_total <= _attacker_ship_strength) {
            return -100000;
        }

        var _best_ready_ship_security = 0;
        for (var _containment_ship_index = 0;
             _containment_ship_index
                < array_length(_defender_player.board.ships);
             _containment_ship_index++) {
            var _containment_ship =
                _defender_player.board.ships[_containment_ship_index];
            if (_containment_ship.ready) {
                _best_ready_ship_security = max(
                    _best_ready_ship_security,
                    get_card_stat(_containment_ship, "containment_ship")
                );
            }
        }
        var _hazard = get_lab_hazard(_defender_player);
        var _remaining_containment = _ready_defender_strength
            - _committed_strength + _best_ready_ship_security;
        var _containment_deficit = max(0, _hazard - _remaining_containment);
        var _lab_research = get_player_research(_defender_player);
        var _final_round_pressure = game_state.final_round_active ? 2.5 : 0;
        return (_committed_strength * 0.04)
            + (_committed_count * 0.06)
            + (_containment_deficit * 0.3)
            + (_lab_research * 0.08)
            + (_final_round_pressure * 0.2)
            - (ai_card_utility(_attacker, _attacker_player) * 0.35)
            - ai_cp_spend_cost(_attacker_player, _raid_cost);
    };

    ai_raid_plan_score = function(_attacker_index, _defender_index) {
        var _attacker_player = game_state.players[game_state.active_player];
        var _defender_player = game_state.players[1 - game_state.active_player];
        if (_attacker_index < 0
        || _attacker_index >= array_length(_attacker_player.board.ships)
        || _defender_index < 0
        || _defender_index >= array_length(_defender_player.board.ships)) {
            return -100000;
        }
        var _attacker = _attacker_player.board.ships[_attacker_index];
        var _defender = _defender_player.board.ships[_defender_index];
        if (!_attacker.ready) {
            return -100000;
        }
        var _raid_cost = get_raid_cost(_attacker_player, _defender);
        if (_attacker_player.command_points < _raid_cost) {
            return -100000;
        }
        var _attacker_max = get_card_stat(_attacker, "raid_attacker_ship");
        for (var _attacker_character_index = 0;
             _attacker_character_index
                < array_length(_attacker_player.board.characters);
             _attacker_character_index++) {
            var _attacker_character =
                _attacker_player.board.characters[_attacker_character_index];
            if (_attacker_character.ready) {
                _attacker_max += get_card_stat(
                    _attacker_character,
                    "raid_attacker_character"
                );
            }
        }
        var _defender_max = get_card_stat(_defender, "raid_defender_ship");
        _defender_max += raid_tyr_support_potential(
            _defender_player, _defender
        );
        for (var _defender_character_index = 0;
             _defender_character_index
                < array_length(_defender_player.board.characters);
             _defender_character_index++) {
            var _defender_character =
                _defender_player.board.characters[_defender_character_index];
            if (_defender_character.ready) {
                _defender_max += raid_character_contribution(
                    _defender_character,
                    _defender
                );
            }
        }
        var _defender_has_raid_boost = false;
        for (var _boost_character_index = 0;
             _boost_character_index
                < array_length(_defender_player.board.characters);
             _boost_character_index++) {
            var _boost_abilities = get_activated_abilities(
                _defender_player.board.characters[_boost_character_index]
            );
            for (var _boost_ability_index = 0;
                 _boost_ability_index < array_length(_boost_abilities);
                 _boost_ability_index++) {
                if (_boost_abilities[_boost_ability_index].effect_kind
                == "raid_defense_1") {
                    _defender_has_raid_boost = true;
                    break;
                }
            }
            if (_defender_has_raid_boost) break;
        }
        if (_defender_has_raid_boost) {
            _defender_max += _defender_player.command_points;
        }
        if (_attacker_max <= _defender_max) {
            return ai_raid_exhaustion_score(
                _attacker_index,
                _defender_index
            );
        }
        var _cargo_value = 0;
        for (var _cargo_index = 0;
             _cargo_index < array_length(_defender.cargo);
             _cargo_index++) {
            var _cargo = _defender.cargo[_cargo_index];
            // Destroying the carrier denies the opponent this research path.
            _cargo_value += _cargo.definition.research_value;
            // If the attacker has room and Security, the same Metroid enters
            // the attacker's pipeline: denial plus acquisition is a true swing.
            if (array_length(_attacker.cargo) <= 0
            && _cargo.definition.hazard <= get_card_stat(_attacker)) {
                _cargo_value += _cargo.definition.research_value
                    * ai_cargo_survival_probability(
                        _attacker_player, _attacker
                    );
            }
        }
        var _defender_board_loss = ai_board_card_removal_value(
            _defender, _defender_player
        );
        // Predict the same strongest-first contributor set used when the raid is
        // declared, then charge the exact containment loss created by exhausting
        // those Characters and the attacking Ship.
        var _required_character_strength = 0;
        var _predicted_attack = get_card_stat(
            _attacker, "raid_attacker_ship"
        );
        var _available_strengths = [];
        for (var _commit_index = 0;
             _commit_index < array_length(_attacker_player.board.characters);
             _commit_index++) {
            var _commit_card = _attacker_player.board.characters[_commit_index];
            if (_commit_card.ready) {
                array_push(
                    _available_strengths,
                    get_card_stat(_commit_card, "raid_attacker_character")
                );
            }
        }
        while (_predicted_attack <= _defender_max
        && array_length(_available_strengths) > 0) {
            var _strongest_position = 0;
            for (var _strength_index = 1;
                 _strength_index < array_length(_available_strengths);
                 _strength_index++) {
                if (_available_strengths[_strength_index]
                > _available_strengths[_strongest_position]) {
                    _strongest_position = _strength_index;
                }
            }
            var _committed = _available_strengths[_strongest_position];
            array_delete(_available_strengths, _strongest_position, 1);
            _predicted_attack += _committed;
            _required_character_strength += _committed;
        }
        var _before_containment_loss = ai_lab_failure_cost(_attacker_player);
        var _after_containment_loss = ai_containment_loss_at(
            _attacker_player,
            max(
                0,
                ai_ready_strength(_attacker_player)
                    - _required_character_strength
            ),
            ai_best_other_ship_security(
                _attacker_player, _attacker.instance_id
            )
        );
        var _raid_containment_cost = max(
            0, _after_containment_loss - _before_containment_loss
        );
        return _defender_board_loss
            + _cargo_value
            - ai_cp_spend_cost(_attacker_player, _raid_cost)
            - _raid_containment_cost
            - max(0, _defender_max - get_card_stat(
                _attacker,
                "raid_attacker_ship"
            )) * 0.03
            - ai_card_utility(_attacker, _attacker_player) * 0.08;
    };

    ai_resolve_raid_defense = function() {
        if (is_undefined(pending_choice)
        || pending_choice.kind != "raid"
        || pending_choice.stage != "defenders") {
            return false;
        }
        var _raid = pending_choice;
        var _attacker_player = game_state.players[game_state.active_player];
        var _defender_player = game_state.players[1 - game_state.active_player];
        var _attacker = raid_get_ship(
            _attacker_player, _raid.attacker_ship_id
        );
        var _defender = raid_get_ship(
            _defender_player, _raid.defender_ship_id
        );
        if (is_undefined(_attacker) || is_undefined(_defender)) {
            return resolve_raid();
        }
        var _attacker_total = get_card_stat(
            _attacker,
            "raid_attacker_ship"
        ) + _raid.attacker_ability_bonus;
        for (var _attacker_character_index = 0;
             _attacker_character_index
                < array_length(_raid.attacker_characters);
             _attacker_character_index++) {
            var _committed_attacker_index = raid_find_instance_index(
                _attacker_player.board.characters,
                _raid.attacker_characters[_attacker_character_index]
            );
            if (_committed_attacker_index >= 0) {
                _attacker_total += get_card_stat(
                    _attacker_player.board.characters[_committed_attacker_index],
                    "raid_attacker_character"
                );
            }
        }
        var _defender_base = get_card_stat(
            _defender,
            "raid_defender_ship"
        ) + _raid.defender_ability_bonus;
        var _available_indices = [];
        var _available_strength = 0;
        for (var _defender_character_index = 0;
             _defender_character_index
                < array_length(_defender_player.board.characters);
             _defender_character_index++) {
            var _defender_character =
                _defender_player.board.characters[_defender_character_index];
            if (_defender_character.ready) {
                array_push(_available_indices, _defender_character_index);
                _available_strength += raid_character_contribution(
                    _defender_character,
                    _defender
                );
            }
        }

        var _maximum_without_ability = _defender_base + _available_strength;
        if (_maximum_without_ability <= _attacker_total) {
            var _tyr_supporters = [];
            var _tyr_support_total = 0;
            var _tyr_support_value = card_has_faction(_defender, "GF") ? 2 : 1;
            for (var _tyr_ship_index = 0;
                 _tyr_ship_index < array_length(_defender_player.board.ships);
                 _tyr_ship_index++) {
                var _tyr_ship = _defender_player.board.ships[_tyr_ship_index];
                if (_tyr_ship.definition_id == "loc.g_f_s_tyr"
                && _tyr_ship.instance_id != _defender.instance_id
                && _tyr_ship.ready) {
                    array_push(_tyr_supporters, _tyr_ship.instance_id);
                    _tyr_support_total += _tyr_support_value;
                }
            }
            if (_maximum_without_ability + _tyr_support_total
            > _attacker_total) {
                for (var _tyr_support_index = 0;
                     _tyr_support_index < array_length(_tyr_supporters)
                        && _maximum_without_ability <= _attacker_total;
                     _tyr_support_index++) {
                    var _current_tyr_index = raid_find_instance_index(
                        _defender_player.board.ships,
                        _tyr_supporters[_tyr_support_index]
                    );
                    if (_current_tyr_index < 0) continue;
                    var _current_tyr = _defender_player.board.ships[
                        _current_tyr_index
                    ];
                    var _current_tyr_abilities = get_activated_abilities(
                        _current_tyr
                    );
                    for (var _current_tyr_ability_index = 0;
                         _current_tyr_ability_index
                            < array_length(_current_tyr_abilities);
                         _current_tyr_ability_index++) {
                        if (_current_tyr_abilities[
                            _current_tyr_ability_index
                        ].effect_kind == "tyr_raid_support") {
                            var _tyr_target_index = raid_find_instance_index(
                                _defender_player.board.ships,
                                _defender.instance_id
                            );
                            var _tyr_started = activate_selected_ability(
                                "opponent_ship",
                                _current_tyr_index,
                                _current_tyr_ability_index
                            );
                            var _tyr_resolved = _tyr_started
                                && _tyr_target_index >= 0
                                && resolve_ability_target_choice(
                                    "opponent_ship", _tyr_target_index
                                );
                            if (is_undefined(pending_choice)) {
                                pending_choice = _raid;
                            }
                            if (_tyr_resolved) {
                                _maximum_without_ability += _tyr_support_value;
                                _defender_base += _tyr_support_value;
                                ai_debug_log(
                                    "Raid defense: G.F.S. Tyr added +"
                                        + string(_tyr_support_value)
                                        + " Security to "
                                        + _defender.definition.name + "."
                                );
                            }
                            break;
                        }
                    }
                }
            }
        }
        if (_maximum_without_ability <= _attacker_total
        && _defender_player.command_points > 0
        && _maximum_without_ability + _defender_player.command_points
            >= _attacker_total) {
            var _defense_needed = _attacker_total
                - _maximum_without_ability + 1;
            var _samus_index = -1;
            var _samus_ability_index = -1;
            for (var _samus_character_index = 0;
                 _samus_character_index
                    < array_length(_defender_player.board.characters);
                 _samus_character_index++) {
                var _samus_abilities = get_activated_abilities(
                    _defender_player.board.characters[_samus_character_index]
                );
                for (var _samus_candidate_index = 0;
                     _samus_candidate_index < array_length(_samus_abilities);
                     _samus_candidate_index++) {
                    if (_samus_abilities[_samus_candidate_index].effect_kind
                    == "raid_defense_1") {
                        _samus_index = _samus_character_index;
                        _samus_ability_index = _samus_candidate_index;
                        break;
                    }
                }
                if (_samus_index >= 0) break;
            }
            var _defense_spend = min(
                _defense_needed,
                _defender_player.command_points
            );
            for (var _defense_activation = 0;
                 _defense_activation < _defense_spend
                    && _samus_index >= 0;
                 _defense_activation++) {
                activate_selected_ability(
                    "opponent_character",
                    _samus_index,
                    _samus_ability_index
                );
            }
            _defender_base = get_card_stat(
                _defender,
                "raid_defender_ship"
            ) + _raid.defender_ability_bonus;
            if (_defense_spend > 0 && _samus_index >= 0) {
                ai_debug_log(
                    "Raid defense ability: spent "
                    + string(_defense_spend)
                    + " CP through Samus for +"
                    + string(_defense_spend) + " defense."
                );
            }
        }

        _raid.defender_characters = [];
        if (_defender_base + _available_strength >= _attacker_total) {
            var _defense_total = _defender_base;
            while (_defense_total <= _attacker_total
            && array_length(_available_indices) > 0) {
                var _best_position = 0;
                var _best_strength = -1;
                var _best_commitment_score = -100000;
                for (var _candidate_position = 0;
                     _candidate_position < array_length(_available_indices);
                     _candidate_position++) {
                    var _candidate_index =
                        _available_indices[_candidate_position];
                    var _candidate_strength = raid_character_contribution(
                        _defender_player.board.characters[_candidate_index],
                        _defender
                    );
                    var _candidate_card = _defender_player.board.characters[
                        _candidate_index
                    ];
                    var _candidate_commitment_score = _candidate_strength * 100;
                    if (_candidate_card.definition_id == "loc.gf_soldier"
                    && array_length(_attacker_player.lab) > 0) {
                        // Preserve the post-defense breach trigger when another
                        // equal contributor can secure the same Raid result.
                        _candidate_commitment_score -= 50;
                    }
                    if (_candidate_commitment_score
                    > _best_commitment_score) {
                        _best_strength = _candidate_strength;
                        _best_commitment_score = _candidate_commitment_score;
                        _best_position = _candidate_position;
                    }
                }
                var _chosen_index = _available_indices[_best_position];
                array_delete(_available_indices, _best_position, 1);
                array_push(
                    _raid.defender_characters,
                    _defender_player.board.characters[_chosen_index].instance_id
                );
                _defense_total += _best_strength;
            }
            ai_debug_log(
                "Raid defense: committed "
                + string(array_length(_raid.defender_characters))
                + " Character(s) for " + string(_defense_total)
                + " total against " + string(_attacker_total) + "."
            );
        } else {
            ai_debug_log(
                "Raid defense: maximum " + string(
                    _defender_base + _available_strength
                ) + " cannot tie " + string(_attacker_total)
                + "; preserving Characters and conceding the Ship."
            );
        }
        return resolve_raid();
    };

    ai_resolve_pending_choice = function() {
        if (is_undefined(pending_choice)) {
            return false;
        }
        var _choice = pending_choice;
        ai_debug_log("Mandatory choice: " + _choice.kind + ".");
        switch (_choice.kind) {
            case "back_in_the_day":
                var _back_player = game_state.players[_choice.player_index];
                var _back_best_index = 0;
                var _back_best_score = -100000;
                for (var _back_candidate_index = 0;
                     _back_candidate_index
                        < array_length(_choice.candidate_ids);
                     _back_candidate_index++) {
                    var _back_definition_id =
                        _choice.candidate_ids[_back_candidate_index];
                    for (var _back_shop_index = 0;
                         _back_shop_index
                            < array_length(game_state.shop_deck);
                         _back_shop_index++) {
                        var _back_card = game_state.shop_deck[_back_shop_index];
                        if (_back_card.definition_id != _back_definition_id) {
                            continue;
                        }
                        var _back_score = ai_card_utility(
                            _back_card, _back_player
                        );
                        if (_back_score > _back_best_score) {
                            _back_best_score = _back_score;
                            _back_best_index = _back_candidate_index;
                        }
                        break;
                    }
                }
                ai_debug_log(
                    "Back In the Day: selected "
                    + _choice.candidate_names[_back_best_index] + "."
                );
                return resolve_back_in_the_day_choice(_back_best_index);

            case "raid":
                if (_choice.stage == "target") {
                    var _best_raid_target = -1;
                    var _best_raid_score = -100000;
                    for (var _raid_target_index = 0;
                         _raid_target_index < array_length(
                            game_state.players[
                                1 - game_state.active_player
                            ].board.ships
                         );
                         _raid_target_index++) {
                        var _raid_plan_attacker_index = raid_find_instance_index(
                            game_state.players[game_state.active_player].board.ships,
                            _choice.attacker_ship_id
                        );
                        var _raid_score = ai_raid_plan_score(
                            _raid_plan_attacker_index,
                            _raid_target_index
                        );
                        if (_raid_score > _best_raid_score) {
                            _best_raid_score = _raid_score;
                            _best_raid_target = _raid_target_index;
                        }
                    }
                    ai_debug_log(
                        "Raid target: selected Ship index "
                        + string(_best_raid_target) + " with score "
                        + string_format(_best_raid_score, 0, 2) + "."
                    );
                    return select_raid_target(_best_raid_target);
                }
                if (_choice.stage == "attackers") {
                    var _raid_attacker_player =
                        game_state.players[game_state.active_player];
                    var _raid_defender_player =
                        game_state.players[1 - game_state.active_player];
                    var _raid_live_attacker_index = raid_find_instance_index(
                        _raid_attacker_player.board.ships,
                        _choice.attacker_ship_id
                    );
                    var _raid_live_defender_index = raid_find_instance_index(
                        _raid_defender_player.board.ships,
                        _choice.defender_ship_id
                    );
                    var _raid_attacker_ship = raid_get_ship(
                        _raid_attacker_player, _choice.attacker_ship_id
                    );
                    var _raid_defender_ship = raid_get_ship(
                        _raid_defender_player, _choice.defender_ship_id
                    );
                    if (is_undefined(_raid_attacker_ship)
                    || is_undefined(_raid_defender_ship)) return resolve_raid();
                    var _exhaustion_raid_score = ai_raid_exhaustion_score(
                        _raid_live_attacker_index,
                        _raid_live_defender_index
                    );
                    if (_exhaustion_raid_score > -100000) {
                        _choice.attacker_characters = [];
                        ai_debug_log(
                            "Raid attackers: tactical exhaustion raid; "
                            + "committed no Characters at score "
                            + string_format(_exhaustion_raid_score, 0, 2) + "."
                        );
                        return lock_raid_attackers();
                    }
                    var _attack_total = get_card_stat(
                        _raid_attacker_ship,
                        "raid_attacker_ship"
                    ) + _choice.attacker_ability_bonus;
                    var _expected_defense = get_card_stat(
                        _raid_defender_ship,
                        "raid_defender_ship"
                    );
                    for (var _expected_defender_index = 0;
                         _expected_defender_index < array_length(
                            _raid_defender_player.board.characters
                         );
                         _expected_defender_index++) {
                        var _expected_defender =
                            _raid_defender_player.board.characters[
                                _expected_defender_index
                            ];
                        if (_expected_defender.ready) {
                            _expected_defense += get_card_stat(
                                _expected_defender,
                                "raid_defender_character"
                            );
                        }
                    }
                    var _expected_raid_boost = false;
                    for (var _expected_boost_index = 0;
                         _expected_boost_index < array_length(
                            _raid_defender_player.board.characters
                         );
                         _expected_boost_index++) {
                        var _expected_boost_abilities = get_activated_abilities(
                            _raid_defender_player.board.characters[
                                _expected_boost_index
                            ]
                        );
                        for (var _expected_ability_index = 0;
                             _expected_ability_index
                                < array_length(_expected_boost_abilities);
                             _expected_ability_index++) {
                            if (_expected_boost_abilities[
                                _expected_ability_index
                            ].effect_kind == "raid_defense_1") {
                                _expected_raid_boost = true;
                                break;
                            }
                        }
                        if (_expected_raid_boost) break;
                    }
                    if (_expected_raid_boost) {
                        _expected_defense +=
                            _raid_defender_player.command_points;
                    }
                    _choice.attacker_characters = [];
                    while (_attack_total <= _expected_defense) {
                        var _best_attacker_index = -1;
                        var _best_attacker_strength = -1;
                        for (var _attacker_option_index = 0;
                             _attacker_option_index < array_length(
                                _raid_attacker_player.board.characters
                             );
                             _attacker_option_index++) {
                            var _attacker_option =
                                _raid_attacker_player.board.characters[
                                    _attacker_option_index
                                ];
                            if (_attacker_option.ready
                            && !raid_array_contains(
                                _choice.attacker_characters,
                                _attacker_option.instance_id
                            )) {
                                var _attacker_strength = get_card_stat(
                                    _attacker_option,
                                    "raid_attacker_character"
                                );
                                if (_attacker_strength > _best_attacker_strength) {
                                    _best_attacker_strength = _attacker_strength;
                                    _best_attacker_index = _attacker_option_index;
                                }
                            }
                        }
                        if (_best_attacker_index < 0) break;
                        array_push(
                            _choice.attacker_characters,
                            _raid_attacker_player.board.characters[
                                _best_attacker_index
                            ].instance_id
                        );
                        _attack_total += _best_attacker_strength;
                    }
                    ai_debug_log(
                        "Raid attackers: committed "
                        + string(array_length(_choice.attacker_characters))
                        + " Character(s) for expected " + string(_attack_total)
                        + " vs maximum defense "
                        + string(_expected_defense) + "."
                    );
                    return lock_raid_attackers();
                }
                if (_choice.stage == "defenders") {
                    return ai_resolve_raid_defense();
                }
                return false;

            case "queen_event":
                return _choice.stage == "revealed"
                    ? resolve_queen_shop_event()
                    : finish_queen_shop_event();

            case "researcher_discard":
                var _researcher_player =
                    game_state.players[game_state.active_player];
                var _worst_hand_index = -1;
                var _worst_hand_value = 100000;
                for (var _hand_index = 0;
                     _hand_index < array_length(_researcher_player.hand);
                     _hand_index++) {
                    var _hand_value = ai_card_utility(
                        _researcher_player.hand[_hand_index],
                        _researcher_player
                    );
                    if (_hand_value < _worst_hand_value) {
                        _worst_hand_value = _hand_value;
                        _worst_hand_index = _hand_index;
                    }
                }
                ai_debug_log(
                    "Researcher discard: chose hand index "
                    + string(_worst_hand_index)
                    + (_worst_hand_index >= 0
                        ? " (" + _researcher_player.hand[
                            _worst_hand_index
                        ].definition.name + ") because it had the lowest utility."
                        : " because the hand is empty.")
                );
                return resolve_researcher_discard(_worst_hand_index);

            case "chozo_ghosts_source":
                var _ghost_sources = chozo_ghosts_find_sources(
                    _choice.player_index,
                    _choice.ghost
                );
                if (array_length(_ghost_sources) <= 0) return false;
                var _ghost_source = _ghost_sources[0];
                for (var _ghost_source_index = 1;
                     _ghost_source_index < array_length(_ghost_sources);
                     _ghost_source_index++) {
                    if (_ghost_sources[_ghost_source_index].phazon_tokens
                    > _ghost_source.phazon_tokens) {
                        _ghost_source = _ghost_sources[_ghost_source_index];
                    }
                }
                return resolve_chozo_ghosts_source(_ghost_source);

            case "chozo_ghosts_target":
                var _ghost_targets = game_state.players[
                    _choice.target_player_index
                ].board.characters;
                if (array_length(_ghost_targets) <= 0) {
                    return resolve_chozo_ghosts_target(undefined);
                }
                var _ghost_target = _ghost_targets[0];
                var _ghost_target_value = ai_card_utility(
                    _ghost_target,
                    game_state.players[_choice.target_player_index]
                );
                for (var _ghost_target_index = 1;
                     _ghost_target_index < array_length(_ghost_targets);
                     _ghost_target_index++) {
                    var _candidate_value = ai_card_utility(
                        _ghost_targets[_ghost_target_index],
                        game_state.players[_choice.target_player_index]
                    );
                    if (_candidate_value > _ghost_target_value) {
                        _ghost_target = _ghost_targets[_ghost_target_index];
                        _ghost_target_value = _candidate_value;
                    }
                }
                return resolve_chozo_ghosts_target(_ghost_target);

            case "hyper_mode_character":
                var _hyper_player = game_state.players[_choice.player_index];
                var _hyper_best_index = -1;
                var _hyper_best_value = -100000;
                for (var _hyper_index = 0;
                     _hyper_index < array_length(_hyper_player.board.characters);
                     _hyper_index++) {
                    var _hyper_value = ai_card_utility(
                        _hyper_player.board.characters[_hyper_index],
                        _hyper_player
                    );
                    if (_hyper_value > _hyper_best_value) {
                        _hyper_best_value = _hyper_value;
                        _hyper_best_index = _hyper_index;
                    }
                }
                ai_debug_log(
                    "Hyper Mode: consolidated "
                        + string(_choice.tokens_removed)
                        + " token(s) onto Character index "
                        + string(_hyper_best_index) + "."
                );
                return resolve_hyper_mode_character(_hyper_best_index);

            case "ability_target":
                if (variable_struct_exists(_choice, "multi_select")
                && _choice.multi_select
                && _choice.ability.effect_kind == "dark_samus_discard") {
                    var _multi_opponent = game_state.players[
                        1 - game_state.active_player
                    ];
                    while (true) {
                        var _best_multi_index = -1;
                        var _best_multi_value = -100000;
                        for (var _multi_index = 0;
                             _multi_index < array_length(
                                _multi_opponent.board.characters
                             );
                             _multi_index++) {
                            var _multi_target =
                                _multi_opponent.board.characters[_multi_index];
                            if (raid_array_contains(
                                _choice.selected_targets,
                                _multi_target.instance_id
                            ) || !can_resolve_ability_target(
                                _choice,
                                "opponent_character",
                                _multi_index
                            )) continue;
                            var _multi_value = ai_card_utility(
                                _multi_target,
                                _multi_opponent
                            );
                            if (_multi_value > _best_multi_value) {
                                _best_multi_value = _multi_value;
                                _best_multi_index = _multi_index;
                            }
                        }
                        if (_best_multi_index < 0) break;
                        toggle_dark_samus_discard_target(
                            "opponent_character",
                            _best_multi_index
                        );
                    }
                    return confirm_dark_samus_discard();
                }
                var _ability_player =
                    game_state.players[game_state.priority_player];
                var _ability_target = ai_find_ability_target(
                    _choice,
                    _ability_player
                );
                if (_ability_target.index < 0) {
                    ai_debug_log("Ability target: no useful legal target found.");
                    return false;
                }
                ai_debug_log(
                    "Ability target: selected " + _ability_target.kind
                    + " index " + string(_ability_target.index)
                    + " with score "
                    + string_format(_ability_target.score, 0, 2) + "."
                );
                return resolve_ability_target_choice(
                    _ability_target.kind,
                    _ability_target.index
                );

            case "teleport_destination":
                var _teleport_player = game_state.players[
                    _choice.player_index
                ];
                var _best_teleport_destination = -1;
                var _best_teleport_destination_score = -100000;
                for (var _teleport_ship_index = 0;
                     _teleport_ship_index
                        < array_length(_teleport_player.board.ships);
                     _teleport_ship_index++) {
                    var _teleport_ship =
                        _teleport_player.board.ships[_teleport_ship_index];
                    if (_teleport_ship.instance_id == _choice.cargo_ship_id
                    || !card_has_faction(_teleport_ship, "CZ")
                    || array_length(_teleport_ship.cargo) >= 1) continue;
                    var _teleport_destination_score =
                        get_card_stat(_teleport_ship, "raid_defender_ship");
                    if (_teleport_ship.definition_id
                    == "loc.chozo_transport") {
                        _teleport_destination_score += 4;
                    }
                    if (_teleport_destination_score
                    > _best_teleport_destination_score) {
                        _best_teleport_destination_score =
                            _teleport_destination_score;
                        _best_teleport_destination = _teleport_ship_index;
                    }
                }
                if (_best_teleport_destination < 0) return false;
                var _teleport_kind = _choice.player_index
                    == game_state.active_player ? "ship" : "opponent_ship";
                return resolve_teleport_destination_choice(
                    _teleport_kind,
                    _best_teleport_destination
                );

            case "quiet_robe_metroids":
                var _best_metroid_source = -1;
                var _best_metroid_score = -100000;
                for (var _metroid_source = 0;
                     _metroid_source < 5;
                     _metroid_source++) {
                    if (!can_select_quiet_robe_metroid(_metroid_source)) {
                        continue;
                    }
                    var _quiet_metroid =
                        get_sr388_metroid_for_choice(_metroid_source);
                    var _quiet_score =
                        _quiet_metroid.definition.research_value * 3
                        - _quiet_metroid.definition.hazard * 0.2;
                    if (_quiet_score > _best_metroid_score) {
                        _best_metroid_score = _quiet_score;
                        _best_metroid_source = _metroid_source;
                    }
                }
                ai_debug_log(
                    "Quiet Robe: selected Metroid source "
                    + string(_best_metroid_source) + " with score "
                    + string_format(_best_metroid_score, 0, 2) + "."
                );
                if (_best_metroid_source < 0) {
                    array_push(
                        game_state.event_log,
                        "AI recovery: Quiet Robe had no legal remaining Metroid; "
                        + "its selection ended early."
                    );
                    pending_choice = undefined;
                    game_state.priority_player = game_state.active_player;
                    return true;
                }
                return resolve_quiet_robe_metroid_choice(
                    _best_metroid_source
                );

            case "special_containment_ship":
                var _special_player =
                    game_state.players[_choice.player_index];
                var _special_ship_index = ai_choose_containment_ship(
                    _special_player
                );
                if (is_undefined(special_containment_sequence)) {
                    array_push(
                        game_state.event_log,
                        "AI recovery: cleared an orphaned special containment "
                        + "choice after its sequence ended."
                    );
                    pending_choice = undefined;
                    game_state.priority_player = game_state.active_player;
                    return true;
                }
                if (_special_ship_index < 0
                || _special_ship_index >= array_length(
                    _special_player.board.ships
                )
                || !_special_player.board.ships[_special_ship_index].ready) {
                    _special_ship_index = -1;
                }
                // The AI always declines Adam's optional destruction. Resolve the
                // current special-containment entry directly so the mandatory
                // prompt cannot survive a nominally successful AI step.
                ai_debug_log(
                    "Special containment: resolving directly with Ship index "
                    + string(_special_ship_index) + "."
                );
                return resolve_special_containment_now(_special_ship_index);

            case "adam_breach":
                ai_debug_log(
                    "Adam Malkovich: declined optional Ship contribution; "
                    + "preserving the Ship for later actions."
                );
                return resolve_adam_breach_choice(false);

            case "breach_character":
                var _breach_player =
                    game_state.players[_choice.player_index];
                var _breach_character_index = ai_choose_weakest_character(
                    _breach_player,
                    false
                );
                ai_debug_log(
                    "Breach casualty: chose character index "
                    + string(_breach_character_index)
                    + (_breach_character_index >= 0
                        ? " (" + _breach_player.board.characters[
                            _breach_character_index
                        ].definition.name + ") because it had the lowest utility."
                        : " because no Character can be discarded.")
                );
                return resolve_breach_character_choice(
                    _breach_character_index
                );

            case "olympus_ready":
                var _olympus_player =
                    game_state.players[_choice.player_index];
                var _olympus_character_index = ai_choose_weakest_character(
                    _olympus_player,
                    true
                );
                ai_debug_log(
                    "Olympus ready choice: chose GF Character index "
                    + string(_olympus_character_index) + "."
                );
                return resolve_olympus_ready_choice(
                    _olympus_character_index
                );

            case "space_pirate_payment":
                ai_debug_log(
                    "Space Pirate payment: "
                    + (game_state.players[_choice.payer_index].command_points > 2
                        ? "paying because more than 2 CP remain."
                        : "declining because the remaining CP is too valuable.")
                );
                return resolve_space_pirate_payment(
                    game_state.players[_choice.payer_index].command_points > 2
                );

            case "space_pirate_ready":
                var _ready_player =
                    game_state.players[_choice.owner_index];
                var _ready_choice = -1;
                var _ready_value = -100000;
                for (var _ready_index = 0;
                     _ready_index < array_length(_ready_player.board.characters);
                     _ready_index++) {
                    var _ready_character =
                        _ready_player.board.characters[_ready_index];
                    if (!_ready_character.ready
                    && card_has_faction(_ready_character, "SP")) {
                        var _candidate_value =
                            ai_card_utility(_ready_character, _ready_player);
                        if (_candidate_value > _ready_value) {
                            _ready_value = _candidate_value;
                            _ready_choice = _ready_index;
                        }
                    }
                }
                ai_debug_log(
                    "Space Pirate ready choice: chose Character index "
                    + string(_ready_choice)
                    + " because it had the highest utility among legal targets."
                );
                return resolve_space_pirate_ready(
                    _choice.owner_index == game_state.active_player
                        ? "character"
                        : "opponent_character",
                    _ready_choice
                );

            case "choose_faction":
                var _chosen_faction = ai_choose_synergy_faction(
                    game_state.players[game_state.priority_player]
                );
                ai_debug_log(
                    "Faction choice: selected " + _chosen_faction
                    + " to match the largest existing faction group."
                );
                return resolve_faction_choice(_chosen_faction);

            case "raid_cargo":
                var _losing_player = _choice.winner_is_attacker
                    ? game_state.players[1 - game_state.active_player]
                    : game_state.players[game_state.active_player];
                var _losing_ship = raid_get_ship(
                    _losing_player,
                    _choice.winner_is_attacker
                        ? _choice.defender_ship_id
                        : _choice.attacker_ship_id
                );
                if (is_undefined(_losing_ship)
                || !variable_struct_exists(_losing_ship, "cargo")
                || array_length(_losing_ship.cargo) <= 0) {
                    return false;
                }
                var _best_cargo_index = 0;
                var _best_cargo_research = -1;
                for (var _cargo_index = 0;
                     _cargo_index < array_length(_losing_ship.cargo);
                     _cargo_index++) {
                    var _cargo_research = _losing_ship.cargo[
                        _cargo_index
                    ].definition.research_value;
                    if (_cargo_research > _best_cargo_research) {
                        _best_cargo_research = _cargo_research;
                        _best_cargo_index = _cargo_index;
                    }
                }
                ai_debug_log(
                    "Raid cargo: chose cargo index "
                    + string(_best_cargo_index)
                    + " because it had the highest Research value."
                );
                return finish_attacker_raid_win(_best_cargo_index);
        }
        return false;
    };

    ai_select_action = function() {
        var _player = game_state.players[game_state.active_player];
        if (ai_salvage_goal_instance_id >= 0) {
            for (var _goal_index = 0;
                 _goal_index < array_length(game_state.shop_row);
                 _goal_index++) {
                if (game_state.shop_row[_goal_index].instance_id
                != ai_salvage_goal_instance_id) continue;
                var _goal_deploy_cost = get_modified_deploy_cost(
                    _player,
                    game_state.shop_row[_goal_index]
                );
                var _goal_reserve_cost = get_modified_reserve_cost(
                    _player,
                    game_state.shop_row[_goal_index]
                );
                if (ai_salvage_goal_mode == "deploy"
                && is_real(_goal_deploy_cost)
                && _player.command_points >= _goal_deploy_cost) {
                    ai_last_action = "Completing salvage plan: deploying "
                        + game_state.shop_row[_goal_index].definition.name;
                    ai_salvage_goal_instance_id = -1;
                    ai_salvage_goal_mode = "";
                    return deploy_shop_card(_goal_index);
                }
                if (ai_salvage_goal_mode == "reserve"
                && is_real(_goal_reserve_cost)
                && _player.command_points >= _goal_reserve_cost) {
                    ai_last_action = "Completing salvage plan: reserving "
                        + game_state.shop_row[_goal_index].definition.name;
                    ai_salvage_goal_instance_id = -1;
                    ai_salvage_goal_mode = "";
                    return reserve_shop_card(_goal_index);
                }
                break;
            }
            // The intended card vanished or is still unaffordable; abandon the
            // plan rather than chaining unrelated plays or further salvage.
            ai_salvage_goal_instance_id = -1;
            ai_salvage_goal_mode = "";
        }
        var _best_kind = "end";
        var _best_index = -1;
        var _best_secondary = -1;
        var _best_source_kind = "";
        var _best_ability_index = -1;
        var _best_refresh_indices = [];
        var _best_refresh_ship_search = false;
        var _best_salvage_goal_id = -1;
        var _best_salvage_goal_mode = "";
        var _best_visible_shop_score = -100000;
        var _turn_candidates = [];
        ai_eval_utility_cache = {};
        ai_eval_cache_active = true;
        ai_planner_collecting = true;
        var _bank_plan = ai_score_bank_cp(_player);
        // Deltas at or below two hundredths of a safe capture are evaluation
        // noise. Ending the turn remains the zero-delta baseline.
        var _best_score = 0.02;
        ai_debug_log(
            "Evaluating action phase with " + string(_player.command_points)
            + " CP, " + string(array_length(_player.hand)) + " cards in hand, "
            + "and " + string(array_length(game_state.shop_row))
            + " Shop cards."
        );
        ai_debug_log(
            "Bank CP candidate: retain " + string(_player.command_points)
            + " CP; score " + string_format(_bank_plan.score, 0, 2)
            + (_bank_plan.unlock_name != ""
                ? ", next-turn access to " + _bank_plan.unlock_name
                : "")
            + (_bank_plan.reaction_cp > 0
                ? ", preserves paid board options"
                : "")
            + "."
        );

        var _ability_zones = [
            ["character", _player.board.characters],
            ["ship", _player.board.ships],
            ["location", _player.board.locations]
        ];
        for (var _ability_zone_index = 0;
             _ability_zone_index < array_length(_ability_zones);
             _ability_zone_index++) {
            var _ability_source_kind = _ability_zones[_ability_zone_index][0];
            var _ability_cards = _ability_zones[_ability_zone_index][1];
            for (var _ability_source_index = 0;
                 _ability_source_index < array_length(_ability_cards);
                 _ability_source_index++) {
                var _ability_source = _ability_cards[_ability_source_index];
                var _source_abilities = get_activated_abilities(_ability_source);
                for (var _ability_index = 0;
                     _ability_index < array_length(_source_abilities);
                     _ability_index++) {
                    if (!can_activate_selected_ability(
                        _ability_source_kind,
                        _ability_source_index,
                        _ability_index
                    )) {
                        continue;
                    }
                    var _ability_score = ai_score_ability(
                        _ability_source,
                        _source_abilities[_ability_index],
                        _player
                    );
                    ai_debug_log(
                        "Ability candidate: " + _ability_source.definition.name
                        + " / " + _source_abilities[_ability_index].effect_kind
                        + "; score "
                        + string_format(_ability_score, 0, 2) + "."
                    );
                    var _ability_groups = [
                        "ability_" + string(_ability_source.instance_id)
                            + "_" + string(_ability_index)
                    ];
                    if (_source_abilities[_ability_index].cost_exhaust) {
                        array_push(
                            _ability_groups,
                            "source_" + string(_ability_source.instance_id)
                        );
                    }
                    if (_source_abilities[_ability_index].target_kind != "") {
                        var _ability_preview = ai_find_ability_target({
                            source: _ability_source,
                            ability: _source_abilities[_ability_index],
                            target_kind:
                                _source_abilities[_ability_index].target_kind
                        }, _player);
                        if (_ability_preview.index >= 0) {
                            var _ability_preview_target =
                                get_ability_target_card(
                                    _ability_preview.kind,
                                    _ability_preview.index
                                );
                            if (!is_undefined(_ability_preview_target)) {
                                array_push(
                                    _ability_groups,
                                    "target_" + string(
                                        _ability_preview_target.instance_id
                                    )
                                );
                            }
                        }
                    }
                    array_push(_turn_candidates, {
                        kind: "ability",
                        index: _ability_source_index,
                        secondary: -1,
                        source_kind: _ability_source_kind,
                        ability_index: _ability_index,
                        cost: _source_abilities[_ability_index].cost_cp,
                        cp_gain: _source_abilities[_ability_index].effect_kind
                            == "gain_cp" ? 1 : 0,
                        value: _ability_score,
                        groups: _ability_groups,
                        is_event: false,
                        name: "ACTIVATE " + _ability_source.definition.name
                    });
                    if (_ability_score > _best_score) {
                        _best_score = _ability_score;
                        _best_kind = "ability";
                        _best_source_kind = _ability_source_kind;
                        _best_index = _ability_source_index;
                        _best_ability_index = _ability_index;
                    }
                }
            }
        }

        for (var _hand_index = 0;
             _hand_index < array_length(_player.hand);
             _hand_index++) {
            var _hand_card = _player.hand[_hand_index];
            var _hand_cost = _hand_card.definition.type == "event"
                ? 0
                : max(
                    0,
                    _hand_card.definition.costs.reserve
                        - get_zebes_discount(_player, _hand_card)
                );
            if (_hand_card.definition_id == "loc.sa_x_breaks_out") {
                ai_debug_log(
                    "Hand rejected: " + _hand_card.definition.name
                    + " (not currently legal or deliberately deferred)."
                );
                continue;
            }
            if (!can_play_hand_card(_hand_index)) {
                if (_hand_card.definition.type != "event"
                && _hand_cost > _player.command_points
                && _hand_cost <= _player.command_points + 4) {
                    var _future_hand_value = ai_card_utility(
                        _hand_card, _player
                    );
                    array_push(_turn_candidates, {
                        kind: "play",
                        index: _hand_index,
                        secondary: -1,
                        source_kind: "",
                        ability_index: -1,
                        cost: _hand_cost,
                        value: _future_hand_value,
                        groups: ["card_" + string(_hand_card.instance_id)],
                        is_event: false,
                        earliest_phase: 1,
                        name: "NEXT TURN PLAY "
                            + _hand_card.definition.name
                    });
                    ai_debug_log(
                        "Future hand plan: " + _hand_card.definition.name
                        + "; cost " + string(_hand_cost)
                        + ", state delta "
                        + string_format(_future_hand_value, 0, 2) + " CV."
                    );
                } else {
                    ai_debug_log(
                        "Hand rejected: " + _hand_card.definition.name
                        + " (not currently legal or deliberately deferred)."
                    );
                }
                continue;
            }
            var _hand_score = ai_card_utility(_hand_card, _player)
                - ai_cp_spend_cost(_player, _hand_cost);
            ai_debug_log(
                "Hand candidate: " + _hand_card.definition.name
                + "; cost " + string(_hand_cost)
                + ", board/effect delta "
                + string_format(ai_card_utility(_hand_card, _player), 0, 2)
                + " CV, CP opportunity "
                + string_format(ai_cp_spend_cost(_player, _hand_cost), 0, 2)
                + " CV, net " + string_format(_hand_score, 0, 2) + " CV."
            );
            array_push(_turn_candidates, {
                kind: "play",
                index: _hand_index,
                secondary: -1,
                source_kind: "",
                ability_index: -1,
                cost: _hand_cost,
                value: _hand_score,
                groups: ["card_" + string(_hand_card.instance_id)],
                is_event: _hand_card.definition.type == "event",
                name: "PLAY " + _hand_card.definition.name
            });
            if (_hand_score > _best_score) {
                _best_score = _hand_score;
                _best_kind = "play";
                _best_index = _hand_index;
            }
        }

        var _hand_refresh_plan = ai_plan_hand_refresh(_player);
        if (_hand_refresh_plan.score > -100000) {
            ai_debug_log(
                "Hand refresh candidate: replace "
                + string(array_length(_hand_refresh_plan.indices))
                + " card(s); expected unknown draw utility "
                + string_format(
                    _hand_refresh_plan.expected_draw_value,
                    0,
                    2
                ) + ", projected improvement "
                + string_format(_hand_refresh_plan.improvement, 0, 2)
                + ", score "
                + string_format(_hand_refresh_plan.score, 0, 2) + "."
            );
            var _hand_refresh_groups = ["refresh_hand"];
            for (var _refresh_group_index = 0;
                 _refresh_group_index < array_length(_hand_refresh_plan.indices);
                 _refresh_group_index++) {
                var _refreshed_hand_index =
                    _hand_refresh_plan.indices[_refresh_group_index];
                if (_refreshed_hand_index >= 0
                && _refreshed_hand_index < array_length(_player.hand)) {
                    array_push(
                        _hand_refresh_groups,
                        "card_" + string(
                            _player.hand[_refreshed_hand_index].instance_id
                        )
                    );
                }
            }
            array_push(_turn_candidates, {
                kind: "refresh_hand",
                index: -1,
                secondary: -1,
                source_kind: "",
                ability_index: -1,
                cost: 1,
                value: _hand_refresh_plan.score,
                groups: _hand_refresh_groups,
                is_event: false,
                name: "REFRESH HAND"
            });
            if (_hand_refresh_plan.score > _best_score) {
                _best_score = _hand_refresh_plan.score;
                _best_kind = "refresh_hand";
                _best_refresh_indices = _hand_refresh_plan.indices;
                _best_refresh_ship_search = _hand_refresh_plan.ship_search;
            }
        }

        var _capture_cost = get_capture_cost(_player);
        for (var _ship_index = 0;
             _ship_index < array_length(_player.board.ships);
             _ship_index++) {
            var _ship = _player.board.ships[_ship_index];
            if (!_ship.ready || array_length(_ship.cargo) >= 1) {
                continue;
            }
            var _security = get_card_stat(_ship);
            for (var _source_index = 0; _source_index < 5; _source_index++) {
                var _metroid = _source_index == 4
                    ? (array_length(game_state.cavern) > 0
                        ? game_state.cavern[array_length(game_state.cavern) - 1]
                        : undefined)
                    : game_state.sr388[_source_index];
                if (is_undefined(_metroid)
                || _metroid.definition.hazard > _security
                || _player.command_points < _capture_cost) {
                    continue;
                }
                var _capture_score = ai_capture_delta(
                    _player,
                    _ship,
                    _metroid,
                    _capture_cost
                );
                ai_debug_log(
                    "Capture candidate: Ship "
                    + _ship.definition.name + ", "
                    + _metroid.definition.name + "; cost "
                    + string(_capture_cost) + ", Research "
                    + string(_metroid.definition.research_value)
                    + " CV, cargo survival "
                    + string_format(
                        ai_cargo_survival_probability(_player, _ship), 0, 2
                    ) + ", CP opportunity "
                    + string_format(
                        ai_cp_spend_cost(_player, _capture_cost), 0, 2
                    ) + " CV, net "
                    + string_format(_capture_score, 0, 2) + " CV."
                );
                array_push(_turn_candidates, {
                    kind: "capture",
                    index: _ship_index,
                    secondary: _source_index,
                    source_kind: "",
                    ability_index: -1,
                    cost: _capture_cost,
                    value: _capture_score,
                    groups: [
                        // Capture values are scored against the entire current
                        // possession pipeline. Do not add two independently
                        // scored captures to one projection; execute one and
                        // replan with its cargo now included.
                        "capture_projection",
                        "source_" + string(_ship.instance_id),
                        "metroid_" + string(_metroid.instance_id)
                    ],
                    is_event: false,
                    name: "CAPTURE " + _metroid.definition.name
                });
                if (_capture_score > _best_score) {
                    _best_score = _capture_score;
                    _best_kind = "capture";
                    _best_index = _ship_index;
                    _best_secondary = _source_index;
                }
            }
        }

        for (var _raid_attacker_index = 0;
             _raid_attacker_index < array_length(_player.board.ships);
             _raid_attacker_index++) {
            for (var _raid_defender_index = 0;
                 _raid_defender_index < array_length(
                    game_state.players[
                        1 - game_state.active_player
                    ].board.ships
                 );
                 _raid_defender_index++) {
                var _raid_candidate_score = ai_raid_plan_score(
                    _raid_attacker_index,
                    _raid_defender_index
                );
                if (_raid_candidate_score > -100000) {
                    ai_debug_log(
                        "Raid candidate: "
                        + _player.board.ships[
                            _raid_attacker_index
                        ].definition.name + " into "
                        + game_state.players[
                            1 - game_state.active_player
                        ].board.ships[
                            _raid_defender_index
                        ].definition.name + "; score "
                        + string_format(_raid_candidate_score, 0, 2) + "."
                    );
                    var _raid_attacker = _player.board.ships[
                        _raid_attacker_index
                    ];
                    var _raid_defender = game_state.players[
                        1 - game_state.active_player
                    ].board.ships[_raid_defender_index];
                    array_push(_turn_candidates, {
                        kind: "raid",
                        index: _raid_attacker_index,
                        secondary: _raid_defender_index,
                        source_kind: "",
                        ability_index: -1,
                        cost: get_raid_cost(_player, _raid_defender),
                        value: _raid_candidate_score,
                        groups: [
                            "source_" + string(_raid_attacker.instance_id),
                            "target_" + string(_raid_defender.instance_id)
                        ],
                        is_event: false,
                        name: "RAID " + _raid_defender.definition.name
                    });
                }
                if (_raid_candidate_score > _best_score) {
                    _best_score = _raid_candidate_score;
                    _best_kind = "raid";
                    _best_index = _raid_attacker_index;
                    _best_secondary = _raid_defender_index;
                }
            }
        }

        for (var _shop_index = 0;
             _shop_index < array_length(game_state.shop_row);
             _shop_index++) {
            var _shop_card = game_state.shop_row[_shop_index];
            if (_shop_card.definition_id == "loc.queen_metroid_awakens"
            || _shop_card.definition_id == "loc.sa_x_breaks_out") {
                ai_debug_log(
                    "Shop rejected: " + _shop_card.definition.name
                    + " (special game-state card is deliberately deferred)."
                );
                continue;
            }
            var _card_value = ai_card_utility(_shop_card, _player);
            var _deploy_cost = get_modified_deploy_cost(
                _player,
                _shop_card
            );
            if (_shop_card.definition.type != "event"
            && is_real(_deploy_cost)
            && _player.command_points >= _deploy_cost) {
                var _deploy_score = _card_value
                    - ai_cp_spend_cost(_player, _deploy_cost);
                _best_visible_shop_score = max(
                    _best_visible_shop_score,
                    _deploy_score
                );
                ai_debug_log(
                    "Deploy candidate: " + _shop_card.definition.name
                    + "; cost " + string(_deploy_cost)
                    + ", board/effect delta "
                    + string_format(_card_value, 0, 2)
                    + " CV, CP opportunity "
                    + string_format(
                        ai_cp_spend_cost(_player, _deploy_cost), 0, 2
                    ) + " CV, net "
                    + string_format(_deploy_score, 0, 2) + " CV."
                );
                array_push(_turn_candidates, {
                    kind: "deploy",
                    index: _shop_index,
                    secondary: -1,
                    source_kind: "",
                    ability_index: -1,
                    cost: _deploy_cost,
                    value: _deploy_score,
                    groups: ["shop_" + string(_shop_card.instance_id)],
                    is_event: false,
                    name: "DEPLOY " + _shop_card.definition.name
                });
                if (_deploy_score > _best_score) {
                    _best_score = _deploy_score;
                    _best_kind = "deploy";
                    _best_index = _shop_index;
                }
            } else if (_shop_card.definition.type != "event"
            && is_real(_deploy_cost)
            && _deploy_cost > _player.command_points
            && _deploy_cost <= _player.command_points + 4) {
                array_push(_turn_candidates, {
                    kind: "deploy",
                    index: _shop_index,
                    secondary: -1,
                    source_kind: "",
                    ability_index: -1,
                    cost: _deploy_cost,
                    value: _card_value,
                    groups: ["shop_" + string(_shop_card.instance_id)],
                    is_event: false,
                    earliest_phase: 1,
                    name: "NEXT TURN DEPLOY " + _shop_card.definition.name
                });
            }
            var _reserve_cost = get_modified_reserve_cost(
                _player,
                _shop_card
            );
            if (is_real(_reserve_cost)
            && _player.command_points >= _reserve_cost) {
                var _reserve_score = (_card_value * 0.35)
                    - ai_cp_spend_cost(_player, _reserve_cost);
                _best_visible_shop_score = max(
                    _best_visible_shop_score,
                    _reserve_score
                );
                ai_debug_log(
                    "Reserve candidate: " + _shop_card.definition.name
                    + "; cost " + string(_reserve_cost)
                    + ", discounted future option "
                    + string_format(_card_value * 0.35, 0, 2)
                    + " CV, CP opportunity "
                    + string_format(
                        ai_cp_spend_cost(_player, _reserve_cost), 0, 2
                    ) + " CV, net "
                    + string_format(_reserve_score, 0, 2) + " CV."
                );
                array_push(_turn_candidates, {
                    kind: "reserve",
                    index: _shop_index,
                    secondary: -1,
                    source_kind: "",
                    ability_index: -1,
                    cost: _reserve_cost,
                    value: _reserve_score,
                    groups: ["shop_" + string(_shop_card.instance_id)],
                    is_event: false,
                    name: "RESERVE " + _shop_card.definition.name
                });
                if (_reserve_score > _best_score) {
                    _best_score = _reserve_score;
                    _best_kind = "reserve";
                    _best_index = _shop_index;
                }
            } else if (is_real(_reserve_cost)
            && _reserve_cost > _player.command_points
            && _reserve_cost <= _player.command_points + 4) {
                array_push(_turn_candidates, {
                    kind: "reserve",
                    index: _shop_index,
                    secondary: -1,
                    source_kind: "",
                    ability_index: -1,
                    cost: _reserve_cost,
                    value: _card_value * 0.35,
                    groups: ["shop_" + string(_shop_card.instance_id)],
                    is_event: false,
                    earliest_phase: 1,
                    name: "NEXT TURN RESERVE " + _shop_card.definition.name
                });
            }
        }

        // Salvage only when one discard immediately unlocks a specifically
        // stronger Shop replacement. The chosen purchase is remembered and
        // executed next, preventing salvage from becoming fuel for a hand play.
        var _salvage_zones = [
            ["character", _player.board.characters],
            ["ship", _player.board.ships],
            ["location", _player.board.locations]
        ];
        for (var _salvage_zone_index = 0;
             _salvage_zone_index < array_length(_salvage_zones);
             _salvage_zone_index++) {
            var _salvage_kind = _salvage_zones[_salvage_zone_index][0];
            var _salvage_cards = _salvage_zones[_salvage_zone_index][1];
            for (var _salvage_index = 0;
                 _salvage_index < array_length(_salvage_cards);
                 _salvage_index++) {
                var _salvage_card = _salvage_cards[_salvage_index];
                var _salvage_refund = get_salvage_refund(_salvage_card);
                if (!_salvage_card.ready
                || _salvage_refund <= 0
                || array_length(_salvage_card.cargo) > 0) continue;
                var _salvage_value = ai_card_utility(_salvage_card, _player);
                var _unlocked_score = -100000;
                var _unlocked_goal_id = -1;
                var _unlocked_goal_mode = "";
                for (var _unlock_shop_index = 0;
                     _unlock_shop_index < array_length(game_state.shop_row);
                     _unlock_shop_index++) {
                    var _unlock_card = game_state.shop_row[_unlock_shop_index];
                    var _unlock_deploy = get_modified_deploy_cost(_player, _unlock_card);
                    var _unlock_reserve = get_modified_reserve_cost(_player, _unlock_card);
                    var _unlock_utility = ai_card_utility(
                        _unlock_card,
                        _player
                    );
                    // A small numerical edge is not enough to justify losing a
                    // developed permanent and paying for its replacement.
                    if (_unlock_utility < _salvage_value + 1.5) continue;
                    if (_unlock_card.definition.type != "event"
                    && is_real(_unlock_deploy)
                    && _player.command_points < _unlock_deploy
                    && _player.command_points + _salvage_refund
                        >= _unlock_deploy) {
                        var _unlock_deploy_score = _unlock_utility
                            - ai_cp_spend_cost(_player, _unlock_deploy)
                            - _salvage_value;
                        if (_unlock_deploy_score > _unlocked_score) {
                            _unlocked_score = _unlock_deploy_score;
                            _unlocked_goal_id = _unlock_card.instance_id;
                            _unlocked_goal_mode = "deploy";
                        }
                    }
                    if (is_real(_unlock_reserve)
                    && _player.command_points < _unlock_reserve
                    && _player.command_points + _salvage_refund
                        >= _unlock_reserve) {
                        var _unlock_reserve_score = (_unlock_utility * 0.35)
                            - ai_cp_spend_cost(_player, _unlock_reserve)
                            - _salvage_value;
                        if (_unlock_reserve_score > _unlocked_score) {
                            _unlocked_score = _unlock_reserve_score;
                            _unlocked_goal_id = _unlock_card.instance_id;
                            _unlocked_goal_mode = "reserve";
                        }
                    }
                }
                if (_unlocked_score > _best_score) {
                    _best_score = _unlocked_score;
                    _best_kind = "salvage";
                    _best_source_kind = _salvage_kind;
                    _best_index = _salvage_index;
                    _best_salvage_goal_id = _unlocked_goal_id;
                    _best_salvage_goal_mode = _unlocked_goal_mode;
                }
                if (_unlocked_score > -100000) {
                    array_push(_turn_candidates, {
                        kind: "salvage",
                        index: _salvage_index,
                        secondary: -1,
                        source_kind: _salvage_kind,
                        ability_index: -1,
                        cost: 0,
                        value: _unlocked_score,
                        groups: [
                            "source_" + string(_salvage_card.instance_id),
                            "shop_" + string(_unlocked_goal_id)
                        ],
                        is_event: false,
                        salvage_goal_id: _unlocked_goal_id,
                        salvage_goal_mode: _unlocked_goal_mode,
                        name: "SALVAGE " + _salvage_card.definition.name
                    });
                }
            }
        }

        var _shop_refresh_score = ai_score_shop_refresh(
            _player,
            _best_visible_shop_score
        );
        if (_shop_refresh_score > -100000) {
            ai_debug_log(
                "Shop refresh candidate: visible best "
                + string_format(
                    max(0, _best_visible_shop_score),
                    0,
                    2
                ) + ", hidden-pool composition score "
                + string_format(_shop_refresh_score, 0, 2) + "."
            );
            var _shop_refresh_groups = ["refresh_shop"];
            for (var _refresh_shop_index = 0;
                 _refresh_shop_index < array_length(game_state.shop_row);
                 _refresh_shop_index++) {
                array_push(
                    _shop_refresh_groups,
                    "shop_" + string(
                        game_state.shop_row[_refresh_shop_index].instance_id
                    )
                );
            }
            array_push(_turn_candidates, {
                kind: "refresh_shop",
                index: -1,
                secondary: -1,
                source_kind: "",
                ability_index: -1,
                cost: 1,
                value: _shop_refresh_score,
                groups: _shop_refresh_groups,
                is_event: false,
                name: "REFRESH SHOP"
            });
            if (_shop_refresh_score > _best_score) {
                _best_score = _shop_refresh_score;
                _best_kind = "refresh_shop";
            }
        }

        ai_planner_collecting = false;
        var _turn_plan = ai_plan_turn(
            _turn_candidates, _player.command_points
        );
        if (_turn_plan.first >= 0) {
            var _planned = _turn_candidates[_turn_plan.first];
            _best_kind = _planned.kind;
            _best_index = _planned.index;
            _best_secondary = _planned.secondary;
            _best_source_kind = _planned.source_kind;
            _best_ability_index = _planned.ability_index;
            _best_score = _turn_plan.value;
            if (_best_kind == "refresh_hand") {
                _best_refresh_indices = _hand_refresh_plan.indices;
                _best_refresh_ship_search = _hand_refresh_plan.ship_search;
            }
            if (_best_kind == "salvage") {
                _best_salvage_goal_id = _planned.salvage_goal_id;
                _best_salvage_goal_mode = _planned.salvage_goal_mode;
            }
        } else {
            _best_kind = "end";
            _best_score = _turn_plan.value;
        }
        var _plan_text = "";
        for (var _plan_step = 0;
             _plan_step < array_length(_turn_plan.sequence);
             _plan_step++) {
            if (_plan_text != "") _plan_text += " -> ";
            _plan_text += _turn_candidates[
                _turn_plan.sequence[_plan_step]
            ].name;
        }
        ai_debug_log(
            "Turn plan: " + (_plan_text == "" ? "BANK" : _plan_text)
            + "; projected " + string_format(_turn_plan.value, 0, 2)
            + " CV; executing "
            + (_turn_plan.first >= 0
                ? _turn_candidates[_turn_plan.first].name
                : "BANK") + "."
        );
        ai_eval_cache_active = false;
        switch (_best_kind) {
            case "ability":
                var _chosen_source = get_ability_source(
                    _best_source_kind,
                    _best_index
                );
                ai_debug_log(
                    "Decision: activate " + _chosen_source.definition.name
                    + " ability " + string(_best_ability_index)
                    + " with winning score "
                    + string_format(_best_score, 0, 2) + "."
                );
                ai_last_action = "Activating "
                    + _chosen_source.definition.name;
                return activate_selected_ability(
                    _best_source_kind,
                    _best_index,
                    _best_ability_index
                );
            case "play":
                ai_debug_log(
                    "Decision: play "
                    + _player.hand[_best_index].definition.name
                    + " with winning score "
                    + string_format(_best_score, 0, 2) + "."
                );
                ai_last_action = "Playing "
                    + _player.hand[_best_index].definition.name;
                return play_hand_card(_best_index);
            case "capture":
                ai_debug_log(
                    "Decision: capture with Ship index "
                    + string(_best_index) + " from source "
                    + string(_best_secondary) + " with winning score "
                    + string_format(_best_score, 0, 2) + "."
                );
                ai_last_action = "Capturing a Metroid";
                return capture_metroid_action(_best_index, _best_secondary);
            case "raid":
                ai_debug_log(
                    "Decision: initiate raid with "
                    + _player.board.ships[_best_index].definition.name
                    + " against expected target index "
                    + string(_best_secondary) + " with winning score "
                    + string_format(_best_score, 0, 2) + "."
                );
                ai_last_action = "Initiating a raid";
                return begin_raid_choice(_best_index);
            case "deploy":
                ai_debug_log(
                    "Decision: deploy "
                    + game_state.shop_row[_best_index].definition.name
                    + " with winning score "
                    + string_format(_best_score, 0, 2) + "."
                );
                ai_last_action = "Deploying "
                    + game_state.shop_row[_best_index].definition.name;
                return deploy_shop_card(_best_index);
            case "reserve":
                ai_debug_log(
                    "Decision: reserve "
                    + game_state.shop_row[_best_index].definition.name
                    + " with winning score "
                    + string_format(_best_score, 0, 2) + "."
                );
                ai_last_action = "Reserving "
                    + game_state.shop_row[_best_index].definition.name;
                return reserve_shop_card(_best_index);
            case "refresh_hand":
                ai_debug_log(
                    "Decision: refresh "
                    + string(array_length(_best_refresh_indices))
                    + " weak hand card(s) with winning score "
                    + string_format(_best_score, 0, 2) + "."
                );
                ai_last_action = "Refreshing hand";
                if (_best_refresh_ship_search) {
                    _player.ai_ship_search_turn = game_state.turn_number;
                }
                var _hand_refresh_result = refresh_hand_cards(
                    _best_refresh_indices
                );
                if (_hand_refresh_result) {
                    _player.ai_hand_refresh_turn = game_state.turn_number;
                }
                return _hand_refresh_result;
            case "refresh_shop":
                ai_debug_log(
                    "Decision: refresh the Shop with winning score "
                    + string_format(_best_score, 0, 2) + "."
                );
                ai_last_action = "Refreshing Shop";
                var _shop_refresh_result = refresh_shop_action();
                if (_shop_refresh_result) {
                    _player.ai_shop_refresh_turn = game_state.turn_number;
                }
                return _shop_refresh_result;
            case "salvage":
                ai_last_action = "Salvaging "
                    + get_ability_source(
                        _best_source_kind,
                        _best_index
                    ).definition.name;
                if (salvage_permanent(_best_source_kind, _best_index)) {
                    ai_salvage_goal_instance_id = _best_salvage_goal_id;
                    ai_salvage_goal_mode = _best_salvage_goal_mode;
                    return true;
                }
                ai_salvage_goal_instance_id = -1;
                ai_salvage_goal_mode = "";
                return false;
        }
        ai_debug_log(
            "Decision: bank " + string(_player.command_points)
            + " CP with winning score "
            + string_format(_bank_plan.score, 0, 2) + "."
        );
        ai_last_action = "Ending turn";
        return end_turn_action();
    };

    run_ai_controller_step = function() {
        if ((game_state.game_mode != "ai"
            && game_state.game_mode != "ai_watch"
            && game_state.game_mode != "batch")
        || !game_state.players[game_state.priority_player].is_ai
        || game_state.phase == "game_over"
        || (game_state.game_mode != "batch"
            && current_time < ai_next_step_time)) {
            return false;
        }
        ai_next_step_time = current_time + ai_action_delay;
        if (!is_undefined(pending_choice)) {
            // Resolution may replace/clear pending_choice or end the game. Keep
            // diagnostics on a stable value instead of dereferencing the mutable
            // global after the resolver returns.
            var _pending_kind = pending_choice.kind;
            ai_last_action = "Resolving " + _pending_kind;
            var _pending_resolved = ai_resolve_pending_choice();
            if (!_pending_resolved
            && !is_undefined(pending_choice)
            && game_state.phase != "game_over") {
                ai_debug_log(
                    "Unsupported or unresolved mandatory choice: "
                    + _pending_kind + "."
                );
                array_push(
                    game_state.event_log,
                    "AI paused on unsupported choice: "
                    + _pending_kind + "."
                );
            }
            return true;
        }
        switch (game_state.phase) {
            case "containment":
                ai_last_action = "Resolving containment";
                resolve_turn_containment(
                    ai_choose_containment_ship(
                        game_state.players[game_state.active_player]
                    )
                );
                return true;
            case "action":
                var _action_resolved = ai_select_action();
                if (!_action_resolved) {
                    var _failed_action = ai_last_action;
                    show_debug_message(
                        "[AI RECOVERY] Seed " + string(game_state.seed)
                        + ", turn " + string(game_state.turn_number)
                        + ", player " + string(game_state.active_player + 1)
                        + ": " + _failed_action + " returned false."
                    );
                    ai_debug_log(
                        "Action resolver returned false after selecting: "
                        + _failed_action + ". Ending the turn to prevent an AI loop."
                    );
                    array_push(
                        game_state.event_log,
                        "AI recovery: " + _failed_action
                        + " could not resolve, so the turn ended."
                    );
                    ai_last_action = "Recovery after failed action: "
                        + _failed_action;
                    if (!is_undefined(pending_choice)) {
                        ai_debug_log(
                            "Recovery could not end the turn because pending choice "
                            + pending_choice.kind + " was created."
                        );
                        return true;
                    }
                    return end_turn_action();
                }
                return true;
            case "gain_cp":
            case "ready":
            case "mutation":
            case "pass_turn":
                ai_debug_log("Advancing automatic phase.");
                advance_game_phase();
                return true;
        }
        return false;
    };

    advance_game_phase = function() {
        switch (game_state.phase) {
            case "containment":
                resolve_containment_phase();
                break;

            case "gain_cp":
                resolve_gain_cp_phase();
                break;

            case "ready":
                resolve_ready_phase();
                break;

            case "mutation":
                resolve_mutation_phase();
                break;

            case "pass_turn":
                game_state.active_player = 1 - game_state.active_player;
                game_state.priority_player = game_state.active_player;
                game_state.view_player = game_state.game_mode == "hotseat"
                    ? game_state.active_player
                    : (game_state.game_mode == "ai_watch"
                        ? game_state.view_player
                        : (game_state.game_mode == "network"
                        ? (network_local_player >= 0
                            ? network_local_player
                            : game_state.view_player)
                        : 0));
                game_state.turn_number += 1;
                game_state.phase = "containment";
                check_alternate_end_conditions();
                game_state.players[game_state.active_player].event_played_this_turn = false;
                selected_shop_index = 0;
                selected_hand_index = 0;
                selected_ship_index = 0;
                selected_metroid_source = 0;
                selection_focus = 0;
                ui_selected_kind = "";
                ui_selected_index = -1;
                pending_choice = undefined;
                handoff_active = game_state.game_mode == "hotseat";
                array_push(
                    game_state.event_log,
                    "Turn " + string(game_state.turn_number) + " began for "
                    + game_state.players[game_state.active_player].name + "."
                );
                if (!handoff_active) {
                    resolve_start_turn_researchers(
                        game_state.players[game_state.active_player]
                    );
                    skip_empty_lab_containment();
                }
                break;
        }
    };

}

