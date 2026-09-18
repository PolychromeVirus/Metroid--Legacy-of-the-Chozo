function loc_bootstrap_data() {
    load_errors = [];
    sprite_cache = {};

    card_database = {
        schema_version: 1,
        cards_by_id: {},
        metroids_by_id: {},
        pools: {
            loc: [],
            lop: [],
            starter: [],
            metroids: []
        },
        totals: {
            definitions: 0,
            copies: 0
        }
    };

    resolve_included_path = function(_relative_path) {
        var _candidates = [
            working_directory + _relative_path,
            _relative_path
        ];

        for (var _i = 0; _i < array_length(_candidates); _i++) {
            if (file_exists(_candidates[_i])) {
                return _candidates[_i];
            }
        }

        return "";
    };

    load_json_file = function(_relative_path) {
        var _path = resolve_included_path(_relative_path);
        if (_path == "") {
            array_push(load_errors, "Missing included file: " + _relative_path);
            return undefined;
        }

        var _file = file_text_open_read(_path);
        if (_file < 0) {
            array_push(load_errors, "Could not open: " + _relative_path);
            return undefined;
        }

        var _text = "";
        while (!file_text_eof(_file)) {
            _text += file_text_read_string(_file);
            file_text_readln(_file);
            if (!file_text_eof(_file)) {
                _text += "\n";
            }
        }
        file_text_close(_file);

        try {
            return json_parse(_text);
        } catch (_exception) {
            array_push(
                load_errors,
                "Invalid JSON in " + _relative_path + ": " + string(_exception)
            );
            return undefined;
        }
    };

    register_card_pool = function(_relative_path, _expected_pool) {
        var _data = load_json_file(_relative_path);
        if (is_undefined(_data)) {
            return;
        }

        if (!variable_struct_exists(_data, "schema_version")
        || _data.schema_version != card_database.schema_version) {
            array_push(load_errors, "Unsupported schema in " + _relative_path);
            return;
        }

        if (!variable_struct_exists(_data, "pool") || _data.pool != _expected_pool) {
            array_push(
                load_errors,
                "Pool mismatch in " + _relative_path + "; expected " + _expected_pool
            );
            return;
        }

        if (!variable_struct_exists(_data, "cards") || !is_array(_data.cards)) {
            array_push(load_errors, "Missing cards array in " + _relative_path);
            return;
        }

        for (var _i = 0; _i < array_length(_data.cards); _i++) {
            var _card = _data.cards[_i];
            if (!is_struct(_card)
            || !variable_struct_exists(_card, "definition_id")
            || !variable_struct_exists(_card, "image")) {
                array_push(
                    load_errors,
                    "Malformed card record " + string(_i) + " in " + _relative_path
                );
                continue;
            }

            if (variable_struct_exists(
                card_database.cards_by_id,
                _card.definition_id
            )) {
                array_push(load_errors, "Duplicate card id: " + _card.definition_id);
                continue;
            }

            variable_struct_set(
                card_database.cards_by_id,
                _card.definition_id,
                _card
            );
            var _pool_cards = variable_struct_get(
                card_database.pools,
                _expected_pool
            );
            array_push(_pool_cards, _card);
            variable_struct_set(card_database.pools, _expected_pool, _pool_cards);
            card_database.totals.definitions += 1;
            card_database.totals.copies += _card.count;
        }
    };

    register_metroids = function(_relative_path) {
        var _data = load_json_file(_relative_path);
        if (is_undefined(_data)) {
            return;
        }

        if (!variable_struct_exists(_data, "schema_version")
        || _data.schema_version != card_database.schema_version) {
            array_push(load_errors, "Unsupported schema in " + _relative_path);
            return;
        }

        if (!variable_struct_exists(_data, "metroids") || !is_array(_data.metroids)) {
            array_push(load_errors, "Missing metroids array in " + _relative_path);
            return;
        }

        for (var _i = 0; _i < array_length(_data.metroids); _i++) {
            var _metroid = _data.metroids[_i];
            if (!is_struct(_metroid)
            || !variable_struct_exists(_metroid, "definition_id")
            || !variable_struct_exists(_metroid, "stage_key")) {
                array_push(
                    load_errors,
                    "Malformed Metroid record " + string(_i) + " in " + _relative_path
                );
                continue;
            }

            if (variable_struct_exists(
                card_database.metroids_by_id,
                _metroid.definition_id
            )) {
                array_push(load_errors, "Duplicate Metroid id: " + _metroid.definition_id);
                continue;
            }

            variable_struct_set(
                card_database.metroids_by_id,
                _metroid.definition_id,
                _metroid
            );
            array_push(card_database.pools.metroids, _metroid);
            card_database.totals.definitions += 1;
            card_database.totals.copies += _metroid.count;
        }
    };

    get_card_definition = function(_id) {
        if (!variable_struct_exists(card_database.cards_by_id, _id)) {
            array_push(load_errors, "Unknown card id: " + _id);
            return undefined;
        }
        return variable_struct_get(card_database.cards_by_id, _id);
    };

    get_metroid_definition = function(_id) {
        if (!variable_struct_exists(card_database.metroids_by_id, _id)) {
            array_push(load_errors, "Unknown Metroid id: " + _id);
            return undefined;
        }
        return variable_struct_get(card_database.metroids_by_id, _id);
    };

    get_definition_image_path = function(_definition, _is_metroid) {
        if (_is_metroid) {
            return "cards/CARD_METROID" + string(_definition.stage_key) + ".png";
        }
        return "cards/CARD_" + string(_definition.image) + ".png";
    };

    get_definition_sprite = function(_definition, _is_metroid) {
        var _cache_key = _definition.definition_id;
        if (variable_struct_exists(sprite_cache, _cache_key)) {
            return variable_struct_get(sprite_cache, _cache_key);
        }

        var _relative_path = get_definition_image_path(_definition, _is_metroid);
        var _path = resolve_included_path(_relative_path);
        if (_path == "") {
            array_push(
                load_errors,
                "Missing image for " + _definition.definition_id + ": " + _relative_path
            );
            variable_struct_set(sprite_cache, _cache_key, -1);
            return -1;
        }

        var _sprite = sprite_add(_path, 1, false, false, 0, 0);
        if (_sprite < 0) {
            array_push(load_errors, "Could not load image: " + _relative_path);
        }
        variable_struct_set(sprite_cache, _cache_key, _sprite);
        return _sprite;
    };

    get_card_back_sprite = function() {
        var _cache_key = "__card_back";
        if (variable_struct_exists(sprite_cache, _cache_key)) {
            return variable_struct_get(sprite_cache, _cache_key);
        }
        var _relative_path = "cards/CardBack.png";
        var _path = resolve_included_path(_relative_path);
        if (_path == "") {
            array_push(load_errors, "Missing Shop deck card back: " + _relative_path);
            variable_struct_set(sprite_cache, _cache_key, -1);
            return -1;
        }
        var _sprite = sprite_add(_path, 1, false, false, 0, 0);
        if (_sprite < 0) {
            array_push(load_errors, "Could not load image: " + _relative_path);
        }
        variable_struct_set(sprite_cache, _cache_key, _sprite);
        return _sprite;
    };

    register_card_pool("generated/cards_loc.json", "loc");
    register_card_pool("generated/cards_lop.json", "lop");
    register_card_pool("generated/cards_starter.json", "starter");
    register_metroids("generated/metroids.json");

    next_card_instance_id = 1;
    next_metroid_instance_id = 1;

    shuffle_array = function(_array) {
        for (var _i = array_length(_array) - 1; _i > 0; _i--) {
            var _swap_index = irandom(_i);
            var _held = _array[_i];
            _array[_i] = _array[_swap_index];
            _array[_swap_index] = _held;
        }
    };

    make_card_instance = function(_definition, _owner, _zone) {
        var _instance = {
            instance_id: next_card_instance_id,
            definition_id: _definition.definition_id,
            definition: _definition,
            printed_definition_id: _definition.definition_id,
            printed_definition: _definition,
            copy_until_end_turn: false,
            granted_factions: [],
            granted_faction: "",
            owner: _owner,
            controller: _owner,
            zone: _zone,
            ready: true,
            temporary_stat_bonus: 0,
            ai_readied_by_effect_this_turn: false,
            skip_ready_after_lab_intake: false,
            phazon_tokens: 0,
            attachments: [],
            cargo: [],
            ui_position_initialized: false,
            ui_x: 0,
            ui_y: 0,
            ui_zone: "",
            ui_move_after_ms: 0,
            ui_hold_until_ms: 0,
            ui_hide_until_ms: 0,
            ui_face_down_until_move: false,
            ui_force_deck_origin: false,
            ui_force_shop_origin: false,
            ui_shop_slot: -1,
            ui_angle_initialized: false,
            ui_angle: 0,
            ui_tilt: 0,
            ui_commit_lift: 0,
            ui_last_phazon_tokens: 0,
            ui_phazon_flash_started_ms: -1
        };
        next_card_instance_id += 1;
        return _instance;
    };

    clear_card_board_state = function(_card) {
        while (array_length(_card.attachments) > 0) {
            var _leaving_attachment = _card.attachments[0];
            array_delete(_card.attachments, 0, 1);
            clear_card_board_state(_leaving_attachment);
            _leaving_attachment.zone = "discard";
            array_push(
                game_state.players[_leaving_attachment.owner].discard,
                _leaving_attachment
            );
            array_push(
                game_state.event_log,
                _leaving_attachment.definition.name
                    + " was discarded because its host left play."
            );
        }
        _card.ready = true;
        _card.temporary_stat_bonus = 0;
        _card.ai_readied_by_effect_this_turn = false;
        _card.phazon_tokens = 0;
        _card.definition_id = _card.printed_definition_id;
        _card.definition = _card.printed_definition;
        _card.copy_until_end_turn = false;
        _card.granted_factions = [];
        _card.granted_faction = "";
        if (variable_struct_exists(_card, "used_for_containment_this_turn")) {
            _card.used_for_containment_this_turn = false;
        }
        _card.skip_ready_after_lab_intake = false;
        if (variable_struct_exists(_card, "host_instance_id")) {
            _card.host_instance_id = -1;
        }
    };

    make_metroid_instance = function(_definition, _zone) {
        var _instance = {
            instance_id: next_metroid_instance_id,
            definition_id: _definition.definition_id,
            definition: _definition,
            zone: _zone,
            ui_position_initialized: false,
            ui_x: 0,
            ui_y: 0,
            ui_zone: "",
            ui_move_after_ms: 0,
            ui_hold_until_ms: 0,
            ui_cargo_arrival_ms: 0,
            evolution_old_definition: undefined,
            evolution_started_ms: -1,
            evolution_duration_ms: 1400
        };
        next_metroid_instance_id += 1;
        return _instance;
    };

    make_player_state = function(_player_index) {
        return {
            index: _player_index,
            name: "Player " + string(_player_index + 1),
            is_ai: false,
            favored_faction: "",
            leader_identity_id: "",
            identity_starter_id: "",
            identity_starter_replaced_id: "",
            command_points: 0,
            telemetry: {
                max_cp: 0,
                captures: 0,
                raids_started: 0,
                raids_won: 0,
                raids_lost: 0,
                raid_ties: 0,
                breaches: 0,
                card_take_ids: [],
                card_take_counts: []
            },
            event_played_this_turn: false,
            next_reserve_discount: 0,
            next_capture_discount: 0,
            prevent_next_effect_exhaust: false,
            prevent_next_breach: false,
            next_bounty_hunter_refund: false,
            next_gf_ability_double: false,
            deck: [],
            hand: [],
            discard: [],
            board: {
                characters: [],
                ships: [],
                locations: [],
                relics: []
            },
            lab: []
        };
    };

    telemetry_update_max_cp = function(_player) {
        _player.telemetry.max_cp = max(
            _player.telemetry.max_cp,
            _player.command_points
        );
    };

    telemetry_record_card_taken = function(_player, _card) {
        var _definition_id = _card.definition_id;
        for (var _take_index = 0;
             _take_index < array_length(_player.telemetry.card_take_ids);
             _take_index++) {
            if (_player.telemetry.card_take_ids[_take_index] == _definition_id) {
                _player.telemetry.card_take_counts[_take_index] += 1;
                return;
            }
        }
        array_push(_player.telemetry.card_take_ids, _definition_id);
        array_push(_player.telemetry.card_take_counts, 1);
    };

    expand_card_pool = function(_definitions, _owner, _zone) {
        var _instances = [];
        for (var _definition_index = 0;
             _definition_index < array_length(_definitions);
             _definition_index++) {
            var _definition = _definitions[_definition_index];
            for (var _copy = 0; _copy < _definition.count; _copy++) {
                array_push(
                    _instances,
                    make_card_instance(_definition, _owner, _zone)
                );
            }
        }
        return _instances;
    };

    draw_from_deck = function(_player, _count) {
        for (var _draw = 0; _draw < _count; _draw++) {
            if (array_length(_player.deck) <= 0) {
                if (array_length(_player.discard) <= 0) {
                    array_push(
                        game_state.event_log,
                        _player.name + " could not draw a card."
                    );
                    return;
                }

                if (game_state.game_mode != "batch") {
                    for (var _shuffle_visual_index = 0;
                         _shuffle_visual_index < array_length(_player.discard);
                         _shuffle_visual_index++) {
                        array_push(presentation_card_transits, {
                            card: _player.discard[_shuffle_visual_index],
                            player_index: _player.index,
                            kind: "discard_to_deck",
                            start_x: 0,
                            start_y: 0,
                            started_at_ms: current_time
                                + (_shuffle_visual_index * 18),
                            duration_ms: 320
                        });
                    }
                    presentation_shuffle_until_ms[_player.index] =
                        current_time + 320
                        + (max(0, array_length(_player.discard) - 1) * 18);
                }
                _player.deck = _player.discard;
                _player.discard = [];
                shuffle_array(_player.deck);
                array_push(
                    game_state.event_log,
                    _player.name + " shuffled their discard into their deck."
                );
            }

            var _card = array_pop(_player.deck);
            clear_card_board_state(_card);
            _card.zone = "hand";
            _card.ui_force_deck_origin = true;
            _card.ui_hold_until_ms = max(
                _card.ui_hold_until_ms,
                presentation_shuffle_until_ms[_player.index]
            );
            array_push(_player.hand, _card);
        }
    };

    restore_hand_to_five = function(_player) {
        var _missing = max(0, 5 - array_length(_player.hand));
        var _available = array_length(_player.deck)
            + array_length(_player.discard);
        var _draw_count = min(_missing, _available);
        if (_draw_count <= 0) {
            return 0;
        }
        var _before = array_length(_player.hand);
        draw_from_deck(_player, _draw_count);
        var _drawn = array_length(_player.hand) - _before;
        if (_drawn > 0) {
            array_push(
                game_state.event_log,
                _player.name + " drew " + string(_drawn)
                    + " card(s) to restore their hand to five."
            );
        }
        return _drawn;
    };

    refill_shop = function() {
        var _revealed_queen_index = -1;
        while (array_length(game_state.shop_row) < 5) {
            if (array_length(game_state.shop_deck) <= 0) {
                if (array_length(game_state.shop_discard) <= 0) {
                    array_push(
                        game_state.event_log,
                        "The Shop could not refill an empty slot."
                    );
                    return;
                }

                game_state.shop_deck = game_state.shop_discard;
                game_state.shop_discard = [];
                shuffle_array(game_state.shop_deck);
                array_push(
                    game_state.event_log,
                    "The Shop discard was shuffled into the Shop deck."
                );
            }

            var _card = array_pop(game_state.shop_deck);
            _card.zone = "shop";
            var _shop_slot_used = [false, false, false, false, false];
            for (var _shop_slot_card_index = 0;
                 _shop_slot_card_index < array_length(game_state.shop_row);
                 _shop_slot_card_index++) {
                var _occupied_shop_slot = game_state.shop_row[
                    _shop_slot_card_index
                ].ui_shop_slot;
                if (_occupied_shop_slot >= 0 && _occupied_shop_slot < 5) {
                    _shop_slot_used[_occupied_shop_slot] = true;
                }
            }
            _card.ui_shop_slot = 0;
            for (var _available_shop_slot = 0;
                 _available_shop_slot < 5;
                 _available_shop_slot++) {
                if (!_shop_slot_used[_available_shop_slot]) {
                    _card.ui_shop_slot = _available_shop_slot;
                    break;
                }
            }
            array_push(game_state.shop_row, _card);

            if (_card.definition_id == "loc.queen_metroid_awakens") {
                // Queen occupies her slot normally, but her state event waits
                // until every other open Shop slot has also been replaced.
                _revealed_queen_index = array_length(game_state.shop_row) - 1;
            }
        }
        if (_revealed_queen_index >= 0) {
            begin_queen_shop_event(_revealed_queen_index);
        }
    };

    fill_opening_shop = function() {
        var _queen_was_drawn = false;
        var _opening_draw_attempts = 0;
        var _opening_draw_limit = max(
            1,
            array_length(game_state.shop_deck) + 1
        );

        while (array_length(game_state.shop_row) < 5) {
            _opening_draw_attempts += 1;
            if (_opening_draw_attempts > _opening_draw_limit) {
                array_push(
                    setup_errors,
                    "The Shop could not fill five opening slots without revealing Queen Metroid Awakens."
                );
                return;
            }
            if (array_length(game_state.shop_deck) <= 0) {
                array_push(
                    setup_errors,
                    "The Shop deck emptied during opening setup."
                );
                return;
            }

            var _card = array_pop(game_state.shop_deck);
            if (_card.definition_id == "loc.queen_metroid_awakens") {
                _card.zone = "shop_deck";
                array_insert(game_state.shop_deck, 0, _card);
                _queen_was_drawn = true;
                continue;
            }

            _card.zone = "shop";
            _card.ui_shop_slot = array_length(game_state.shop_row);
            array_push(game_state.shop_row, _card);
        }

        if (_queen_was_drawn) {
            shuffle_array(game_state.shop_deck);
            array_push(
                game_state.event_log,
                "Queen Metroid was deferred during opening Shop setup."
            );
        }
    };

}

