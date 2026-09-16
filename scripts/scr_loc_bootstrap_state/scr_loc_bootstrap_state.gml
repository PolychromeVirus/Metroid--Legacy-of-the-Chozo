function loc_bootstrap_state() {
    game_seed = variable_global_exists("loc_test_seed")
        ? global.loc_test_seed
        : 388;
    random_set_seed(game_seed);

    // Presentation queues must exist before opening hands call draw_from_deck().
    presentation_card_transits = [];
    presentation_card_destructions = [];
    presentation_breaches = [];
    presentation_last_breach_instance_id = -1;
    presentation_shuffle_until_ms = [0, 0];
    presentation_evolution_until_ms = 0;
    presentation_capture_until_ms = 0;
    cavern_sensor_alpha = 0;
    presentation_lab_intake_until_ms = 0;
    presentation_lab_intake_close_at_ms = 0;
    presentation_lab_intake_player = -1;
    presentation_target_effect = undefined;
    presentation_target_effect_committing = false;
    event_log_scroll = 0;
    chat_input_active = false;
    chat_input_text = "";

    queue_breach_presentation = function(_card, _player_index) {
        presentation_last_breach_instance_id = -1;
        if (is_undefined(_card) || game_state.game_mode == "batch") {
            return -1;
        }
        presentation_last_breach_instance_id = _card.instance_id;
        array_push(presentation_breaches, {
            card: _card,
            player_index: _player_index,
            instance_id: _card.instance_id,
            started_at_ms: current_time,
            emerge_duration_ms: 520,
            return_started_at_ms: -1,
            return_duration_ms: 680
        });
        return _card.instance_id;
    };

    release_breach_presentation = function(_instance_id) {
        if (_instance_id < 0) return false;
        for (var _breach_release_index = 0;
             _breach_release_index < array_length(presentation_breaches);
             _breach_release_index++) {
            var _breach_release = presentation_breaches[_breach_release_index];
            if (_breach_release.instance_id == _instance_id
            && _breach_release.return_started_at_ms < 0) {
                _breach_release.return_started_at_ms = max(
                    current_time,
                    _breach_release.started_at_ms
                        + _breach_release.emerge_duration_ms
                );
                return true;
            }
        }
        return false;
    };

    queue_card_destruction = function(_card, _source_kind) {
        if (is_undefined(_card) || game_state.game_mode == "batch") {
            return false;
        }
        var _kind = is_undefined(_source_kind) ? "character" : _source_kind;
        var _width = 116;
        var _height = 162;
        var _rotate_ship = false;
        if (_kind == "ship") {
            _width = 184;
            _height = 132;
            _rotate_ship = true;
        } else if ((_kind == "location" || _kind == "relic")) {
            _width = 104;
            _height = 146;
        } else if (_kind == "hand") {
            _width = 145;
            _height = 203;
            _rotate_ship = _card.definition.type == "ship";
        }
        array_push(presentation_card_destructions, {
            card: _card,
            x: _card.ui_x,
            y: _card.ui_y,
            width: _width,
            height: _height,
            rotate_ship: _rotate_ship,
            started_at_ms: current_time,
            duration_ms: 900
        });
        return true;
    };

    game_state = {
        seed: game_seed,
        started_at_ms: current_time,
        turn_number: 1,
        active_player: 0,
        priority_player: 0,
        view_player: 0,
        game_mode: "",
        phase: "setup_complete",
        mutation: 0,
        mutation_limit: 8,
        final_round_active: false,
        final_round_end_player: -1,
        final_round_reason: "",
        players: [
            make_player_state(0),
            make_player_state(1)
        ],
        shop_deck: [],
        shop_row: [],
        shop_discard: [],
        sr388: [],
        cavern: [],
        removed_cards: [],
        event_log: [],
        match_summary: "",
        balance_log_path: ""
    };

    for (var _player_index = 0; _player_index < 2; _player_index++) {
        var _player = game_state.players[_player_index];
        _player.deck = expand_card_pool(
            card_database.pools.starter,
            _player_index,
            "deck"
        );
        shuffle_array(_player.deck);
        draw_from_deck(_player, 5);
        array_push(
            game_state.event_log,
            _player.name + " drew an opening hand of 5 cards."
        );
    }

    game_state.shop_deck = expand_card_pool(
        card_database.pools.loc,
        -1,
        "shop_deck"
    );
    var _lop_shop_cards = expand_card_pool(
        card_database.pools.lop,
        -1,
        "shop_deck"
    );
    for (var _lop_index = 0;
         _lop_index < array_length(_lop_shop_cards);
         _lop_index++) {
        array_push(game_state.shop_deck, _lop_shop_cards[_lop_index]);
    }
    var _expected_opening_shop_deck_count = max(
        0,
        array_length(game_state.shop_deck) - 5
    );
    shuffle_array(game_state.shop_deck);
    setup_errors = [];
    fill_opening_shop();

    var _larva_definition = get_metroid_definition("metroid.larva");
    if (!is_undefined(_larva_definition)) {
        for (var _slot = 0; _slot < 4; _slot++) {
            array_push(
                game_state.sr388,
                make_metroid_instance(_larva_definition, "sr388_" + string(_slot))
            );
        }
    }

    // Keep the opening player deterministic while the rules engine is under test.
    game_state.active_player = 0;
    game_state.priority_player = game_state.active_player;
    array_push(
        game_state.event_log,
        game_state.players[game_state.active_player].name + " takes the first turn."
    );
        array_push(
            game_state.event_log,
            "Setup complete with seed " + string(game_seed) + "."
        );

    if (array_length(game_state.players[0].hand) != 5
    || array_length(game_state.players[1].hand) != 5) {
        array_push(setup_errors, "Both opening hands must contain 5 cards.");
    }
    if (array_length(game_state.players[0].deck) != 5
    || array_length(game_state.players[1].deck) != 5) {
        array_push(setup_errors, "Both starter decks must have 5 cards after drawing.");
    }
    if (array_length(game_state.shop_row) != 5) {
        array_push(setup_errors, "The Shop row must contain 5 cards.");
    }
    if (array_length(game_state.shop_deck)
    != _expected_opening_shop_deck_count) {
        array_push(
            setup_errors,
            "The Shop deck must contain "
                + string(_expected_opening_shop_deck_count)
                + " cards after its opening row; found "
                + string(array_length(game_state.shop_deck)) + "."
        );
    }
    if (array_length(game_state.sr388) != 4) {
        array_push(setup_errors, "SR388 must contain 4 Metroid Larvae.");
    }
    if (game_state.mutation != 0 || game_state.mutation_limit != 8) {
        array_push(setup_errors, "The Mutation Track must begin at 0/8.");
    }

}

