/// @description Load the generated card database and prepare a visual smoke test.

// Shared identity palette. Keep faction-facing UI colors centralized here so
// nameplates, reports, and future faction presentation stay synchronized.
#macro LOC_COLOR_NEUTRAL make_color_rgb(166, 174, 184)
#macro LOC_COLOR_GF make_color_rgb(84, 229, 242)
#macro LOC_COLOR_SP make_color_rgb(255, 99, 110)
#macro LOC_COLOR_CZ make_color_rgb(255, 220, 70)
#macro LOC_COLOR_BH make_color_rgb(38, 255, 24)
#macro LOC_COLOR_PZ make_color_rgb(70, 104, 210)

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
        || !variable_struct_exists(_card, "id")
        || !variable_struct_exists(_card, "image")) {
            array_push(
                load_errors,
                "Malformed card record " + string(_i) + " in " + _relative_path
            );
            continue;
        }

        if (variable_struct_exists(card_database.cards_by_id, _card.id)) {
            array_push(load_errors, "Duplicate card id: " + _card.id);
            continue;
        }

        variable_struct_set(card_database.cards_by_id, _card.id, _card);
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
        || !variable_struct_exists(_metroid, "id")
        || !variable_struct_exists(_metroid, "stage_key")) {
            array_push(
                load_errors,
                "Malformed Metroid record " + string(_i) + " in " + _relative_path
            );
            continue;
        }

        if (variable_struct_exists(card_database.metroids_by_id, _metroid.id)) {
            array_push(load_errors, "Duplicate Metroid id: " + _metroid.id);
            continue;
        }

        variable_struct_set(
            card_database.metroids_by_id,
            _metroid.id,
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
    var _cache_key = _definition.id;
    if (variable_struct_exists(sprite_cache, _cache_key)) {
        return variable_struct_get(sprite_cache, _cache_key);
    }

    var _relative_path = get_definition_image_path(_definition, _is_metroid);
    var _path = resolve_included_path(_relative_path);
    if (_path == "") {
        array_push(
            load_errors,
            "Missing image for " + _definition.id + ": " + _relative_path
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
        definition_id: _definition.id,
        definition: _definition,
        printed_definition_id: _definition.id,
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
    if (variable_struct_exists(_card, "host_instance_id")) {
        _card.host_instance_id = -1;
    }
};

make_metroid_instance = function(_definition, _zone) {
    var _instance = {
        instance_id: next_metroid_instance_id,
        definition_id: _definition.id,
        definition: _definition,
        zone: _zone,
        ui_position_initialized: false,
        ui_x: 0,
        ui_y: 0,
        ui_zone: "",
        ui_move_after_ms: 0,
        ui_hold_until_ms: 0,
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
        identity_starter_id: "",
        identity_starter_replaced_id: "",
        command_points: 0,
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
            locations: []
        },
        lab: []
    };
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

refill_shop = function() {
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
            begin_queen_shop_event(array_length(game_state.shop_row) - 1);
            return;
        }
    }
};

fill_opening_shop = function() {
    var _queen_was_drawn = false;

    while (array_length(game_state.shop_row) < 5) {
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

game_seed = variable_global_exists("loc_test_seed")
    ? global.loc_test_seed
    : 388;
random_set_seed(game_seed);

// Presentation queues must exist before opening hands call draw_from_deck().
presentation_card_transits = [];
presentation_card_destructions = [];
presentation_shuffle_until_ms = [0, 0];
presentation_evolution_until_ms = 0;
cavern_sensor_alpha = 0;
presentation_lab_intake_until_ms = 0;
presentation_lab_intake_close_at_ms = 0;
presentation_lab_intake_player = -1;
presentation_target_effect = undefined;
presentation_target_effect_committing = false;

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
    } else if (_kind == "location") {
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
if (array_length(game_state.shop_deck) != 122) {
    array_push(
        setup_errors,
        "The Shop deck must contain 122 cards after its opening row."
    );
}
if (array_length(game_state.sr388) != 4) {
    array_push(setup_errors, "SR388 must contain 4 Metroid Larvae.");
}
if (game_state.mutation != 0 || game_state.mutation_limit != 8) {
    array_push(setup_errors, "The Mutation Track must begin at 0/8.");
}

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
        || _card.definition_id == "loc.zebesian_pirate";
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
    if (_card.definition_id == "loc.chozo_transport"
    && _context == "raid_defender_ship") {
        _conditional_bonus += 1;
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

get_lab_hazard = function(_player) {
    var _hazard = 0;
    for (var _i = 0; _i < array_length(_player.lab); _i++) {
        _hazard += _player.lab[_i].definition.hazard;
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

resolve_metroid_breach = function(_player, _lab_index, _defer_character) {
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
    array_push(
        game_state.event_log,
        _player.name + "'s " + _metroid.definition.name + " breached."
    );

    if (_metroid.definition.id == "metroid.hunter") {
        for (var _i = 0;
             _i < array_length(_player.board.characters);
             _i++) {
            _player.board.characters[_i].phazon_tokens += 1;
        }
        array_push(
            game_state.event_log,
            "Hunter breach gave each of " + _player.name
            + "'s Characters a Phazon token."
        );
    }

    if (is_undefined(_defer_character) || !_defer_character) {
        discard_character_for_player(_player, "a breach");
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
        if (_ship.phazon_tokens >= 3) {
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
        && resolve_metroid_breach(_player, _forced_index)) {
            _breach_count += 1;
        }
    }

    if (_ship_index < 0) {
        // Every Omega is a distinct simultaneous breach instance.
        for (var _omega_index = array_length(_player.lab) - 1;
             _omega_index >= 0;
             _omega_index--) {
            if (_player.lab[_omega_index].definition.id == "metroid.omega") {
                if (resolve_metroid_breach(_player, _omega_index)) {
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
        if (!resolve_metroid_breach(_player, _breach_index)) {
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
    while (true) {
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

        if (!resolve_metroid_breach(_player, _breach_index, true)) {
            return finish_containment_sequence();
        }
        _context.breach_count += 1;
        if (array_length(_player.board.characters) <= 0) {
            array_push(
                game_state.event_log,
                _player.name
                + " had no Character to discard for a breach."
            );
            continue;
        }
        game_state.priority_player = _context.player_index;
        pending_choice = {
            kind: "breach_character",
            player_index: _context.player_index,
            prompt: _player.name
                + ": choose a Character to discard for the breach."
        };
        ui_selected_kind = "";
        ui_selected_index = -1;
        return true;
    }
};

resolve_breach_character_choice = function(_character_index) {
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
        if (_ship.phazon_tokens >= 3) {
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

resolve_gain_cp_phase = function() {
    var _player = game_state.players[game_state.active_player];
    var _income = get_turn_income();
    _player.command_points += _income;
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
        while (array_length(_ship.cargo) > 0) {
            var _metroid = array_pop(_ship.cargo);
            if (game_state.game_mode != "batch"
            && game_state.game_mode != "network"
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
        if (_skip_ready) {
            _card.used_for_containment_this_turn = false;
        } else {
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

        if (_next_stage == 4 || _next_stage == 5) {
            game_state.mutation = min(
                game_state.mutation + 1,
                game_state.mutation_limit
            );
            array_push(
                game_state.event_log,
                "Mutation advanced to " + string(game_state.mutation)
                + "/" + string(game_state.mutation_limit) + "."
            );
        }
    }
};

resolve_mutation_phase = function() {
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
    } else {
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

count_event_log_matches = function(_needle) {
    var _count = 0;
    var _needle_lower = string_lower(_needle);
    for (var _event_index = 0;
         _event_index < array_length(game_state.event_log);
         _event_index++) {
        if (string_pos(
            _needle_lower,
            string_lower(game_state.event_log[_event_index])
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
        if (string_copy(
            string_lower(game_state.event_log[_event_index]),
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
    var _file = file_text_open_write(_path);
    if (_file < 0) {
        show_debug_message(
            "[BALANCE] Could not open match log: " + _path
        );
        return "";
    }
    file_text_write_string(
        _file,
        "LEGACY OF THE CHOZO - LIVE MATCH JOURNAL\n"
        + "Seed: " + string(game_state.seed) + "\n"
        + "Status: IN PROGRESS\n\n"
    );
    file_text_close(_file);
    game_state.balance_log_path = _path;
    balance_live_event_count = 0;
    balance_live_ai_count = 0;
    show_debug_message(
        "[BALANCE] Live match log created at "
        + get_export_display_path(_path)
    );
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
    var _file = file_text_open_append(_path);
    if (_file < 0) {
        show_debug_message(
            "[BALANCE] Could not append match log: " + _path
        );
        return false;
    }
    for (var _event_index = balance_live_event_count;
         _event_index < _event_total;
         _event_index++) {
        file_text_write_string(
            _file,
            "[EVENT " + string(_event_index + 1) + "] "
                + game_state.event_log[_event_index] + "\n"
        );
    }
    for (var _ai_index = balance_live_ai_count;
         _ai_index < _ai_total;
         _ai_index++) {
        file_text_write_string(
            _file,
            "[TRACE] " + ai_trace_log[_ai_index] + "\n"
        );
    }
    file_text_close(_file);
    balance_live_event_count = _event_total;
    balance_live_ai_count = _ai_total;
    return true;
};

write_balance_match_log = function() {
    if (!sync_balance_live_log()) {
        return "";
    }
    var _path = game_state.balance_log_path;
    var _file = file_text_open_append(_path);
    if (_file < 0) {
        show_debug_message(
            "[BALANCE] Could not finalize match log: " + _path
        );
        return "";
    }
    file_text_write_string(
        _file,
        "\nSTATUS: COMPLETE\n\nFINAL MATCH SUMMARY\n"
        + game_state.match_summary + "\n"
    );
    file_text_close(_file);
    show_debug_message(
        "[BALANCE] Match log finalized at "
        + get_export_display_path(_path)
    );
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
        "Queen Metroid Awakens appeared in the Shop and is awaiting resolution."
    );
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
        prompt:
            "Queen Metroid Awakens resolved. Inspect SR388, then advance to "
            + "return Queen to the Shop deck and refill its slot."
    };
    array_push(
        game_state.event_log,
        "Queen Metroid Awakens evolved all four SR388 slots."
    );

    if (game_state.mutation >= game_state.mutation_limit) {
        resolve_game_over();
    }
    return true;
};

finish_queen_shop_event = function() {
    if (is_undefined(pending_choice)
    || pending_choice.kind != "queen_event"
    || pending_choice.stage != "resolved") {
        return false;
    }
    var _shop_index = pending_choice.shop_index;
    if (_shop_index < 0
    || _shop_index >= array_length(game_state.shop_row)) {
        pending_choice = undefined;
        return false;
    }
    var _queen = game_state.shop_row[_shop_index];
    array_delete(game_state.shop_row, _shop_index, 1);
    _queen.zone = "shop_deck";
    // If Queen was the final card in the draw pile, recycle the discard
    // before returning her. Otherwise Queen becomes the only drawable card
    // and immediately retriggers forever while the replacement slot is open.
    if (array_length(game_state.shop_deck) <= 0
    && array_length(game_state.shop_discard) > 0) {
        game_state.shop_deck = game_state.shop_discard;
        game_state.shop_discard = [];
        array_push(
            game_state.event_log,
            "The Shop discard was recycled before Queen Metroid returned."
        );
    }
    array_push(game_state.shop_deck, _queen);
    shuffle_array(game_state.shop_deck);
    pending_choice = undefined;
    array_push(
        game_state.event_log,
        "Queen Metroid returned to the Shop deck and its slot was replaced."
    );
    refill_shop();
    return true;
};

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
    }

    switch (_card.definition.type) {
        case "character":
            array_push(_player.board.characters, _card);
            return true;

        case "ship":
            array_push(_player.board.ships, _card);
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

resolve_event_effect = function(_player, _card) {
    switch (_card.definition_id) {
        case "starter.orders_received":
            _player.command_points += 1;
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
            for (var _character_index = 0;
                 _character_index < array_length(_player.board.characters);
                 _character_index++) {
                _player.board.characters[_character_index].phazon_tokens += 1;
            }
            array_push(
                game_state.event_log,
                "Hive Mind Communication granted 2 CP and spread Phazon."
            );
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
        resolve_event_effect(_player, _card);
        var _event_was_destroyed = _card.definition_id == "loc.torizo";
        var _event_visual_until = current_time + 360;
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
        if (_ship.phazon_tokens >= 3) {
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
    return true;
};

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
                prompt: "Select a Character with Strength no greater than Dark Samus's Phazon tokens.",
                effect_kind: "dark_samus_discard"
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
        if (_source.phazon_tokens >= 3) {
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
            if (_target.phazon_tokens >= 3) {
                remove_ability_source(
                    _target_kind,
                    _target_index,
                    _target,
                    false
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

        case "corrupt_copy":
            var _copied_definition_id = _target.definition_id;
            var _copied_definition = _target.definition;
            _target.phazon_tokens += 1;
            _target.ready = false;
            if (_target.phazon_tokens >= 3) {
                remove_ability_source(
                    _target_kind,
                    _target_index,
                    _target,
                    false
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
                        _corrupt_zones[_corrupt_zone_index][
                            _corrupt_card_index
                        ].phazon_tokens += 3;
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
            prompt: _ability.prompt
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
        return _target_kind == "ship"
            && !is_undefined(_target);
    }
    if (_choice.target_kind == "ready_ship") {
        return _target_kind == "ship"
            && !is_undefined(_target)
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
        var _dark_samus_tokens = _choice.source.phazon_tokens
            + (card_has_faction(_target, "PZ") ? 1 : 0);
        return (_target_kind == "character"
            || _target_kind == "opponent_character")
            && !is_undefined(_target)
            && get_card_stat(_target) <= _dark_samus_tokens;
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
        return _target_kind == "character"
            && !is_undefined(_target)
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
        return (_target_kind == "opponent_character"
            || _target_kind == "opponent_ship"
            || _target_kind == "opponent_location"
            || _target_kind == "opponent_attachment")
            && !is_undefined(_target);
    }
    return false;
};

resolve_ability_target_choice = function(_target_kind, _target_index) {
    if (is_undefined(pending_choice)
    || pending_choice.kind != "ability_target") {
        return false;
    }
    var _choice = pending_choice;
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
    apply_phazon_interaction(_choice.source, _target);
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
            && _choice.source.phazon_tokens >= 3);
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
        interaction_mode: "contributors",
        ability_source_kind: "",
        ability_source_index: -1,
        ability_index: -1,
        raid_cost: _raid_cost,
        prompt: "Select an opposing Ship to raid."
    };
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
    _attacker.ready = false;
    if (_attacker.phazon_tokens >= 3) {
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
    pending_choice.interaction_mode = "contributors";
    pending_choice.prompt =
        "Select your ready Characters to contribute, then lock attackers.";
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
    pending_choice.interaction_mode = "contributors";
    pending_choice.ability_source_kind = "";
    pending_choice.ability_source_index = -1;
    pending_choice.ability_index = -1;
    game_state.priority_player = 1 - game_state.active_player;
    pending_choice.prompt =
        "Select the defender's ready Characters, then resolve the raid.";
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
    || pending_choice.interaction_mode != "abilities") {
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
        var _raid_kind = _raid_ability.effect_kind;
        var _raid_legal_kind = _raid_kind == "gain_cp"
            || _raid_kind == "ready_ship"
            || _raid_kind == "ship_security_1"
            || _raid_kind == "ship_security_2"
            || (_raid_kind == "raid_defense_1"
                && pending_choice.stage == "defenders");
        if (_raid_legal_kind
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

activate_raid_ability_index = function(_ability_index) {
    if (is_undefined(pending_choice)
    || pending_choice.kind != "raid") {
        return false;
    }
    pending_choice.ability_index = _ability_index;
    return activate_raid_selected_ability();
};

can_activate_raid_ability = function() {
    if (is_undefined(pending_choice)
    || pending_choice.kind != "raid"
    || pending_choice.interaction_mode != "abilities") {
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
    var _target_index = game_state.priority_player == game_state.active_player
        ? _raid.attacker_ship_index
        : _raid.defender_ship_index;
    var _raid_has_target = _ability.effect_kind != "gain_cp"
        && _ability.effect_kind != "raid_defense_1";
    var _raid_target_kind = game_state.priority_player
        == game_state.active_player
        ? "ship"
        : "opponent_ship";
    if (_raid_has_target) {
        apply_phazon_interaction(
            _source,
            get_ability_target_card(_raid_target_kind, _target_index)
        );
    }

    var _raid_resolution_count = consume_activation_modifiers(
        _source,
        _ability
    );
    pay_activated_ability_cost(
        _raid.ability_source_kind,
        _raid.ability_source_index,
        _source,
        _ability
    );
    var _resolved = false;
    for (var _raid_resolution_index = 0;
         _raid_resolution_index < _raid_resolution_count;
         _raid_resolution_index++) {
        _resolved = resolve_activated_ability(
            _source,
            _ability,
            !_raid_has_target
                ? ""
                : _raid_target_kind,
            !_raid_has_target
                ? -1
                : _target_index
        ) || _resolved;
    }
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
        && _player.board.characters[_board_index].phazon_tokens >= 3) {
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
    }
    array_delete(_player.board.ships, _ship_index, 1);
    clear_card_board_state(_ship);
    _ship.zone = "discard";
    array_push(_player.discard, _ship);
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
         || pending_choice.kind == "torizo_metroid")) {
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
    for (var _player_index = 0; _player_index < 2; _player_index++) {
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
            for (var _attachment_index = 0;
                 _attachment_index < array_length(_character.attachments);
                 _attachment_index++) {
                if (_character.attachments[_attachment_index].definition_id
                == "loc.the_baby") {
                    _baby_attached = true;
                    break;
                }
            }
            if (_baby_attached) {
                _character.ready = false;
                array_push(
                    game_state.event_log,
                    _character.definition.name
                    + " exhausted at end of turn because The Baby is attached."
                );
                if (_character.phazon_tokens >= 3) {
                    remove_ability_source(
                        _player_index == game_state.active_player
                            ? "character"
                            : "opponent_character",
                        _character_index,
                        _character,
                        false
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
                if (_location.phazon_tokens >= 3) {
                    remove_ability_source(
                        _player_index == game_state.active_player
                            ? "location"
                            : "opponent_location",
                        _location_index,
                        _location,
                        false
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
    draw_from_deck(_player, _researcher_count);
    pending_choice = {
        kind: "researcher_discard",
        remaining: _researcher_count,
        prompt: "Researcher: select "
            + string(_researcher_count)
            + " card(s) from your hand to discard."
    };
    array_push(
        game_state.event_log,
        "Researcher drew " + string(_researcher_count)
        + " card(s); matching discards are required."
    );
};

resolve_researcher_discard = function(_hand_index) {
    if (is_undefined(pending_choice)
    || pending_choice.kind != "researcher_discard") {
        return false;
    }
    var _player = game_state.players[game_state.active_player];
    if (_hand_index < 0 || _hand_index >= array_length(_player.hand)) {
        return false;
    }
    var _card = _player.hand[_hand_index];
    array_delete(_player.hand, _hand_index, 1);
    clear_card_board_state(_card);
    _card.zone = "discard";
    array_push(_player.discard, _card);
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

end_turn_action = function() {
    if (game_state.phase != "action") {
        return false;
    }
    if (!is_undefined(pending_choice)
    && (pending_choice.kind == "raid"
    || pending_choice.kind == "queen_event")) {
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
    game_state.phase = "mutation";
    resolve_mutation_phase();
    if (game_state.phase == "pass_turn"
    && current_time >= presentation_evolution_until_ms) {
        advance_game_phase();
    }
    return true;
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

get_identity_starter_config = function(_faction, _forced_starter_id) {
    switch (_faction) {
        case "GF": return {
            starter_id: "loc.gf_marine",
            replace_id: "starter.private_military"
        };
        case "SP": return {
            starter_id: "loc.attack_vessel",
            replace_id: "starter.sloop"
        };
        case "CZ": return {
            starter_id: is_undefined(_forced_starter_id)
                || _forced_starter_id == ""
                ? choose("loc.quiet_robe", "loc.raven_beak")
                : _forced_starter_id,
            replace_id: "starter.ship_captain"
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
            replace_id: "starter.military_rations"
        };
    }
};

apply_identity_starter = function(
    _player,
    _rename_identity,
    _forced_starter_id
) {
    if (!faction_starters_enabled || !_player.is_ai) {
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

    var _starter_id = _starter_config.starter_id;
    var _starter_definition = get_card_definition(_starter_id);
    var _starter_applied = false;
    if (_replace_index >= 0 && !is_undefined(_starter_definition)) {
        array_delete(_player.deck, _replace_index, 1);
        array_push(
            _player.deck,
            make_card_instance(_starter_definition, _player.index, "deck")
        );
        _starter_applied = true;
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
            _player.name + " replaced " + _replaced_definition.name + " with "
                + _starter_definition.name + " in their starter deck."
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
    game_state.players[0].name = net_player_name;
    game_state.players[0].is_ai = _mode == "ai_watch";
    game_state.players[1].is_ai = _is_ai_mode;
    game_state.players[0].favored_faction = "";
    game_state.players[1].favored_faction = "";
    if (_is_ai_mode) {
        // Visible AI players borrow the focused acquisition profiles used by
        // balance batches. Their displayed identities communicate strategic
        // preference without exposing test-oriented terminology.
        var _opponent_focuses = ["", "GF", "SP", "CZ", "BH", "PZ"];
        var _opponent_names = [
            "Mercenary",
            "Galactic Federation",
            "Space Pirate",
            "Chozo",
            "Bounty Hunter",
            "Phazon"
        ];
        if (_mode == "ai_watch") {
            var _player_one_focus_index = irandom(
                array_length(_opponent_focuses) - 1
            );
            game_state.players[0].favored_faction =
                _opponent_focuses[_player_one_focus_index];
            game_state.players[0].name =
                _opponent_names[_player_one_focus_index];
        }
        var _opponent_focus_index = irandom(
            array_length(_opponent_focuses) - 1
        );
        game_state.players[1].favored_faction =
            _opponent_focuses[_opponent_focus_index];
        game_state.players[1].name =
            _opponent_names[_opponent_focus_index];
        if (_mode == "ai_watch") {
            apply_identity_starter(
                game_state.players[0],
                true,
                undefined
            );
        }
        apply_identity_starter(
            game_state.players[1],
            true,
            undefined
        );
        if (_mode == "ai_watch"
        && game_state.players[0].name == game_state.players[1].name) {
            game_state.players[0].name += " Alpha";
            game_state.players[1].name += " Beta";
        }
    } else {
        game_state.players[1].name = "Player 2";
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
        if (_rematch_player.is_ai) {
            apply_identity_starter(
                _rematch_player,
                false,
                _rematch.player_starters[_rematch_player_index]
            );
        }
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
                stage: "contributors",
                attacker_ship_index: 0,
                defender_ship_index: 0,
                attacker_characters: [],
                defender_characters: [],
                attacker_ability_bonus: 0,
                defender_ability_bonus: 0,
                interaction_mode: "contributors",
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

batch_profile_label = function(_profile) {
    return _profile == "" ? "NONE" : _profile;
};

batch_count_owned_faction = function(_player, _faction) {
    if (_faction == "") {
        return 0;
    }
    var _count = 0;
    var _zones = [
        _player.deck,
        _player.hand,
        _player.discard,
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
            _count += card_matches_ai_profile(
                _zones[_zone_index][_card_index],
                _faction
            ) ? 1 : 0;
        }
    }
    return _count;
};

batch_count_owned_cards = function(_player) {
    return array_length(_player.deck)
        + array_length(_player.hand)
        + array_length(_player.discard)
        + array_length(_player.board.characters)
        + array_length(_player.board.ships)
        + array_length(_player.board.locations);
};

batch_make_timestamp = function() {
    var _now = date_current_datetime();
    var _month = date_get_month(_now);
    var _day = date_get_day(_now);
    var _hour = date_get_hour(_now);
    var _minute = date_get_minute(_now);
    var _second = date_get_second(_now);
    return string(date_get_year(_now))
        + (_month < 10 ? "0" : "") + string(_month)
        + (_day < 10 ? "0" : "") + string(_day)
        + "_"
        + (_hour < 10 ? "0" : "") + string(_hour)
        + (_minute < 10 ? "0" : "") + string(_minute)
        + (_second < 10 ? "0" : "") + string(_second);
};

get_export_display_path = function(_internal_path) {
    var _local_app_data = environment_get_variable("LOCALAPPDATA");
    var _filename = filename_name(_internal_path);
    if (_local_app_data == "") {
        return "%LOCALAPPDATA%\\LegacyofChozo\\" + _filename;
    }
    return _local_app_data + "\\LegacyofChozo\\" + _filename;
};

batch_get_schedule_info = function(_completed_index) {
    var _batch = global.loc_batch_state;
    if (variable_struct_exists(_batch, "schedule")) {
        return _batch.schedule[clamp(
            _completed_index,
            0,
            max(0, array_length(_batch.schedule) - 1)
        )];
    }
    _completed_index = clamp(
        _completed_index,
        0,
        max(0, _batch.total_games - 1)
    );
    var _pair_index = floor(_completed_index / 2);
    var _leg = _completed_index mod 2;
    var _matchup_index = floor(
        _pair_index / _batch.paired_seeds_per_matchup
    );
    var _seed_index = _pair_index mod _batch.paired_seeds_per_matchup;
    var _matchup = _batch.matchups[_matchup_index];
    var _p1_deck = _leg == 0 ? "A" : "B";
    var _p2_deck = _leg == 0 ? "B" : "A";
    var _starting_deck = _seed_index mod 2 == 0 ? "A" : "B";
    var _fallback_seed = _batch.seed_base + _pair_index;
    return {
        pair_index: _pair_index,
        pair_id: _pair_index + 1,
        leg: _leg + 1,
        matchup_index: _matchup_index,
        seed_index: _seed_index,
        seed: _fallback_seed,
        deck_a_profile: _matchup[0],
        deck_b_profile: _matchup[1],
        p1_deck: _p1_deck,
        p2_deck: _p2_deck,
        p1_profile: _leg == 0 ? _matchup[0] : _matchup[1],
        p2_profile: _leg == 0 ? _matchup[1] : _matchup[0],
        deck_a_starter_id: batch_identity_starter_id(
            _matchup[0], _fallback_seed, "A"
        ),
        deck_b_starter_id: batch_identity_starter_id(
            _matchup[1], _fallback_seed, "B"
        ),
        starting_deck: _starting_deck,
        first_player: _starting_deck == _p1_deck ? 1 : 2
    };
};

batch_identity_starter_id = function(_profile, _seed, _deck_key) {
    if (_profile == "CZ") {
        var _chozo_offset = _deck_key == "B" ? 1 : 0;
        return (abs(floor(_seed)) + _chozo_offset) mod 2 == 0
            ? "loc.quiet_robe"
            : "loc.raven_beak";
    }
    return get_identity_starter_config(_profile, undefined).starter_id;
};

batch_write_results_csv = function() {
    if (!variable_global_exists("loc_batch_state")) {
        return false;
    }
    var _batch = global.loc_batch_state;
    var _file = file_text_open_write(_batch.csv_path);
    if (_file < 0) {
        return false;
    }
    file_text_write_string(
        _file,
        "match,pair_id,leg,seed,deck_a_profile,deck_b_profile,"
        + "p1_deck,p2_deck,starting_deck,winner_deck,"
        + "first_player,p1_profile,p2_profile,winner,turns,mutation,"
        + "faction_starters,p1_starter,p2_starter,"
        + "p1_research,p2_research,p1_cp,p2_cp,p1_profile_cards,"
        + "valid,invalid_reason,replay_log,p2_profile_cards,"
        + "p1_owned_cards,p2_owned_cards,captures,"
        + "raids,breaches,evolutions,hand_refreshes,shop_refreshes\n"
    );
    for (var _result_index = 0;
         _result_index < array_length(_batch.results);
         _result_index++) {
        var _result = _batch.results[_result_index];
        file_text_write_string(
            _file,
            string(_result.match_number) + ","
            + string(_result.pair_id) + ","
            + string(_result.leg) + ","
            + string(_result.seed) + ","
            + batch_profile_label(_result.deck_a_profile) + ","
            + batch_profile_label(_result.deck_b_profile) + ","
            + _result.p1_deck + ","
            + _result.p2_deck + ","
            + _result.starting_deck + ","
            + _result.winner_deck + ","
            + string(_result.first_player) + ","
            + batch_profile_label(_result.p1_profile) + ","
            + batch_profile_label(_result.p2_profile) + ","
            + string(_result.winner) + ","
            + string(_result.turns) + ","
            + string(_result.mutation) + ","
            + string(_result.faction_starters) + ","
            + _result.p1_starter + ","
            + _result.p2_starter + ","
            + string(_result.p1_research) + ","
            + string(_result.p2_research) + ","
            + string(_result.p1_cp) + ","
            + string(_result.p2_cp) + ","
            + string(_result.p1_profile_cards) + ","
            + string(_result.valid) + ","
            + string_replace_all(_result.invalid_reason, ",", ";") + ","
            + string_replace_all(_result.replay_log, ",", ";") + ","
            + string(_result.p2_profile_cards) + ","
            + string(_result.p1_owned_cards) + ","
            + string(_result.p2_owned_cards) + ","
            + string(_result.captures) + ","
            + string(_result.raids) + ","
            + string(_result.breaches) + ","
            + string(_result.evolutions) + ","
            + string(_result.hand_refreshes) + ","
            + string(_result.shop_refreshes) + "\n"
        );
    }
    file_text_close(_file);
    return true;
};

batch_write_summary = function() {
    var _batch = global.loc_batch_state;
    var _file = file_text_open_write(_batch.summary_path);
    if (_file < 0) {
        return false;
    }
    file_text_write_string(
        _file,
        "LEGACY OF THE CHOZO - AI BATCH SUMMARY\n"
        + "Mode: " + string_upper(_batch.mode)
        + " | Paired seeds per matchup: "
        + string(_batch.paired_seeds_per_matchup)
        + " | Maximum games per matchup: "
        + string(_batch.games_per_matchup)
        + " | Completed: " + string(_batch.completed)
        + "/" + string(_batch.total_games) + "\n"
        + "Faction starters: "
        + (_batch.faction_starters_enabled ? "ENABLED" : "DISABLED")
        + "\n"
        + "Total pairs: " + string(_batch.total_pairs) + "\n"
        + "Raw CSV: " + get_export_display_path(_batch.csv_path) + "\n\n"
    );
    for (var _matchup_index = 0;
         _matchup_index < array_length(_batch.matchups);
         _matchup_index++) {
        var _matchup = _batch.matchups[_matchup_index];
        var _games = 0;
        var _a_p1_wins = 0;
        var _a_p2_wins = 0;
        var _b_p1_wins = 0;
        var _b_p2_wins = 0;
        var _draws = 0;
        var _turn_total = 0;
        var _a_research_total = 0;
        var _b_research_total = 0;
        var _a_focus_total = 0;
        var _b_focus_total = 0;
        var _a_sweeps = 0;
        var _b_sweeps = 0;
        var _splits = 0;
        var _mixed_pairs = 0;
        var _invalid_games = 0;
        for (var _result_index = 0;
             _result_index < array_length(_batch.results);
             _result_index++) {
            var _result = _batch.results[_result_index];
            if (_result.deck_a_profile == _matchup[0]
            && _result.deck_b_profile == _matchup[1]) {
                if (!_result.valid) {
                    _invalid_games += 1;
                    continue;
                }
                _games += 1;
                _a_p1_wins += _result.winner_deck == "A"
                    && _result.p1_deck == "A" ? 1 : 0;
                _a_p2_wins += _result.winner_deck == "A"
                    && _result.p2_deck == "A" ? 1 : 0;
                _b_p1_wins += _result.winner_deck == "B"
                    && _result.p1_deck == "B" ? 1 : 0;
                _b_p2_wins += _result.winner_deck == "B"
                    && _result.p2_deck == "B" ? 1 : 0;
                _draws += _result.winner == 0 ? 1 : 0;
                _turn_total += _result.turns;
                var _a_is_p1 = _result.p1_deck == "A";
                _a_research_total += _a_is_p1
                    ? _result.p1_research : _result.p2_research;
                _b_research_total += _a_is_p1
                    ? _result.p2_research : _result.p1_research;
                _a_focus_total += _a_is_p1
                    ? _result.p1_profile_cards
                    : _result.p2_profile_cards;
                _b_focus_total += _a_is_p1
                    ? _result.p2_profile_cards
                    : _result.p1_profile_cards;
                if (_result.leg == 1) {
                    var _other_winner = "";
                    var _other_index = _result_index + 1;
                    if (_other_index < array_length(_batch.results)) {
                        var _other = _batch.results[_other_index];
                        if (_other.pair_id == _result.pair_id
                        && _other.leg == 2) {
                            _other_winner = _other.winner_deck;
                        }
                    }
                    if (_result.winner_deck == "A"
                    && _other_winner == "A") {
                        _a_sweeps += 1;
                    } else if (_result.winner_deck == "B"
                    && _other_winner == "B") {
                        _b_sweeps += 1;
                    } else if (
                        (_result.winner_deck == "A"
                        && _other_winner == "B")
                        || (_result.winner_deck == "B"
                        && _other_winner == "A")
                    ) {
                        _splits += 1;
                    } else {
                        _mixed_pairs += 1;
                    }
                }
            }
        }
        if (_games > 0 || _invalid_games > 0) {
            var _summary_divisor = max(1, _games);
            var _summary_pair_count = _matchup[0] == _matchup[1]
                ? _games : floor(_games / 2);
            file_text_write_string(
                _file,
                batch_profile_label(_matchup[0]) + " vs "
                + batch_profile_label(_matchup[1])
                + ": " + string(_summary_pair_count) + " pairs / "
                + string(_games) + " valid games | invalid "
                + string(_invalid_games) + "\n"
                + "  Deck A " + batch_profile_label(_matchup[0])
                + ": slot 1 wins " + string(_a_p1_wins)
                + " | slot 2 wins " + string(_a_p2_wins)
                + " | both-seat sweeps " + string(_a_sweeps) + "\n"
                + "  Deck B " + batch_profile_label(_matchup[1])
                + ": slot 1 wins " + string(_b_p1_wins)
                + " | slot 2 wins " + string(_b_p2_wins)
                + " | both-seat sweeps " + string(_b_sweeps) + "\n"
                + "  Split pairs " + string(_splits)
                + " | draw/mixed pairs " + string(_mixed_pairs)
                + " | drawn games " + string(_draws)
                + " | avg turns "
                + string_format(_turn_total / _summary_divisor, 0, 2)
                + " | avg research A-B "
                + string_format(_a_research_total / _summary_divisor, 0, 2)
                + "-" + string_format(
                    _b_research_total / _summary_divisor,
                    0,
                    2
                )
                + " | avg favored cards A-B "
                + string_format(_a_focus_total / _summary_divisor, 0, 2)
                + "-" + string_format(
                    _b_focus_total / _summary_divisor,
                    0,
                    2
                ) + "\n\n"
            );
        }
    }
    var _profiles = ["", "GF", "SP", "CZ", "BH", "PZ"];
    file_text_write_string(_file, "PROFILE SLOT RESULTS\n");
    for (var _profile_index = 0;
         _profile_index < array_length(_profiles);
         _profile_index++) {
        var _profile = _profiles[_profile_index];
        var _slot1_wins = 0;
        var _slot2_wins = 0;
        var _profile_sweeps = 0;
        for (var _result_index = 0;
             _result_index < array_length(_batch.results);
             _result_index++) {
            var _result = _batch.results[_result_index];
            if (!_result.valid) {
                continue;
            }
            _slot1_wins += _result.winner == 1
                && _result.p1_profile == _profile ? 1 : 0;
            _slot2_wins += _result.winner == 2
                && _result.p2_profile == _profile ? 1 : 0;
            if (_result.leg == 1 && _result.winner_deck != "") {
                var _other_winner = "";
                var _other_index = _result_index + 1;
                if (_other_index < array_length(_batch.results)) {
                    var _other = _batch.results[_other_index];
                    if (_other.pair_id == _result.pair_id
                    && _other.leg == 2) {
                        _other_winner = _other.winner_deck;
                    }
                }
                var _winner_profile = _result.winner_deck == "A"
                    ? _result.deck_a_profile : _result.deck_b_profile;
                if (_other_winner == _result.winner_deck
                && _winner_profile == _profile) {
                    _profile_sweeps += 1;
                }
            }
        }
        file_text_write_string(
            _file,
            batch_profile_label(_profile)
            + ": slot 1 wins " + string(_slot1_wins)
            + " | slot 2 wins " + string(_slot2_wins)
            + " | total wins " + string(_slot1_wins + _slot2_wins)
            + " | both-seat sweeps " + string(_profile_sweeps) + "\n"
        );
    }
    file_text_close(_file);
    return true;
};

batch_prepare_next_room = function() {
    var _batch = global.loc_batch_state;
    var _schedule_index = _batch.replay_active
        ? _batch.replay_index : _batch.completed;
    var _schedule = batch_get_schedule_info(_schedule_index);
    global.loc_test_seed = _schedule.seed;
    global.loc_batch_active = true;
    room_restart();
    return true;
};

start_batch_run = function(_matrix_mode) {
    var _profiles = ["", "GF", "SP", "CZ", "BH", "PZ"];
    var _matchups = [];
    if (_matrix_mode) {
        for (var _left = 0; _left < array_length(_profiles); _left++) {
            for (var _right = _left;
                 _right < array_length(_profiles);
                 _right++) {
                array_push(
                    _matchups,
                    [_profiles[_left], _profiles[_right]]
                );
            }
        }
    } else {
        array_push(
            _matchups,
            [
                batch_profile_options[batch_profile_p1_index],
                batch_profile_options[batch_profile_p2_index]
            ]
        );
    }
    var _stamp = batch_make_timestamp();
    var _paired_seeds = batch_game_options[batch_game_option_index];
    // The title room otherwise begins from the fixed test RNG seed, causing
    // every new batch to replay the exact same seed sequence.
    randomize();
    var _batch_seed_base = batch_seed_text == ""
        ? irandom(2000000000)
        : real(batch_seed_text);
    var _schedule = [];
    var _pair_id = 0;
    for (var _schedule_matchup_index = 0;
         _schedule_matchup_index < array_length(_matchups);
         _schedule_matchup_index++) {
        var _schedule_matchup = _matchups[_schedule_matchup_index];
        for (var _schedule_seed_index = 0;
             _schedule_seed_index < _paired_seeds;
             _schedule_seed_index++) {
            var _schedule_pair_index = _pair_id;
            _pair_id += 1;
            var _schedule_seed = _batch_seed_base + _schedule_pair_index;
            var _schedule_starting_deck =
                _schedule_seed_index mod 2 == 0 ? "A" : "B";
            var _deck_a_starter_id = batch_identity_starter_id(
                _schedule_matchup[0], _schedule_seed, "A"
            );
            var _deck_b_starter_id = batch_identity_starter_id(
                _schedule_matchup[1], _schedule_seed, "B"
            );
            array_push(_schedule, {
                pair_index: _schedule_pair_index,
                pair_id: _schedule_pair_index + 1,
                leg: 1,
                matchup_index: _schedule_matchup_index,
                seed_index: _schedule_seed_index,
                seed: _schedule_seed,
                deck_a_profile: _schedule_matchup[0],
                deck_b_profile: _schedule_matchup[1],
                p1_deck: "A",
                p2_deck: "B",
                p1_profile: _schedule_matchup[0],
                p2_profile: _schedule_matchup[1],
                deck_a_starter_id: _deck_a_starter_id,
                deck_b_starter_id: _deck_b_starter_id,
                starting_deck: _schedule_starting_deck,
                first_player: _schedule_starting_deck == "A" ? 1 : 2
            });
            // Identical profiles have no distinct mirrored configuration.
            if (_schedule_matchup[0] != _schedule_matchup[1]) {
                array_push(_schedule, {
                    pair_index: _schedule_pair_index,
                    pair_id: _schedule_pair_index + 1,
                    leg: 2,
                    matchup_index: _schedule_matchup_index,
                    seed_index: _schedule_seed_index,
                    seed: _schedule_seed,
                    deck_a_profile: _schedule_matchup[0],
                    deck_b_profile: _schedule_matchup[1],
                    p1_deck: "B",
                    p2_deck: "A",
                    p1_profile: _schedule_matchup[1],
                    p2_profile: _schedule_matchup[0],
                    deck_a_starter_id: _deck_a_starter_id,
                    deck_b_starter_id: _deck_b_starter_id,
                    starting_deck: _schedule_starting_deck,
                    first_player: _schedule_starting_deck == "B" ? 1 : 2
                });
            }
        }
    }
    global.loc_batch_state = {
        mode: _matrix_mode ? "matrix" : "matchup",
        matchups: _matchups,
        schedule: _schedule,
        games_per_matchup: _paired_seeds * 2,
        paired_seeds_per_matchup: _paired_seeds,
        total_pairs: array_length(_matchups) * _paired_seeds,
        total_games: array_length(_schedule),
        completed: 0,
        seed_base: _batch_seed_base,
        results: [],
        faction_starters_enabled: faction_starters_enabled,
        detailed_logs: batch_detailed_logs,
        replay_active: false,
        replay_index: -1,
        csv_path: working_directory
            + "loc_batch_" + _stamp + ".csv",
        summary_path: working_directory
            + "loc_batch_" + _stamp + "_summary.txt"
    };
    batch_write_results_csv();
    return batch_prepare_next_room();
};

configure_batch_room = function() {
    var _batch = global.loc_batch_state;
    var _schedule_index = _batch.replay_active
        ? _batch.replay_index : _batch.completed;
    var _schedule = batch_get_schedule_info(_schedule_index);
    game_state.game_mode = "batch";
    game_state.players[0].is_ai = true;
    game_state.players[1].is_ai = true;
    game_state.players[0].favored_faction = _schedule.p1_profile;
    game_state.players[1].favored_faction = _schedule.p2_profile;
    game_state.players[0].name = "AI " + _schedule.p1_deck + " "
        + batch_profile_label(_schedule.p1_profile);
    game_state.players[1].name = "AI " + _schedule.p2_deck + " "
        + batch_profile_label(_schedule.p2_profile);
    faction_starters_enabled = variable_struct_exists(
        _batch,
        "faction_starters_enabled"
    ) ? _batch.faction_starters_enabled : false;
    var _p1_batch_starter_id = _schedule.p1_deck == "A"
        ? _schedule.deck_a_starter_id
        : _schedule.deck_b_starter_id;
    var _p2_batch_starter_id = _schedule.p2_deck == "A"
        ? _schedule.deck_a_starter_id
        : _schedule.deck_b_starter_id;
    apply_identity_starter(
        game_state.players[0],
        false,
        _p1_batch_starter_id
    );
    apply_identity_starter(
        game_state.players[1],
        false,
        _p2_batch_starter_id
    );
    game_state.active_player = _schedule.first_player - 1;
    game_state.priority_player = game_state.active_player;
    game_state.view_player = game_state.active_player;
    title_menu_active = false;
    handoff_active = false;
    ai_action_delay = 0;
    batch_match_steps = 0;
    batch_match_invalid_reason = "";
    array_push(
        game_state.event_log,
        "Batch match " + string(_schedule_index + 1)
        + "/" + string(_batch.total_games)
        + ", pair " + string(_schedule.pair_id)
        + "/" + string(_batch.total_pairs)
        + " leg " + string(_schedule.leg) + ": A "
        + batch_profile_label(_schedule.deck_a_profile) + " vs B "
        + batch_profile_label(_schedule.deck_b_profile)
        + "; starters "
        + (faction_starters_enabled
            ? _schedule.deck_a_starter_id + " / "
                + _schedule.deck_b_starter_id
            : "disabled")
        + "; starting deck " + _schedule.starting_deck + "."
    );
    return true;
};

finish_batch_match = function() {
    var _batch = global.loc_batch_state;
    if (_batch.replay_active) {
        var _replay_result =
            _batch.results[array_length(_batch.results) - 1];
        _replay_result.replay_log = game_state.balance_log_path;
        _batch.replay_active = false;
        _batch.replay_index = -1;
        batch_write_results_csv();
        if (_batch.completed >= _batch.total_games) {
            batch_write_summary();
            global.loc_batch_active = false;
            global.loc_batch_last_summary = _batch.summary_path;
            global.loc_batch_show_results = true;
            room_restart();
            return true;
        }
        return batch_prepare_next_room();
    }
    var _schedule = batch_get_schedule_info(_batch.completed);
    var _p0 = game_state.players[0];
    var _p1 = game_state.players[1];
    var _winner_slot = game_state.winner < 0
        ? 0 : game_state.winner + 1;
    var _winner_deck = _winner_slot == 0
        ? ""
        : (_winner_slot == 1
            ? _schedule.p1_deck : _schedule.p2_deck);
    array_push(
        _batch.results,
        {
            match_number: _batch.completed + 1,
            pair_id: _schedule.pair_id,
            leg: _schedule.leg,
            seed: game_state.seed,
            deck_a_profile: _schedule.deck_a_profile,
            deck_b_profile: _schedule.deck_b_profile,
            p1_deck: _schedule.p1_deck,
            p2_deck: _schedule.p2_deck,
            starting_deck: _schedule.starting_deck,
            winner_deck: _winner_deck,
            first_player: _schedule.first_player,
            p1_profile: _p0.favored_faction,
            p2_profile: _p1.favored_faction,
            faction_starters: faction_starters_enabled,
            p1_starter: _p0.identity_starter_id,
            p2_starter: _p1.identity_starter_id,
            winner: _winner_slot,
            turns: game_state.turn_number,
            mutation: game_state.mutation,
            p1_research: get_player_research(_p0),
            p2_research: get_player_research(_p1),
            p1_cp: _p0.command_points,
            p2_cp: _p1.command_points,
            p1_profile_cards: batch_count_owned_faction(
                _p0,
                _p0.favored_faction
            ),
            valid: batch_match_invalid_reason == "",
            invalid_reason: batch_match_invalid_reason,
            replay_log: "",
            p2_profile_cards: batch_count_owned_faction(
                _p1,
                _p1.favored_faction
            ),
            p1_owned_cards: batch_count_owned_cards(_p0),
            p2_owned_cards: batch_count_owned_cards(_p1),
            captures: count_event_log_matches(" captured "),
            raids: count_event_log_prefix("Raid "),
            breaches: count_event_log_matches(" breached"),
            evolutions: count_event_log_matches(" evolved"),
            hand_refreshes: count_event_log_matches(
                " hand card(s) for 1 CP"
            ),
            shop_refreshes: count_event_log_matches(
                "refreshed the Shop"
            )
        }
    );
    _batch.completed += 1;
    batch_write_results_csv();
    if (batch_match_invalid_reason != "") {
        _batch.replay_active = true;
        _batch.replay_index = _batch.completed - 1;
        return batch_prepare_next_room();
    }
    if (_batch.completed >= _batch.total_games) {
        batch_write_summary();
        global.loc_batch_active = false;
        global.loc_batch_last_summary = _batch.summary_path;
        global.loc_batch_show_results = true;
        global.loc_test_seed = 388;
        show_debug_message(
            "[BATCH] Complete. Summary: "
            + get_export_display_path(_batch.summary_path)
        );
        room_restart();
        return true;
    }
    return batch_prepare_next_room();
};

network_send_message = function(_socket, _message) {
    if (_socket < 0) {
        return false;
    }
    var _payload = json_stringify(_message);
    var _buffer = buffer_create(
        string_byte_length(_payload) + 1,
        buffer_fixed,
        1
    );
    buffer_write(_buffer, buffer_string, _payload);
    var _sent = network_send_packet(
        _socket,
        _buffer,
        buffer_tell(_buffer)
    );
    buffer_delete(_buffer);
    return _sent >= 0;
};

network_begin_host = function() {
    global.loc_player_name = net_player_name;
    net_role = "host";
    net_status = "Opening host on port " + string(net_port) + "...";
    net_server = network_create_server(network_socket_tcp, net_port, 1);
    if (net_server < 0) {
        net_status = "Could not open port " + string(net_port) + ".";
        return false;
    }
    title_menu_active = false;
    network_lobby_active = true;
    net_status = "Waiting for Player 2 on port "
        + string(net_port) + "...";
    show_debug_message("[NET] " + net_status);
    return true;
};

network_open_join = function() {
    global.loc_player_name = net_player_name;
    net_role = "client";
    net_status = "Enter the host address.";
    title_menu_active = false;
    network_lobby_active = true;
    net_join_field = "address";
    keyboard_string = net_ip_input;
    return true;
};

network_connect_to_host = function() {
    if (net_ip_input == "") {
        net_status = "Enter an IPv4 address or host name.";
        return false;
    }
    if (net_socket >= 0) {
        network_destroy(net_socket);
    }
    net_socket = network_create_socket(network_socket_tcp);
    if (net_socket < 0) {
        net_status = "Could not create a network socket.";
        return false;
    }
    net_status = "Connecting to " + net_ip_input + ":"
        + string(net_port) + "...";
    global.loc_player_name = net_player_name;
    net_join_field = "";
    network_connect_async(net_socket, net_ip_input, net_port);
    show_debug_message("[NET] " + net_status);
    return true;
};

network_prepare_match_restart = function(_role, _socket, _server, _seed) {
    global.loc_test_seed = _seed;
    global.loc_network_resume = true;
    global.loc_network_role = _role;
    global.loc_network_socket = _socket;
    global.loc_network_server = _server;
    room_restart();
};

network_expected_player = function() {
    if (!is_undefined(pending_choice)) {
        if (variable_struct_exists(pending_choice, "player_index")) {
            return pending_choice.player_index;
        }
        if (variable_struct_exists(pending_choice, "owner_index")) {
            return pending_choice.owner_index;
        }
        if (variable_struct_exists(pending_choice, "payer_index")) {
            return pending_choice.payer_index;
        }
    }
    return game_state.priority_player;
};

network_execute_input = function(_input) {
    ui_selected_kind = _input.selected_kind;
    ui_selected_index = _input.selected_index;
    if (_input.input_type == "click") {
        var _kind = _input.kind;
        var _index = _input.index;
        if (is_undefined(pending_choice)) {
            return false;
        }
        switch (pending_choice.kind) {
            case "breach_character":
                if (_kind != "character"
                && _kind != "opponent_character") return false;
                return resolve_breach_character_choice(_index);
            case "olympus_ready":
                if (_kind != "character"
                && _kind != "opponent_character") return false;
                return resolve_olympus_ready_choice(_index);
            case "researcher_discard":
                if (_kind != "hand") return false;
                return resolve_researcher_discard(_index);
            case "raid":
                if (pending_choice.stage == "target") {
                    return select_raid_target(_index);
                }
                if (pending_choice.interaction_mode == "contributors") {
                    if (pending_choice.stage == "attackers") {
                        if (_kind != "character") return false;
                        return raid_toggle_character(_index, false);
                    }
                    if (pending_choice.stage == "defenders") {
                        if (_kind != "opponent_character") return false;
                        return raid_toggle_character(_index, true);
                    }
                }
                if (pending_choice.interaction_mode == "abilities") {
                    return select_raid_ability_source(_kind, _index);
                }
                break;
            case "ability_target":
                return resolve_ability_target_choice(_kind, _index);
            case "quiet_robe_metroids":
                if (_kind != "metroid") return false;
                return resolve_quiet_robe_metroid_choice(_index);
            case "torizo_metroid":
                if (_kind != "lab") return false;
                return resolve_torizo_metroid_choice(_index);
            case "space_pirate_ready":
                return resolve_space_pirate_ready(_kind, _index);
            case "capture_metroid":
                if (_kind != "metroid") return false;
                var _captured = capture_metroid_action(
                    pending_choice.ship_index,
                    _index
                );
                if (_captured) {
                    pending_choice = undefined;
                    ui_selected_kind = "";
                    ui_selected_index = -1;
                }
                return _captured;
            case "hand_refresh":
                if (_kind != "hand") return false;
                return toggle_hand_refresh_card(_index);
        }
        return false;
    }

    switch (_input.action) {
        case "advance_phase": return advance_game_phase();
        case "containment_no_ship": return resolve_turn_containment(-1);
        case "containment_use_ship":
            return resolve_turn_containment(_input.selected_index);
        case "end_turn": return end_turn_action();
        case "reserve": return reserve_shop_card(_input.selected_index);
        case "deploy": return deploy_shop_card(_input.selected_index);
        case "play": return play_hand_card(_input.selected_index);
        case "capture": return begin_capture_choice(_input.selected_index);
        case "raid": return begin_raid_choice(_input.selected_index);
        case "lock_raid_attackers": return lock_raid_attackers();
        case "resolve_raid": return resolve_raid();
        case "raid_cargo_0": return finish_attacker_raid_win(0);
        case "raid_cargo_1": return finish_attacker_raid_win(1);
        case "raid_cargo_2": return finish_attacker_raid_win(2);
        case "raid_cargo_3": return finish_attacker_raid_win(3);
        case "raid_toggle_mode": return toggle_raid_ability_mode();
        case "raid_activate": return activate_raid_selected_ability();
        case "raid_use_0": return activate_raid_ability_index(0);
        case "raid_use_1": return activate_raid_ability_index(1);
        case "raid_use_2": return activate_raid_ability_index(2);
        case "resolve_queen": return resolve_queen_shop_event();
        case "finish_queen": return finish_queen_shop_event();
        case "special_containment_no_ship":
            return choose_special_containment_ship(-1);
        case "special_containment_use_ship":
            return choose_special_containment_ship(_input.selected_index);
        case "adam_prevent_breach":
            return resolve_adam_breach_choice(true);
        case "adam_allow_breach":
            return resolve_adam_breach_choice(false);
        case "space_pirate_pay":
            return resolve_space_pirate_payment(true);
        case "space_pirate_decline":
            return resolve_space_pirate_payment(false);
        case "faction_gf": return resolve_faction_choice("GF");
        case "faction_sp": return resolve_faction_choice("SP");
        case "faction_cz": return resolve_faction_choice("CZ");
        case "faction_bh": return resolve_faction_choice("BH");
        case "faction_pz": return resolve_faction_choice("PZ");
        case "activate_0":
            return activate_selected_ability(
                _input.selected_kind,
                _input.selected_index,
                0
            );
        case "activate_1":
            return activate_selected_ability(
                _input.selected_kind,
                _input.selected_index,
                1
            );
        case "activate_2":
            return activate_selected_ability(
                _input.selected_kind,
                _input.selected_index,
                2
            );
        case "refresh_hand": return begin_hand_refresh_choice();
        case "confirm_hand_refresh": return confirm_hand_refresh_choice();
        case "refresh_shop": return refresh_shop_action();
        case "cancel": return cancel_pending_choice();
    }
    return false;
};

network_submit_input = function(_input) {
    if (network_local_player != network_expected_player()) {
        show_debug_message("[NET] Ignored out-of-priority local input.");
        return false;
    }
    if (net_role == "host") {
        net_command_sequence += 1;
        _input.type = "command_commit";
        _input.sequence = net_command_sequence;
        network_send_message(net_peer_socket, _input);
        return network_execute_input(_input);
    }
    _input.type = "command_request";
    return network_send_message(net_socket, _input);
};

ai_card_utility = function(_card, _player) {
    if (is_undefined(_card)) {
        return -1000;
    }
    var _type = _card.definition.type;
    var _value = 0;
    if (_type == "character") {
        _value = 2 + (get_card_stat(_card) * 1.4);
    } else if (_type == "ship") {
        _value = 2.5 + (get_card_stat(_card) * 1.25);
    } else if (_type == "location") {
        _value = 4;
    } else if (_type == "event") {
        _value = 2.5;
    }
    if (variable_struct_exists(_card.definition, "effect")
    && !is_undefined(_card.definition.effect)
    && string(_card.definition.effect) != ""
    && string(_card.definition.effect) != "--") {
        _value += 1.5;
    }
    var _matching_factions = 0;
    var _zones = [
        _player.board.characters,
        _player.board.ships,
        _player.board.locations
    ];
    var _card_factions = variable_struct_exists(
        _card.definition,
        "factions"
    ) && is_array(_card.definition.factions)
        ? _card.definition.factions
        : [];
    for (var _faction_index = 0;
         _faction_index < array_length(_card_factions);
         _faction_index++) {
        var _faction = _card_factions[_faction_index];
        for (var _zone_index = 0;
             _zone_index < array_length(_zones);
             _zone_index++) {
            for (var _card_index = 0;
                 _card_index < array_length(_zones[_zone_index]);
                 _card_index++) {
                if (card_has_faction(
                    _zones[_zone_index][_card_index],
                    _faction
                )) {
                    _matching_factions += 1;
                }
            }
        }
    }
    _value += min(4, _matching_factions * 0.45);
    var _effect_text = variable_struct_exists(_card.definition, "effect")
        && !is_undefined(_card.definition.effect)
        ? string_lower(string(_card.definition.effect))
        : "";
    if (card_has_faction(_card, "GF")) {
        _value += string_pos("cp", _effect_text) > 0 ? 1.1 : 0.35;
    }
    if (card_has_faction(_card, "SP")) {
        _value += _type == "ship" ? 0.8 : 0.25;
        _value += string_pos("raid", _effect_text) > 0 ? 1.1 : 0;
    }
    if (card_has_faction(_card, "CZ")) {
        _value += string_pos("metroid", _effect_text) > 0 ? 1.1 : 0.3;
        _value += string_pos("discard", _effect_text) > 0 ? 0.7 : 0;
    }
    if (card_has_faction(_card, "BH")) {
        _value += array_length(get_activated_abilities(_card)) > 0
            ? 0.9
            : 0.25;
    }
    if (card_has_faction(_card, "PZ")) {
        var _phazon_board_count = 0;
        for (var _pz_zone_index = 0;
             _pz_zone_index < array_length(_zones);
             _pz_zone_index++) {
            for (var _pz_card_index = 0;
                 _pz_card_index < array_length(_zones[_pz_zone_index]);
                 _pz_card_index++) {
                _phazon_board_count += card_has_faction(
                    _zones[_pz_zone_index][_pz_card_index],
                    "PZ"
                ) ? 1 : 0;
            }
        }
        _value += 0.45 + min(2, _phazon_board_count * 0.35);
    }
    if (_player.favored_faction != "") {
        _value += card_matches_ai_profile(
            _card,
            _player.favored_faction
        )
            ? 4.5
            : -0.8;
    }
    return _value;
};

ai_hand_card_keep_value = function(_card, _player) {
    var _value = ai_card_utility(_card, _player);
    if (_card.definition.type != "event"
    && variable_struct_exists(_card.definition, "costs")
    && is_real(_card.definition.costs.reserve)) {
        var _cost = max(
            0,
            _card.definition.costs.reserve
                - get_zebes_discount(_player, _card)
        );
        _value -= _cost * 0.4;
    }
    return _value;
};

ai_plan_hand_refresh = function(_player) {
    var _plan = {
        indices: [],
        expected_draw_value: 0,
        improvement: 0,
        score: -100000
    };
    if (_player.command_points < 1) {
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

    for (var _hand_index = 0;
         _hand_index < array_length(_player.hand);
         _hand_index++) {
        var _keep_value = ai_hand_card_keep_value(
            _player.hand[_hand_index],
            _player
        );
        var _gain = _plan.expected_draw_value - _keep_value;
        if (_gain > 0.65) {
            array_push(_plan.indices, _hand_index);
            _plan.improvement += _gain;
        }
    }
    if (array_length(_plan.indices) > 0 || _missing_cards > 0) {
        // One CP refreshes every selected card, so broader weak hands make the
        // action increasingly efficient.
        _plan.score = (_plan.improvement * 0.75) - 1.25;
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
            (_card_value * 1.05) - (_deploy_cost * 0.62)
        );
    }
    var _reserve_cost = get_modified_reserve_cost(_player, _card);
    if (is_real(_reserve_cost)
    && _available_cp >= _reserve_cost) {
        _best = max(
            _best,
            (_card_value * 0.72) - (_reserve_cost * 0.48)
        );
    }
    return _best;
};

ai_score_shop_refresh = function(_player, _visible_best_score) {
    if (_player.command_points < 1) {
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

    var _score_total = 0;
    var _score_count = 0;
    var _score_max = 0;
    for (var _pool_index = 0;
         _pool_index < array_length(_pool);
         _pool_index++) {
        var _candidate_score = ai_shop_acquisition_score(
            _pool[_pool_index],
            _player,
            _future_cp
        );
        if (_candidate_score > -100000) {
            _score_total += max(0, _candidate_score);
            _score_max = max(_score_max, _candidate_score);
            _score_count += 1;
        }
    }
    if (_score_count <= 0) {
        return -100000;
    }
    var _mean = _score_total / _score_count;
    // Estimate the best of five unknown draws without consulting their order.
    var _expected_best = _mean + ((_score_max - _mean) * 0.55);
    return _expected_best - max(0, _visible_best_score) - 1;
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
    var _value = ai_card_utility(_target, _player);
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
            return _value + 2;
        case "ship_security_1":
        case "ship_security_2":
            return _kind == "ship" && _target.ready
                ? _value + array_length(_target.cargo) * 2
                : -100000;
        case "exhaust_card":
            if (!_opponent_target || !_target.ready) return -100000;
            return _value + (_target.phazon_tokens >= 3 ? 8 : 0);
        case "discard_card":
        case "dark_samus_discard":
            return _opponent_target ? _value + 5 : -100000;
        case "copy_until_end_turn":
        case "corrupt_copy":
            return _value + (_opponent_target ? 0.5 : 0);
        case "attach_source":
        case "attach_choose_faction":
            return !_opponent_target ? _value : -100000;
        case "leviathan_attach":
            return _opponent_target ? _value + 2 : -100000;
        case "quiet_robe_place":
            return _kind == "ship" && _target.ready
                ? get_card_stat(_target) * 1.4
                : -100000;
        case "deploy_shop_ship":
        case "reserve_shop_event_free":
            return ai_card_utility(_target, _player) + 3;
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
    var _score = -_ability.cost_cp * 0.7;
    switch (_ability.effect_kind) {
        case "gain_cp": return 3.5;
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
            return _has_bh_followup ? 2.8 : -100000;
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
            return _has_gf_followup ? 3.2 : -100000;
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
                ? 2.3 + (_best_exhausted_pirate_value * 0.15)
                : -100000;
        case "ped_strength":
            return _source.phazon_tokens > 0
                ? (_source.phazon_tokens * 1.5) - _ability.cost_cp
                : -100000;
        case "corrupt_all":
            var _own_count = array_length(_player.board.characters)
                + array_length(_player.board.ships);
            var _enemy = game_state.players[1 - _player.index];
            var _enemy_count = array_length(_enemy.board.characters)
                + array_length(_enemy.board.ships);
            return (_enemy_count - _own_count) * 2.2;
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
                ? 0.8
                : 0.35
        );
    } else {
        _score += 1;
    }
    if (_ability.cost_destroy) {
        _score -= ai_card_utility(_source, _player) * 0.7;
    }
    if (_ability.cost_exhaust) {
        _score -= get_card_stat(_source) * 0.18;
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
    var _raid_cost = get_raid_cost(_attacker_player);
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
    for (var _defender_character_index = 0;
         _defender_character_index
            < array_length(_defender_player.board.characters);
         _defender_character_index++) {
        var _defender_character =
            _defender_player.board.characters[_defender_character_index];
        if (_defender_character.ready) {
            _defender_max += get_card_stat(
                _defender_character,
                "raid_defender_character"
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
        return -100000;
    }
    var _cargo_value = 0;
    for (var _cargo_index = 0;
         _cargo_index < array_length(_defender.cargo);
         _cargo_index++) {
        _cargo_value +=
            _defender.cargo[_cargo_index].definition.research_value * 3;
    }
    return ai_card_utility(_defender, _attacker_player) * 0.8
        + _cargo_value
        + (_defender_max * 0.3)
        - (_raid_cost * 1.2)
        - max(0, _defender_max - get_card_stat(
            _attacker,
            "raid_attacker_ship"
        )) * 0.2;
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
    var _attacker = _attacker_player.board.ships[
        _raid.attacker_ship_index
    ];
    var _defender = _defender_player.board.ships[
        _raid.defender_ship_index
    ];
    var _attacker_total = get_card_stat(
        _attacker,
        "raid_attacker_ship"
    ) + _raid.attacker_ability_bonus;
    for (var _attacker_character_index = 0;
         _attacker_character_index
            < array_length(_raid.attacker_characters);
         _attacker_character_index++) {
        _attacker_total += get_card_stat(
            _attacker_player.board.characters[
                _raid.attacker_characters[_attacker_character_index]
            ],
            "raid_attacker_character"
        );
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
            _available_strength += get_card_stat(
                _defender_character,
                "raid_defender_character"
            );
        }
    }

    var _maximum_without_ability = _defender_base + _available_strength;
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
            for (var _candidate_position = 0;
                 _candidate_position < array_length(_available_indices);
                 _candidate_position++) {
                var _candidate_index =
                    _available_indices[_candidate_position];
                var _candidate_strength = get_card_stat(
                    _defender_player.board.characters[_candidate_index],
                    "raid_defender_character"
                );
                if (_candidate_strength > _best_strength) {
                    _best_strength = _candidate_strength;
                    _best_position = _candidate_position;
                }
            }
            var _chosen_index = _available_indices[_best_position];
            array_delete(_available_indices, _best_position, 1);
            array_push(_raid.defender_characters, _chosen_index);
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
                    var _raid_score = ai_raid_plan_score(
                        _choice.attacker_ship_index,
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
                var _raid_attacker_ship =
                    _raid_attacker_player.board.ships[
                        _choice.attacker_ship_index
                    ];
                var _raid_defender_ship =
                    _raid_defender_player.board.ships[
                        _choice.defender_ship_index
                    ];
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
                            _attacker_option_index
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
                        _best_attacker_index
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

        case "ability_target":
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
            var _losing_ship = _choice.winner_is_attacker
                ? game_state.players[
                    1 - game_state.active_player
                ].board.ships[_choice.defender_ship_index]
                : game_state.players[
                    game_state.active_player
                ].board.ships[_choice.attacker_ship_index];
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
    var _best_kind = "end";
    var _best_index = -1;
    var _best_secondary = -1;
    var _best_source_kind = "";
    var _best_ability_index = -1;
    var _best_refresh_indices = [];
    var _best_visible_shop_score = -100000;
    var _best_score = 0;
    ai_debug_log(
        "Evaluating action phase with " + string(_player.command_points)
        + " CP, " + string(array_length(_player.hand)) + " cards in hand, "
        + "and " + string(array_length(game_state.shop_row))
        + " Shop cards."
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
        if (_hand_card.definition_id == "loc.sa_x_breaks_out"
        || !can_play_hand_card(_hand_index)) {
            ai_debug_log(
                "Hand rejected: " + _hand_card.definition.name
                + " (not currently legal or deliberately deferred)."
            );
            continue;
        }
        var _hand_cost = _hand_card.definition.type == "event"
            ? 0
            : max(
                0,
                _hand_card.definition.costs.reserve
                    - get_zebes_discount(_player, _hand_card)
            );
        var _hand_score = ai_card_utility(_hand_card, _player) * 1.35
            - (_hand_cost * 0.45);
        ai_debug_log(
            "Hand candidate: " + _hand_card.definition.name
            + "; cost " + string(_hand_cost)
            + ", score " + string_format(_hand_score, 0, 2) + "."
        );
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
        if (_hand_refresh_plan.score > _best_score) {
            _best_score = _hand_refresh_plan.score;
            _best_kind = "refresh_hand";
            _best_refresh_indices = _hand_refresh_plan.indices;
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
            var _capture_score =
                (_metroid.definition.research_value * 2.6)
                + (_metroid.definition.hazard * 0.2)
                - _capture_cost;
            ai_debug_log(
                "Capture candidate: Ship "
                + _ship.definition.name + ", "
                + _metroid.definition.name + "; cost "
                + string(_capture_cost) + ", score "
                + string_format(_capture_score, 0, 2) + "."
            );
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
            var _deploy_score = (_card_value * 1.05)
                - (_deploy_cost * 0.62);
            _best_visible_shop_score = max(
                _best_visible_shop_score,
                _deploy_score
            );
            ai_debug_log(
                "Deploy candidate: " + _shop_card.definition.name
                + "; cost " + string(_deploy_cost)
                + ", score " + string_format(_deploy_score, 0, 2) + "."
            );
            if (_deploy_score > _best_score) {
                _best_score = _deploy_score;
                _best_kind = "deploy";
                _best_index = _shop_index;
            }
        }
        var _reserve_cost = get_modified_reserve_cost(
            _player,
            _shop_card
        );
        if (is_real(_reserve_cost)
        && _player.command_points >= _reserve_cost) {
            var _reserve_score = (_card_value * 0.72)
                - (_reserve_cost * 0.48);
            _best_visible_shop_score = max(
                _best_visible_shop_score,
                _reserve_score
            );
            ai_debug_log(
                "Reserve candidate: " + _shop_card.definition.name
                + "; cost " + string(_reserve_cost)
                + ", score " + string_format(_reserve_score, 0, 2) + "."
            );
            if (_reserve_score > _best_score) {
                _best_score = _reserve_score;
                _best_kind = "reserve";
                _best_index = _shop_index;
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
        if (_shop_refresh_score > _best_score) {
            _best_score = _shop_refresh_score;
            _best_kind = "refresh_shop";
        }
    }

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
            return refresh_hand_cards(_best_refresh_indices);
        case "refresh_shop":
            ai_debug_log(
                "Decision: refresh the Shop with winning score "
                + string_format(_best_score, 0, 2) + "."
            );
            ai_last_action = "Refreshing Shop";
            return refresh_shop_action();
    }
    ai_debug_log(
        "Decision: end turn because no legal action scored above 0."
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
        if (!_pending_resolved && game_state.phase != "game_over") {
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
                : (game_state.game_mode == "network"
                    ? network_local_player
                    : 0);
            game_state.turn_number += 1;
            game_state.phase = "containment";
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
        _assert(
            array_length(game_state.shop_row) == 5
            && array_length(game_state.shop_deck) == 3
            && array_length(game_state.shop_discard) == 0,
            "Queen recycles an exhausted Shop deck before replacement",
            "The replacement pool did not include the recycled discard."
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
            -1
        );
        choose_special_containment_ship(-1);
        var _queen_reached_second = !is_undefined(pending_choice)
            && pending_choice.kind == "special_containment_ship"
            && pending_choice.player_index == 1;
        choose_special_containment_ship(-1);
        _assert(
            _queen_reached_second
            && is_undefined(special_containment_sequence)
            && !is_undefined(pending_choice)
            && pending_choice.kind == "queen_event"
            && pending_choice.stage == "resolved",
            "Queen containment completes across both players",
            "The second player or Queen continuation was skipped."
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
            ["GF", "loc.gf_marine", "starter.private_military", 1],
            ["SP", "loc.attack_vessel", "starter.sloop", 0],
            ["CZ", "loc.quiet_robe", "starter.ship_captain", 0],
            ["CZ", "loc.raven_beak", "starter.ship_captain", 0],
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
                && _starter_found == 1
                && _replacement_found == _starter_case[3]
                && _starter_player.identity_starter_id == _starter_case[1],
                "Identity starter replacement "
                    + batch_profile_label(_starter_case[0])
                    + " " + _starter_case[1],
                "Deck size, inserted card, or replaced-card count was wrong."
            );
        }

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

test_ready_active_player = function() {
    var _player = game_state.players[game_state.active_player];
    ready_card_array(_player.board.characters, false);
    ready_card_array(_player.board.ships, false);
    ready_card_array(_player.board.locations, false);
    array_push(game_state.event_log, "TEST: Active player's board readied.");
};

test_deploy_selected_shop = function() {
    if (test_selected_kind != "shop"
    || test_selected_index < 0
    || test_selected_index >= array_length(game_state.shop_row)) {
        log_action_failure("TEST: Select a permanent in the Shop first.");
        return false;
    }
    var _card = game_state.shop_row[test_selected_index];
    if (_card.definition.type == "event") {
        log_action_failure("TEST: Free deployment requires a permanent.");
        return false;
    }
    array_delete(game_state.shop_row, test_selected_index, 1);
    put_card_in_play(
        game_state.players[game_state.active_player],
        _card
    );
    refill_shop();
    test_selected_kind = "";
    test_selected_index = -1;
    if (!is_undefined(pending_choice)
    && pending_choice.kind == "queen_event") {
        test_tools_open = false;
    }
    array_push(
        game_state.event_log,
        "TEST: " + _card.definition.name + " deployed for free."
    );
    return true;
};

test_add_metroid_to_selected_ship = function(_stage) {
    if (test_selected_kind != "ship") {
        log_action_failure("TEST: Select one of your Ships first.");
        return false;
    }
    var _player = game_state.players[game_state.active_player];
    if (test_selected_index < 0
    || test_selected_index >= array_length(_player.board.ships)) {
        return false;
    }
    var _ship = _player.board.ships[test_selected_index];
    if (array_length(_ship.cargo) >= 1) {
        log_action_failure("TEST: The selected Ship is already carrying cargo.");
        return false;
    }
    var _metroid = create_metroid_for_stage(_stage);
    _metroid.zone = "ship";
    _metroid.host_ship_instance_id = _ship.instance_id;
    array_push(_ship.cargo, _metroid);
    array_push(
        game_state.event_log,
        "TEST: Added " + _metroid.definition.name + " to "
        + _ship.definition.name + "."
    );
    return true;
};

test_force_queen = function() {
    if (!is_undefined(pending_choice)) {
        log_action_failure("TEST: Resolve the current choice first.");
        return false;
    }
    for (var _row_index = 0;
         _row_index < array_length(game_state.shop_row);
         _row_index++) {
        if (game_state.shop_row[_row_index].definition_id
        == "loc.queen_metroid_awakens") {
            begin_queen_shop_event(_row_index);
            test_tools_open = false;
            return true;
        }
    }

    var _queen = undefined;
    for (var _deck_index = 0;
         _deck_index < array_length(game_state.shop_deck);
         _deck_index++) {
        if (game_state.shop_deck[_deck_index].definition_id
        == "loc.queen_metroid_awakens") {
            _queen = game_state.shop_deck[_deck_index];
            array_delete(game_state.shop_deck, _deck_index, 1);
            break;
        }
    }
    if (is_undefined(_queen)) {
        for (var _discard_index = 0;
             _discard_index < array_length(game_state.shop_discard);
             _discard_index++) {
            if (game_state.shop_discard[_discard_index].definition_id
            == "loc.queen_metroid_awakens") {
                _queen = game_state.shop_discard[_discard_index];
                array_delete(game_state.shop_discard, _discard_index, 1);
                break;
            }
        }
    }
    if (is_undefined(_queen)) {
        log_action_failure("TEST: Queen Metroid could not be located.");
        return false;
    }

    if (array_length(game_state.shop_row) >= 5) {
        var _replaced = array_pop(game_state.shop_row);
        _replaced.zone = "shop_discard";
        array_push(game_state.shop_discard, _replaced);
    }
    _queen.zone = "shop";
    array_push(game_state.shop_row, _queen);
    begin_queen_shop_event(array_length(game_state.shop_row) - 1);
    test_tools_open = false;
    return true;
};

selected_shop_index = 0;
selected_hand_index = 0;
selected_ship_index = 0;
selected_metroid_source = 0;
selection_focus = 0;
ui_hit_regions = [];
ui_hover_kind = "";
ui_hover_index = -1;
ui_hover_instance = undefined;
ui_selected_kind = "";
ui_selected_index = -1;
ui_selected_instance_id = -1;
ui_context_preview_kind = "";
ui_context_preview_index = -1;
ui_context_preview_until_ms = 0;
ui_hover_action_has_context = false;
context_button_source_kind = "";
context_button_source_index = -1;
ui_screen_width = 1920;
ui_screen_height = 1080;
// Board geometry is authored once at the original 1080p composition. Window
// growth expands the viewport around this world; it must never reflow cards.
board_layout_width = 1531;
board_layout_height = 1080;
ui_resize_camera = -1;
ui_hud_width = 360;
board_viewport_right = ui_screen_width - ui_hud_width;
board_camera_world_width = 1530;
board_viewport_top = 48;
board_camera_world_top = -329;
board_camera_world_bottom = 1080;
board_camera_x = 0;
board_camera_y = board_viewport_top;
board_camera_zoom = 1;
board_camera_target_x = board_camera_x;
board_camera_target_y = board_camera_y;
board_camera_target_zoom = board_camera_zoom;
board_camera_min_zoom = 0.20;
board_camera_max_zoom = 2.25;
board_camera_dragging = false;
board_camera_drag_last_x = 0;
board_camera_drag_last_y = 0;
board_camera_last_turn = -1;
board_camera_auto_center = true;
board_camera_center_far = false;
board_camera_locked = false;
board_camera_last_auto_focus = "";
board_camera_recenter_requested = false;
last_hand_click_instance_id = -1;
last_hand_click_time = -1000;
pending_choice = undefined;
containment_resolution = undefined;
special_containment_sequence = undefined;
pending_ability_source_kind = "";
pending_ability_source_index = -1;
test_tools_open = false;
test_tools_tab = "game";
test_animation_page = 0;
pause_screen_open = false;
debug_headless_to_game_over_active = false;
debug_headless_original_mode = "";
debug_headless_original_ai = [false, false];
debug_headless_steps = 0;
debug_headless_last_signature = "";
debug_headless_same_state_steps = 0;
end_counter_tint_surface = -1;
end_screen_preview = undefined;
test_selected_kind = "";
test_selected_index = -1;
lab_pull_amount = 0;
opponent_lab_pull_amount = 0;
handoff_active = false;
title_menu_active = true;
presentation_opening_started = false;
presentation_opening_active = false;
presentation_opening_frame = 0;
network_lobby_active = false;
net_role = "";
net_status = "";
net_ip_input = "127.0.0.1";
net_port = 6510;
net_server = -1;
net_socket = -1;
net_peer_socket = -1;
net_player_name = variable_global_exists("loc_player_name")
    ? global.loc_player_name
    : "Player 1";
faction_starters_enabled = !variable_global_exists(
    "loc_faction_starters_enabled"
) || global.loc_faction_starters_enabled;
title_name_editing = false;
batch_menu_active = false;
if (variable_global_exists("loc_batch_show_results")
&& global.loc_batch_show_results) {
    batch_menu_active = true;
}
batch_profile_options = ["", "GF", "SP", "CZ", "BH", "PZ"];
batch_profile_p1_index = 0;
batch_profile_p2_index = 0;
batch_game_options = [1, 10, 50, 100, 500];
batch_game_option_index = 1;
batch_detailed_logs = false;
batch_match_steps = 0;
batch_match_invalid_reason = "";
batch_seed_text = "";
batch_seed_editing = false;
batch_report_show_counts = false;
net_join_field = "";
network_local_player = 0;
net_command_sequence = 0;
net_last_applied_sequence = 0;
ai_next_step_time = 0;
ai_action_delay = 420;
ai_last_action = "";
ai_trace_log = [];
balance_live_event_count = 0;
balance_live_ai_count = 0;

ai_debug_log = function(_message) {
    if (game_state.game_mode == "batch"
    && variable_global_exists("loc_batch_state")
    && !global.loc_batch_state.detailed_logs) {
        return;
    }
    var _trace_line = "[AI T" + string(game_state.turn_number)
        + " P" + string(game_state.active_player + 1)
        + " " + string_upper(game_state.phase) + "] "
        + string(_message);
    array_push(ai_trace_log, _trace_line);
    show_debug_message(_trace_line);
    if (!title_menu_active) {
        try {
            sync_balance_live_log();
        } catch (_ai_balance_sync_error) {
            show_debug_message(
                "[BALANCE] AI trace sync failed: "
                + string(_ai_balance_sync_error)
            );
        }
    }
};
game_state.phase = "containment";
skip_empty_lab_containment();
array_push(
    game_state.event_log,
    "Press Space to resolve start phases; press E to end, mutate, and pass."
);

load_complete = array_length(load_errors) == 0
    && array_length(setup_errors) == 0;
if (variable_global_exists("loc_rematch_config")
&& global.loc_rematch_config.pending) {
    resume_rematch();
}
if (variable_global_exists("loc_ai_random_seed_ready")
&& global.loc_ai_random_seed_ready) {
    var _resume_ai_mode =
        variable_global_exists("loc_ai_start_mode")
            ? global.loc_ai_start_mode
            : "ai";
    start_game_mode(_resume_ai_mode);
}
if (variable_global_exists("loc_network_resume")
&& global.loc_network_resume) {
    global.loc_network_resume = false;
    net_role = global.loc_network_role;
    net_socket = global.loc_network_socket;
    net_peer_socket = global.loc_network_socket;
    net_server = global.loc_network_server;
    network_local_player = net_role == "host" ? 0 : 1;
    game_state.game_mode = "network";
    game_state.players[0].name = global.loc_network_host_name;
    game_state.players[1].name = global.loc_network_guest_name;
    game_state.view_player = network_local_player;
    title_menu_active = false;
    network_lobby_active = false;
    handoff_active = false;
    net_status = "Connected as Player "
        + string(network_local_player + 1) + ".";
    show_debug_message(
        "[NET] Match resumed as " + net_role + " with seed "
        + string(game_seed) + "."
    );
}
if (variable_global_exists("loc_batch_active")
&& global.loc_batch_active
&& variable_global_exists("loc_batch_state")) {
    configure_batch_room();
}
show_debug_message(
    "Game setup: "
    + string(card_database.totals.definitions)
    + " definitions / "
    + string(card_database.totals.copies)
    + " copies / loader errors "
    + string(array_length(load_errors))
    + " / setup errors "
    + string(array_length(setup_errors))
    + " errors"
);
