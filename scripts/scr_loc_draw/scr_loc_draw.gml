function loc_draw() {
    /// @description Draw the game state as a proportional 1080p debug layout.

    var _screen_width = ui_screen_width;
    var _screen_height = ui_screen_height;

    if (game_state.game_mode == "batch"
    && variable_global_exists("loc_batch_state")) {
        var _batch_draw_state = global.loc_batch_state;
        var _batch_draw_schedule = batch_get_schedule_info(
            _batch_draw_state.replay_active
                ? _batch_draw_state.replay_index
                : _batch_draw_state.completed
        );
        draw_clear(make_color_rgb(5, 9, 15));
        // Batch diagnostics contain machine-oriented values such as
        // GAME_OVER and pending-choice identifiers. Use the antialiased system
        // font so every character is available and scaled text remains legible.
        draw_set_font(-1);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_color(make_color_rgb(126, 225, 255));
        draw_text_transformed(
            _screen_width * 0.5,
            _screen_height * 0.42,
            _batch_draw_state.replay_active
                ? "INVALID MATCH DIAGNOSTIC REPLAY"
                : "AI BATCH SIMULATION",
            2,
            2,
            0
        );
        draw_set_color(c_white);
        draw_text(
            _screen_width * 0.5,
            _screen_height * 0.51,
            "MATCH " + string(
                (_batch_draw_state.replay_active
                    ? _batch_draw_state.replay_index
                    : _batch_draw_state.completed) + 1
            )
            + " / " + string(_batch_draw_state.total_games)
            + "  |  PAIR " + string(_batch_draw_schedule.pair_id)
            + " / " + string(_batch_draw_state.total_pairs)
            + "  LEG " + string(_batch_draw_schedule.leg)
        );
        draw_text(
            _screen_width * 0.5,
            _screen_height * 0.56,
            game_state.players[0].name + "  VS  "
            + game_state.players[1].name
        );
        draw_set_color(make_color_rgb(120, 135, 150));
        draw_text(
            _screen_width * 0.5,
            _screen_height * 0.62,
            "Seed " + string(game_state.seed)
            + " | Turn " + string(game_state.turn_number)
            + " | " + string_upper(game_state.phase)
        );
        draw_text(
            _screen_width * 0.5,
            _screen_height * 0.67,
            "Last AI step: "
            + (ai_last_action == "" ? "none" : ai_last_action)
        );
        draw_text(
            _screen_width * 0.5,
            _screen_height * 0.72,
            "Match decisions: " + string(batch_match_steps)
            + (_batch_draw_state.replay_active
                ? " | detailed journal active" : "")
        );
        draw_set_font(-1);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        exit;
    }

    // Palette switching is a hotseat handoff cue. Persistent-view modes retain
    // the local player's palette regardless of whose turn is resolving.
    var _secondary_hotseat_palette = game_state.game_mode == "hotseat"
        && game_state.active_player == 1;
    var _settings_accent = function(_index, _player_index) {
        if (_index == 7 && title_menu_active) {
            return LOC_COLOR_GF;
        }
        if (_index == 7
        && _player_index >= 0
        && _player_index < array_length(game_state.players)) {
            switch (game_state.players[_player_index].favored_faction) {
                case "GF": return LOC_COLOR_GF;
                case "SP": return LOC_COLOR_SP;
                case "CZ": return LOC_COLOR_CZ;
                case "BH": return LOC_COLOR_BH;
                case "PZ": return LOC_COLOR_PZ;
                default: return LOC_COLOR_NEUTRAL;
            }
        }
        switch (_index) {
            case 1: return make_color_rgb(92, 242, 112);
            case 2: return make_color_rgb(190, 112, 255);
            case 3: return make_color_rgb(255, 185, 70);
            case 4: return make_color_rgb(225, 235, 242);
            case 5: return make_color_rgb(255, 92, 92);
            case 6: return make_color_rgb(75, 135, 255);
        }
        // The selectable cyan matches the GF visual language, but remains a
        // generic UI choice and never changes faction identity or ownership.
        return LOC_COLOR_GF;
    };
    var _ui_accent = _settings_accent(settings_ui_color_index, 0);
    var _opponent_ui_accent = _settings_accent(
        settings_opponent_ui_color_index,
        1
    );
    var _ui_palette_accent = _secondary_hotseat_palette
        ? _opponent_ui_accent
        : _ui_accent;
    ui_color_background = _secondary_hotseat_palette
        ? merge_color(c_black, _opponent_ui_accent, 0.055)
        : merge_color(c_black, _ui_accent, 0.055);
    ui_color_header = _secondary_hotseat_palette
        ? merge_color(c_black, _opponent_ui_accent, 0.09)
        : merge_color(c_black, _ui_accent, 0.09);
    draw_clear(ui_color_background);
    var _space_source_width = sprite_get_width(Back_Space);
    var _space_source_height = sprite_get_height(Back_Space);
    // Give the starfield enough overscan to drift gently behind the board camera.
    // It follows only a fraction of camera travel, preserving the sense that the
    // cards and SR388 occupy a nearer layer.
    var _space_draw_width = _screen_width * 1.14;
    var _space_draw_height = _space_draw_width
        * (_space_source_height / max(1, _space_source_width));
    var _space_draw_x = (_screen_width - _space_draw_width) * 0.5
        - (board_camera_x * 0.035);
    var _space_draw_y = (_screen_height - _space_draw_height) * 0.5
        - ((board_camera_y - board_viewport_top) * 0.025);
    draw_set_alpha(1);
    draw_sprite_stretched(
        Back_Space,
        0,
        _space_draw_x,
        _space_draw_y,
        _space_draw_width,
        _space_draw_height
    );
    draw_set_alpha(1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    ui_hit_regions = [];
    ui_gameplay_input_enabled = title_menu_active
        || network_lobby_active
        || (
            game_state.game_mode != "ai_watch"
            && !game_state.players[game_state.view_player].is_ai
            && (
                game_state.active_player == game_state.view_player
                || (!is_undefined(pending_choice)
                    && game_state.priority_player == game_state.view_player)
            )
        );

    ui_color_panel = _secondary_hotseat_palette
        ? merge_color(c_black, _opponent_ui_accent, 0.16)
        : merge_color(c_black, _ui_accent, 0.16);
    ui_color_panel_alt = _secondary_hotseat_palette
        ? merge_color(c_black, _opponent_ui_accent, 0.22)
        : merge_color(c_black, _ui_accent, 0.22);
    ui_color_line = _secondary_hotseat_palette
        ? merge_color(c_black, _opponent_ui_accent, 0.46)
        : merge_color(c_black, _ui_accent, 0.46);
    ui_color_title = _secondary_hotseat_palette
        ? _opponent_ui_accent
        : _ui_accent;
    ui_color_text = make_color_rgb(232, 240, 246);
    ui_color_muted = _secondary_hotseat_palette
        ? merge_color(make_color_rgb(145, 155, 165),
            _opponent_ui_accent, 0.22)
        : merge_color(make_color_rgb(145, 155, 165), _ui_accent, 0.22);
    ui_color_success = make_color_rgb(99, 224, 139);
    ui_color_error = make_color_rgb(255, 99, 110);
    ui_color_mutation = make_color_rgb(242, 89, 89);
    ui_color_selected = make_color_rgb(255, 211, 92);
    // Neutral foundations calibrated against the original cyan palette. The
    // default remains visually unchanged while other accents receive the same
    // restrained dark tint instead of inheriting cyan's blue-gray surfaces.
    ui_color_hud_surface = merge_color(
        make_color_rgb(28, 25, 30),
        _ui_palette_accent,
        0.05
    );
    ui_color_hud_line = merge_color(
        make_color_rgb(74, 68, 78),
        _ui_palette_accent,
        0.10
    );
    ui_color_menu_background = merge_color(
        make_color_rgb(3, 3, 10),
        _ui_palette_accent,
        0.03
    );
    ui_color_menu_panel = merge_color(
        make_color_rgb(7, 9, 21),
        _ui_palette_accent,
        0.07
    );
    ui_color_menu_line = merge_color(
        make_color_rgb(36, 45, 59),
        _ui_palette_accent,
        0.25
    );

    var _draw_panel = function(_x1, _y1, _x2, _y2, _label) {
        draw_set_alpha(0.54);
        draw_set_color(merge_color(c_black, ui_color_title, 0.60));
        draw_rectangle(_x1, _y1, _x2, _y2, false);
        draw_set_alpha(0.9);
        draw_set_color(ui_color_title);
        draw_rectangle(_x1, _y1, _x2, _y2, true);
        draw_set_alpha(1);
        draw_set_color(ui_color_title);
        draw_set_font(FNT_METROID);
        var _panel_label_scale = min(
            1,
            (_x2 - _x1 - 20) / max(1, string_width(_label))
        );
        if (_panel_label_scale >= 0.999) {
            draw_text(_x1 + 10, _y1 + 7, _label);
        } else {
            draw_text_transformed(
                _x1 + 10,
                _y1 + 7,
                _label,
                _panel_label_scale,
                _panel_label_scale,
                0
            );
        }
        draw_set_font(-1);
    };

    var _draw_modal_panel = function(_x1, _y1, _x2, _y2, _label) {
        draw_set_alpha(1);
        draw_set_color(ui_color_hud_surface);
        draw_rectangle(_x1, _y1, _x2, _y2, false);
        draw_set_color(ui_color_hud_line);
        draw_rectangle(_x1, _y1, _x2, _y2, true);
        draw_set_color(ui_color_title);
        draw_set_font(FNT_METROID);
        var _modal_label_scale = min(
            1,
            (_x2 - _x1 - 20) / max(1, string_width(_label))
        );
        if (_modal_label_scale >= 0.999) {
            draw_text(_x1 + 10, _y1 + 7, _label);
        } else {
            draw_text_transformed(
                _x1 + 10,
                _y1 + 7,
                _label,
                _modal_label_scale,
                _modal_label_scale,
                0
            );
        }
        draw_set_font(-1);
    };

    var _draw_selection = function(_x, _y, _width, _height, _focused) {
        draw_set_color(_focused ? ui_color_selected : ui_color_title);
        draw_rectangle(
            _x - 3,
            _y - 3,
            _x + _width + 3,
            _y + _height + 3,
            true
        );
    };

    // Locations remain fully separated while forming the most compact deliberate
    // shape for their count: one, vertical pair, triangle, square, then compact
    // centered rows. Opponent clusters reverse their row order rotationally.
    var _get_location_cluster_position = function(
        _index,
        _count,
        _card_w,
        _card_h,
        _left_edge,
        _right_edge,
        _center_y,
        _anchor_right,
        _reverse_rows
    ) {
        var _rows = [];
        switch (_count) {
            case 1: _rows = [1]; break;
            case 2: _rows = [1, 1]; break;
            case 3: _rows = [1, 2]; break;
            case 4: _rows = [2, 2]; break;
            case 5: _rows = [2, 3]; break;
            case 6: _rows = [3, 3]; break;
            default:
                var _columns = max(1, ceil(sqrt(max(1, _count))));
                var _remaining = _count;
                while (_remaining > 0) {
                    array_push(_rows, min(_columns, _remaining));
                    _remaining -= _columns;
                }
                break;
        }
        if (_reverse_rows) {
            var _reversed_rows = [];
            for (var _reverse_index = array_length(_rows) - 1;
                 _reverse_index >= 0;
                 _reverse_index--) {
                array_push(_reversed_rows, _rows[_reverse_index]);
            }
            _rows = _reversed_rows;
        }
        var _gap_x = 10;
        var _gap_y = 10;
        var _max_columns = 1;
        for (var _row_count_index = 0;
             _row_count_index < array_length(_rows);
             _row_count_index++) {
            _max_columns = max(_max_columns, _rows[_row_count_index]);
        }
        var _cluster_w = (_max_columns * _card_w)
            + ((_max_columns - 1) * _gap_x);
        var _cluster_h = (array_length(_rows) * _card_h)
            + ((array_length(_rows) - 1) * _gap_y);
        var _cluster_x = _anchor_right
            ? _right_edge - _cluster_w
            : _left_edge;
        var _cluster_y = _center_y - (_cluster_h * 0.5);
        var _cursor = 0;
        for (var _row_index = 0;
             _row_index < array_length(_rows);
             _row_index++) {
            var _row_count = _rows[_row_index];
            if (_index < _cursor + _row_count) {
                var _column_index = _index - _cursor;
                var _row_w = (_row_count * _card_w)
                    + ((_row_count - 1) * _gap_x);
                return {
                    x: _cluster_x + ((_cluster_w - _row_w) * 0.5)
                        + (_column_index * (_card_w + _gap_x)),
                    y: _cluster_y + (_row_index * (_card_h + _gap_y))
                };
            }
            _cursor += _row_count;
        }
        return {x: _cluster_x, y: _cluster_y};
    };

    // Yellow is reserved for a card action that is both legal and affordable at
    // this exact moment. This does not represent ordinary Capture or Raid actions.
    var _draw_playability_line = function(
        _x,
        _y,
        _width,
        _start_fraction,
        _end_fraction
    ) {
        var _line_x1 = _x + (_width * _start_fraction);
        var _line_x2 = _x + (_width * _end_fraction);
        var _playable_y = _y - 5;
        draw_set_alpha(0.28);
        draw_set_color(make_color_rgb(255, 222, 54));
        draw_rectangle(
            _line_x1,
            _playable_y - 2,
            _line_x2,
            _playable_y + 3,
            false
        );
        draw_set_alpha(1);
        draw_set_color(make_color_rgb(255, 238, 92));
        draw_rectangle(
            _line_x1,
            _playable_y,
            _line_x2,
            _playable_y + 2,
            false
        );
    };

    var _card_has_usable_ability = function(_kind, _index, _card) {
        if (!ui_gameplay_input_enabled
        || is_undefined(_card)
        || game_state.priority_player != game_state.view_player) {
            return false;
        }
        var _abilities = get_activated_abilities(_card);
        for (var _ability_index = 0;
             _ability_index < array_length(_abilities);
             _ability_index++) {
            if (can_activate_selected_ability(_kind, _index, _ability_index)) {
                return true;
            }
        }
        return false;
    };

    // A card owns one presentation position across every visible zone. When the
    // game moves that instance, its next renderer inherits the exact position at
    // which the previous renderer left it.
    var _get_lerped_board_position = function(
        _card,
        _target_x,
        _target_y,
        _initial_x,
        _initial_y,
        _zone_name,
        _delay_ms,
        _speed_override
    ) {
        var _speed = is_undefined(_speed_override)
            ? 0.18
            : _speed_override;
        if (!_card.ui_position_initialized) {
            _card.ui_x = is_undefined(_initial_x) ? _target_x : _initial_x;
            _card.ui_y = is_undefined(_initial_y) ? _target_y : _initial_y;
            _card.ui_position_initialized = true;
        }
        if (_card.ui_zone != _zone_name) {
            _card.ui_zone = _zone_name;
            _card.ui_move_after_ms = max(
                current_time + max(0, _delay_ms),
                _card.ui_hold_until_ms
            );
        }
        if (current_time >= max(
            _card.ui_move_after_ms,
            _card.ui_hold_until_ms
        )) {
            _card.ui_x = lerp(_card.ui_x, _target_x, _speed);
            _card.ui_y = lerp(_card.ui_y, _target_y, _speed);
        }
        if (abs(_card.ui_x - _target_x) < 0.25) {
            _card.ui_x = _target_x;
        }
        if (abs(_card.ui_y - _target_y) < 0.25) {
            _card.ui_y = _target_y;
        }
        return {x: _card.ui_x, y: _card.ui_y};
    };

    var _get_card_bounds = function(
        _instance,
        _x,
        _y,
        _max_width,
        _max_height,
        _is_metroid
    ) {
        var _source_width = 1000;
        var _source_height = 1400;
        if (!_is_metroid
        && !is_undefined(_instance)
        && _instance.definition.type == "ship") {
            _source_width = 1400;
            _source_height = 1000;
        }
        var _scale = min(
            _max_width / _source_width,
            _max_height / _source_height
        );
        var _width = floor(_source_width * _scale);
        var _height = floor(_source_height * _scale);
        return {
            x: _x + floor((_max_width - _width) * 0.5),
            y: _y + floor((_max_height - _height) * 0.5),
            width: _width,
            height: _height
        };
    };

    var _draw_cp_row = function(_right_x, _y, _amount) {
        var _icon_size = 20;
        var _spacing = 3;
        draw_set_alpha(1);
        for (var _cp_index = 0; _cp_index < _amount; _cp_index++) {
            draw_sprite_stretched(
                sprCP,
                0,
                _right_x - ((_cp_index + 1) * (_icon_size + _spacing)),
                _y,
                _icon_size,
                _icon_size
            );
        }
    };

    var _draw_rich_text = function(
        _x,
        _y,
        _text,
        _max_width,
        _max_height,
        _line_height
    ) {
        var _cursor_x = _x;
        var _cursor_y = _y;
        var _bottom = _y + _max_height;
        var _text_index = 1;
        var _text_length = string_length(_text);
        var _icon_size = 20;

        while (_text_index <= _text_length) {
            var _remaining = string_copy(
                _text,
                _text_index,
                _text_length - _text_index + 1
            );
            if (string_copy(_remaining, 1, 2) == "@[") {
                var _close_relative = string_pos("]", _remaining);
                if (_close_relative > 0) {
                    var _token = string_copy(_remaining, 3, _close_relative - 3);
                    var _token_sprite = -1;
                    switch (_token) {
                        case "cost,1": _token_sprite = spr1; break;
                        case "cost,2": _token_sprite = spr2; break;
                        case "cost,3": _token_sprite = spr3; break;
                        case "cost,4": _token_sprite = spr4; break;
                        case "cost,5": _token_sprite = spr5; break;
                        case "ex": _token_sprite = sprEx; break;
                        case "des": _token_sprite = sprDes; break;
                    }

                    if (_token_sprite >= 0) {
                        if (_cursor_x + _icon_size > _x + _max_width) {
                            _cursor_x = _x;
                            _cursor_y += _line_height;
                            if (_cursor_y + _line_height > _bottom) {
                                draw_text(_x, _bottom - _line_height, "...");
                                return;
                            }
                        }
                        draw_sprite_stretched(
                            _token_sprite,
                            0,
                            _cursor_x,
                            _cursor_y,
                            _icon_size,
                            _icon_size
                        );
                        _cursor_x += _icon_size + 3;
                        _text_index += _close_relative;
                        continue;
                    }
                }
            }

            var _character = string_char_at(_text, _text_index);
            if (_character == "\n") {
                _cursor_x = _x;
                _cursor_y += _line_height;
                if (_cursor_y + _line_height > _bottom) {
                    draw_text(_x, _bottom - _line_height, "...");
                    return;
                }
                _text_index += 1;
            } else if (_character == "\r") {
                _text_index += 1;
            } else if (_character == " ") {
                var _space_width = string_width(" ");
                if (_cursor_x + _space_width <= _x + _max_width) {
                    _cursor_x += _space_width;
                }
                _text_index += 1;
            } else {
                var _word_end = _text_index;
                while (_word_end <= _text_length) {
                    var _word_character = string_char_at(_text, _word_end);
                    if (_word_character == " "
                    || _word_character == "\n"
                    || _word_character == "\r"
                    || (_word_end > _text_index
                    && string_copy(_text, _word_end, 2) == "@[")) {
                        break;
                    }
                    _word_end += 1;
                }
                var _word = string_copy(
                    _text,
                    _text_index,
                    _word_end - _text_index
                );
                var _word_width = string_width(_word);
                if (_cursor_x + _word_width > _x + _max_width
                && _cursor_x > _x) {
                    _cursor_x = _x;
                    _cursor_y += _line_height;
                    if (_cursor_y + _line_height > _bottom) {
                        draw_text(_x, _bottom - _line_height, "...");
                        return;
                    }
                }
                draw_text(_cursor_x, _cursor_y, _word);
                _cursor_x += _word_width;
                _text_index = _word_end;
            }
        }
    };

    var _add_hit_region = function(
        _kind,
        _index,
        _instance,
        _x,
        _y,
        _width,
        _height
    ) {
        array_push(
            ui_hit_regions,
            {
                kind: _kind,
                index: _index,
                instance: _instance,
                x1: _x,
                y1: _y,
                x2: _x + _width,
                y2: _y + _height,
                enabled: true,
                action: ""
            }
        );
    };

    var _draw_action_button = function(
        _label,
        _action,
        _x,
        _y,
        _width,
        _height,
        _enabled
    ) {
        var _camera_control = _action == "camera_center_toggle"
            || _action == "camera_lock_toggle";
        var _always_available_control = _camera_control
            || _action == "rematch"
            || _action == "back_to_menu"
            || string_pos("pause_", _action) == 1
            || string_pos("help_", _action) == 1
            || string_pos("guidance_", _action) == 1
            || string_pos("settings_", _action) == 1
            || string_pos("end_report_", _action) == 1
            || string_pos("test_", _action) == 1;
        _enabled = _enabled
            && (ui_gameplay_input_enabled || _always_available_control);
        var _hovered = ui_hover_kind == "action"
            && ui_hover_index == _action;
        var _navigation_selected = _enabled
            && ((_action == "title_select_" + title_context_mode)
                || (_action == "help_topic_"
                    + string(help_selected_index)));
        var _button_background = !_enabled
            ? make_color_rgb(36, 47, 57)
            : (_navigation_selected
                ? ui_color_title
                : (_hovered ? ui_color_selected : ui_color_panel_alt));
        var _button_foreground = !_enabled
            ? ui_color_muted
            : (_navigation_selected ? ui_color_panel_alt : ui_color_title);
        draw_set_color(
            _button_background
        );
        draw_rectangle(_x, _y, _x + _width, _y + _height, false);
        // Selection inverts only fill and text. A stable border prevents the
        // selected button from appearing to contract against its neighbors.
        draw_set_color(_enabled ? ui_color_title : ui_color_muted);
        draw_rectangle(_x, _y, _x + _width, _y + _height, true);
        draw_set_color(_button_foreground);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_font(FNT_METROID);
        var _button_text_scale = min(
            1,
            (_width - 12) / max(1, string_width(_label)),
            (_height - 8) / max(1, string_height(_label))
        );
        if (_button_text_scale >= 0.999) {
            draw_text(
                _x + (_width * 0.5),
                _y + (_height * 0.5),
                _label
            );
        } else {
            draw_text_transformed(
                _x + (_width * 0.5),
                _y + (_height * 0.5),
                _label,
                _button_text_scale,
                _button_text_scale,
                0
            );
        }
        draw_set_font(-1);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);

        array_push(
            ui_hit_regions,
            {
                kind: "action",
                index: _action,
                instance: undefined,
                x1: _x,
                y1: _y,
                x2: _x + _width,
                y2: _y + _height,
                enabled: _enabled,
                action: _action,
                context_kind: context_button_source_kind,
                context_index: context_button_source_index
            }
        );
    };

    _draw_live_stat_badge = function(
        _instance,
        _draw_x,
        _draw_y,
        _width,
        _height,
        _always_show
    ) {
        if (is_undefined(_instance)) {
            return;
        }
        var _definition = _instance.definition;
        var _has_live_stat = variable_struct_exists(_definition, "stat")
            && !is_undefined(_definition.stat)
            && variable_struct_exists(_definition.stat, "value")
            && !is_undefined(_definition.stat.value);
        if (!_has_live_stat) {
            return;
        }
        var _printed_stat = _definition.stat.value;
        var _current_stat = get_card_stat(_instance);
        if ((!is_undefined(_always_show) && !_always_show)
        && is_real(_printed_stat)
        && _current_stat == _printed_stat) {
            return;
        }
        var _live_stat_radius = clamp(floor(_width * 0.11), 7, 18);
        var _live_stat_x = _draw_x + _live_stat_radius + 4;
        var _live_stat_y = _draw_y + _height - _live_stat_radius - 4;
        draw_set_alpha(0.86);
        draw_set_color(c_black);
        draw_circle(
            _live_stat_x,
            _live_stat_y,
            _live_stat_radius,
            false
        );
        draw_set_alpha(1);
        draw_set_color(ui_color_selected);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_text(_live_stat_x, _live_stat_y, string(_current_stat));
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
    };

    var _draw_card = function(
        _instance,
        _x,
        _y,
        _max_width,
        _max_height,
        _rotate_ship,
        _always_show_stat
    ) {
        if (is_undefined(_instance)) {
            draw_set_color(ui_color_line);
            draw_rectangle(
                _x,
                _y,
                _x + _max_width,
                _y + _max_height,
                true
            );
            return;
        }

        var _definition = _instance.definition;
        var _is_ship = variable_struct_exists(_definition, "type")
            && _definition.type == "ship";
        var _is_rotated_ship = _is_ship
            && !is_undefined(_rotate_ship)
            && _rotate_ship;
        var _sprite = get_definition_sprite(_definition, false);
        var _target_angle = _is_rotated_ship ? 90 : 0;
        if (_is_ship) {
            if (!_instance.ui_angle_initialized) {
                _instance.ui_angle = _target_angle;
                _instance.ui_angle_initialized = true;
            }
            _instance.ui_angle = lerp(
                _instance.ui_angle,
                _target_angle,
                0.18
            );
            if (abs(_instance.ui_angle - _target_angle) < 0.25) {
                _instance.ui_angle = _target_angle;
            }
        }
        var _draw_angle = _is_ship ? _instance.ui_angle : 0;
        var _source_width = _is_ship
            ? (_sprite >= 0 ? sprite_get_width(_sprite) : 1400)
            : 1000;
        var _source_height = _is_ship
            ? (_sprite >= 0 ? sprite_get_height(_sprite) : 1000)
            : 1400;
        var _angle_cos = abs(dcos(_draw_angle));
        var _angle_sin = abs(dsin(_draw_angle));
        var _rotated_source_width = _is_ship
            ? (_source_width * _angle_cos) + (_source_height * _angle_sin)
            : _source_width;
        var _rotated_source_height = _is_ship
            ? (_source_width * _angle_sin) + (_source_height * _angle_cos)
            : _source_height;
        var _scale = min(
            _max_width / _rotated_source_width,
            _max_height / _rotated_source_height
        );
        var _width = floor(_rotated_source_width * _scale);
        var _height = floor(_rotated_source_height * _scale);
        var _draw_x = _x + floor((_max_width - _width) * 0.5);
        var _draw_y = _y + floor((_max_height - _height) * 0.5);

        draw_set_color(ui_color_panel_alt);
        draw_rectangle(
            _draw_x,
            _draw_y,
            _draw_x + _width,
            _draw_y + _height,
            false
        );

        if (_sprite >= 0 && _is_ship) {
            var _card_center_x = _x + (_max_width * 0.5);
            var _card_center_y = _y + (_max_height * 0.5);
            var _half_source_w = _source_width * _scale * 0.5;
            var _half_source_h = _source_height * _scale * 0.5;
            var _corner_cos = dcos(_draw_angle);
            var _corner_sin = dsin(_draw_angle);
            var _corner_x1 = _card_center_x
                + (-_half_source_w * _corner_cos)
                - (-_half_source_h * _corner_sin);
            var _corner_y1 = _card_center_y
                + (-_half_source_w * _corner_sin)
                + (-_half_source_h * _corner_cos);
            var _corner_x2 = _card_center_x
                + (_half_source_w * _corner_cos)
                - (-_half_source_h * _corner_sin);
            var _corner_y2 = _card_center_y
                + (_half_source_w * _corner_sin)
                + (-_half_source_h * _corner_cos);
            var _corner_x3 = _card_center_x
                + (_half_source_w * _corner_cos)
                - (_half_source_h * _corner_sin);
            var _corner_y3 = _card_center_y
                + (_half_source_w * _corner_sin)
                + (_half_source_h * _corner_cos);
            var _corner_x4 = _card_center_x
                + (-_half_source_w * _corner_cos)
                - (_half_source_h * _corner_sin);
            var _corner_y4 = _card_center_y
                + (-_half_source_w * _corner_sin)
                + (_half_source_h * _corner_cos);
            draw_sprite_pos(
                _sprite,
                0,
                _corner_x1,
                _corner_y1,
                _corner_x2,
                _corner_y2,
                _corner_x3,
                _corner_y3,
                _corner_x4,
                _corner_y4,
                1
            );
        } else if (_sprite >= 0) {
            draw_sprite_stretched(
                _sprite,
                0,
                _draw_x,
                _draw_y,
                _width,
                _height
            );
        } else {
            draw_set_color(ui_color_error);
            draw_rectangle(
                _draw_x,
                _draw_y,
                _draw_x + _width,
                _draw_y + _height,
                true
            );
        }

        if (!_instance.ready && _instance.zone != "attachment") {
            draw_set_alpha(0.48);
            draw_set_color(c_black);
            draw_rectangle(
                _draw_x,
                _draw_y,
                _draw_x + _width,
                _draw_y + _height,
                false
            );
            draw_set_alpha(1);
            draw_set_color(ui_color_muted);
            draw_text(_draw_x + 5, _draw_y + 5, "EXHAUSTED");
        }

        if (_instance.phazon_tokens > _instance.ui_last_phazon_tokens) {
            _instance.ui_phazon_flash_started_ms = current_time;
        }
        _instance.ui_last_phazon_tokens = _instance.phazon_tokens;
        if (_instance.ui_phazon_flash_started_ms >= 0) {
            var _phazon_flash_duration = 680;
            var _phazon_flash_t = (
                current_time - _instance.ui_phazon_flash_started_ms
            ) / _phazon_flash_duration;
            if (_phazon_flash_t < 1) {
                // Two positive blue pulses. The token icons are drawn afterward
                // and therefore remain crisp above the flash.
                var _phazon_flash_alpha = max(
                    0,
                    dsin(_phazon_flash_t * 720)
                ) * 0.48;
                draw_set_alpha(_phazon_flash_alpha);
                draw_set_color(make_color_rgb(46, 137, 255));
                draw_rectangle(
                    _draw_x,
                    _draw_y,
                    _draw_x + _width,
                    _draw_y + _height,
                    false
                );
                draw_set_alpha(1);
            } else {
                _instance.ui_phazon_flash_started_ms = -1;
            }
        }

        if (_instance.phazon_tokens > 0) {
            var _pz_gap = 2;
            var _pz_size = min(
                18,
                max(
                    5,
                    floor(
                        (_width - 8 - ((_instance.phazon_tokens - 1) * _pz_gap))
                        / _instance.phazon_tokens
                    )
                )
            );
            var _pz_y = _draw_y + _height - _pz_size - 4;
            for (var _pz_index = 0;
                 _pz_index < _instance.phazon_tokens;
                 _pz_index++) {
                draw_sprite_stretched(
                    sprPZ,
                    0,
                    _draw_x + _width - 4
                        - ((_pz_index + 1) * _pz_size)
                        - (_pz_index * _pz_gap),
                    _pz_y,
                    _pz_size,
                    _pz_size
                );
            }
        }

        _draw_live_stat_badge(
            _instance,
            _draw_x,
            _draw_y,
            _width,
            _height,
            !is_undefined(_always_show_stat) && _always_show_stat
        );
    };

    var _draw_dealt_card_back = function(_x, _y, _max_width, _max_height) {
        var _back_sprite = get_card_back_sprite();
        if (_back_sprite < 0) {
            draw_set_color(ui_color_panel_alt);
            draw_rectangle(
                _x,
                _y,
                _x + _max_width,
                _y + _max_height,
                false
            );
            return;
        }
        var _back_source_w = sprite_get_width(_back_sprite);
        var _back_source_h = sprite_get_height(_back_sprite);
        var _back_scale = min(
            _max_width / _back_source_w,
            _max_height / _back_source_h
        );
        var _back_width = floor(_back_source_w * _back_scale);
        var _back_height = floor(_back_source_h * _back_scale);
        draw_sprite_stretched(
            _back_sprite,
            0,
            _x + floor((_max_width - _back_width) * 0.5),
            _y + floor((_max_height - _back_height) * 0.5),
            _back_width,
            _back_height
        );
    };

    var _draw_metroid = function(_instance, _x, _y, _width, _height) {
        if (is_undefined(_instance)) {
            draw_set_color(ui_color_line);
            draw_rectangle(_x, _y, _x + _width, _y + _height, true);
            draw_set_color(ui_color_muted);
            draw_set_halign(fa_center);
            draw_text(_x + (_width * 0.5), _y + (_height * 0.4), "EMPTY");
            draw_set_halign(fa_left);
            return;
        }

        var _scale = min(_width / 1000, _height / 1400);
        var _draw_width = floor(1000 * _scale);
        var _draw_height = floor(1400 * _scale);
        var _draw_x = _x + floor((_width - _draw_width) * 0.5);
        var _draw_y = _y + floor((_height - _draw_height) * 0.5);
        var _evolution_t = 1;
        var _evolution_definition = _instance.definition;
        if (_instance.evolution_started_ms >= 0) {
            _evolution_t = clamp(
                (current_time - _instance.evolution_started_ms)
                    / max(1, _instance.evolution_duration_ms),
                0,
                1
            );
            if (_evolution_t < 0.5
            && !is_undefined(_instance.evolution_old_definition)) {
                _evolution_definition = _instance.evolution_old_definition;
            }
        }
        var _sprite = get_definition_sprite(_evolution_definition, true);
        if (_sprite >= 0) {
            draw_sprite_stretched(
                _sprite,
                0,
                _draw_x,
                _draw_y,
                _draw_width,
                _draw_height
            );
        } else {
            draw_set_color(ui_color_error);
            draw_rectangle(
                _draw_x,
                _draw_y,
                _draw_x + _draw_width,
                _draw_y + _draw_height,
                true
            );
        }
        if (_evolution_t < 1) {
            var _white_alpha = _evolution_t < 0.44
                ? _evolution_t / 0.44
                : (_evolution_t < 0.56
                    ? 1
                    : 1 - ((_evolution_t - 0.56) / 0.44));
            draw_set_alpha(clamp(_white_alpha, 0, 1));
            draw_set_color(c_white);
            draw_rectangle(
                _draw_x,
                _draw_y,
                _draw_x + _draw_width,
                _draw_y + _draw_height,
                false
            );
            draw_set_alpha(1);
        }
    };

    // World-space composition remains fixed at its authored 1080p dimensions.
    // Only the viewport and screen-space HUD respond to native window size.
    var _margin = 19;
    var _gap = 10;
    var _header_h = 48;
    var _log_w = ui_hud_width;
    var _main_left = _margin;
    var _main_right = board_layout_width;
    var _log_left = _screen_width - _margin - _log_w;
    board_viewport_right = _log_left - _gap;
    var _content_top = _header_h + 8;
    var _content_bottom = board_layout_height - _margin;
    var _shared_h = floor(board_layout_height * 0.22);
    // Preserve the original local framing, then extend the opponent surface above
    // the center strip so both players receive the same amount of world space.
    var _shared_top = _content_top + floor(board_layout_height * 0.17) + _gap;
    var _shared_bottom = _shared_top + _shared_h;
    var _board_top = _shared_bottom + _gap;
    var _board_bottom = _content_bottom;
    var _board_h = _board_bottom - _board_top;
    var _opponent_bottom = _shared_top - _gap;
    var _opponent_top = _opponent_bottom - _board_h;
    // The planet is the centerpiece of the whole playable world, not merely the
    // remainder left beside the Shop.
    var _sr_planet_x = (_main_left + _main_right) * 0.5;
    var _sr_planet_y = (_shared_top + _shared_bottom) * 0.5;
    // Four surface cards define the planet's footprint. The Cavern is rendered as
    // a separate sensor contact outside this circle.
    var _sr_planet_diameter = clamp(
        (_main_right - _main_left) * 0.52,
        680,
        900
    );
    var _sr_left = _sr_planet_x - (_sr_planet_diameter * 0.5);
    var _sr_right = _sr_planet_x + (_sr_planet_diameter * 0.5);
    // Temporary compact Shop placement: keep its panel wholly left of SR388 until
    // the Shop receives its own final board treatment.
    var _shop_right = max(
        _main_left + 330,
        floor(_sr_left - 18)
    );
    board_camera_world_width = _main_right;
    board_camera_world_top = _opponent_top;
    board_camera_world_bottom = _board_bottom + _margin;

    var _active_player = game_state.players[game_state.view_player];
    var _opponent = game_state.players[1 - game_state.view_player];

    // The fixed HUD is one continuous ship-console surface. Its internal regions
    // are separated by typography and restrained rules rather than nested panels.
    draw_set_alpha(1);
    draw_set_color(ui_color_hud_surface);
    draw_rectangle(_log_left, 0, _screen_width, _screen_height, false);
    draw_set_color(ui_color_hud_line);
    draw_line(_log_left, 0, _log_left, _screen_height);

    draw_set_color(ui_color_header);
    draw_rectangle(0, 0, _log_left, _header_h, false);
    draw_set_color(ui_color_title);
    draw_set_font(FNT_METROID);
    draw_text(_margin, 13, "LEGACY OF THE CHOZO - RULES ENGINE");
    draw_set_font(-1);
    draw_set_halign(fa_center);
    draw_set_color(ui_color_text);
    draw_text(
        _screen_width * 0.5,
        13,
        "TURN " + string(game_state.turn_number)
        + "  |  " + string_upper(game_state.phase)
        + "  |  " + game_state.players[game_state.active_player].name
        + (game_state.final_round_active ? "  |  FINAL ROUND" : "")
        + (game_state.priority_player != game_state.active_player
            ? "  |  PRIORITY: "
                + game_state.players[game_state.priority_player].name
            : "")
        + ((game_state.game_mode == "ai"
            || game_state.game_mode == "ai_watch")
            && game_state.players[game_state.active_player].is_ai
            && ai_last_action != ""
                ? "  |  AI: " + ai_last_action
                : "")
    );
    draw_set_halign(fa_right);
    draw_set_color(load_complete ? ui_color_success : ui_color_error);
    draw_text(
        _log_left - 12,
        13,
        load_complete ? "STATE OK" : "STATE ERROR"
    );
    draw_set_halign(fa_left);

    var _watch_header = game_state.game_mode == "ai_watch";
    var _header_control_x = _log_left;
    if (settings_debug_mode) {
        _draw_action_button("TEST TOOLS", "test_open", _header_control_x, 8,
            _watch_header ? 88 : 104, 32, is_undefined(pending_choice));
        _header_control_x += _watch_header ? 94 : 110;
    }
    if (_watch_header && settings_debug_mode) {
        _draw_action_button("SIM", "test_game_over", _log_left + 94, 8,
            48, 32, game_state.phase != "game_over");
        _header_control_x = _log_left + 148;
    }
    _draw_action_button(
        board_camera_center_far ? "CENTER: FAR" : "CENTER: CLOSE",
        "camera_center_toggle",
        _header_control_x,
        8,
        _watch_header ? 100 : 120,
        32,
        true
    );
    _draw_action_button(
        board_camera_locked ? "CAMERA: LOCKED" : "CAMERA: FREE",
        "camera_lock_toggle",
        _header_control_x + (_watch_header ? 106 : 126),
        8,
        _watch_header ? 98 : 116,
        32,
        true
    );

    // Everything from the opponent surface through the local hand belongs to the
    // fixed board world. The dashboard and modal overlays drawn afterward remain
    // in screen space.
    var _world_hit_region_start = array_length(ui_hit_regions);
    var _world_matrix_before = matrix_get(matrix_world);
    var _board_camera_matrix = matrix_build(
        -board_camera_x * board_camera_zoom,
        board_viewport_top - (board_camera_y * board_camera_zoom),
        0,
        0,
        0,
        0,
        board_camera_zoom,
        board_camera_zoom,
        1
    );
    matrix_set(matrix_world, _board_camera_matrix);
    gpu_set_scissor(
        0,
        board_viewport_top,
        board_viewport_right,
        max(1, _screen_height - board_viewport_top)
    );

    // SR388 is part of the table surface rather than another UI panel. Draw it
    // before either player's cards so the planet can cross both play surfaces
    // without obscuring anything placed on them.
    if (sprite_exists(sprSR388)) {
        var _sr_planet_scale = _sr_planet_diameter
            / max(1, sprite_get_width(sprSR388));
        draw_sprite_ext(
            sprSR388,
            0,
            _sr_planet_x,
            _sr_planet_y,
            _sr_planet_scale,
            _sr_planet_scale,
            0,
            c_white,
            1
        );
    }

    // Opponent: public board information only. Their hand remains hidden.
    // Like the local play surface, this is raw space rather than a filled panel.
    var _opponent_permanents = [];
    var _opponent_permanent_kinds = [];
    var _opponent_permanent_indices = [];
    var _opponent_sources = [
        _opponent.board.ships,
        _opponent.board.characters,
        _opponent.board.locations
    ];
    var _opponent_source_kinds = [
        "opponent_ship",
        "opponent_character",
        "opponent_location"
    ];
    for (var _opponent_source_index = 0;
         _opponent_source_index < 3;
         _opponent_source_index++) {
        for (var _opponent_source_card_index = 0;
             _opponent_source_card_index
                < array_length(_opponent_sources[_opponent_source_index]);
             _opponent_source_card_index++) {
            array_push(
                _opponent_permanents,
                _opponent_sources[_opponent_source_index][
                    _opponent_source_card_index
                ]
            );
            array_push(
                _opponent_permanent_kinds,
                _opponent_source_kinds[_opponent_source_index]
            );
            array_push(
                _opponent_permanent_indices,
                _opponent_source_card_index
            );
        }
    }
    var _opponent_zone_names = [
        "",
        "",
        "",
        "LAB"
    ];
    var _opponent_zone_cards = [
        _opponent_permanents,
        [],
        [],
        []
    ];
    var _opponent_lab_lane_x = _main_left
        + floor((_main_right - _main_left) * 0.86);
    var _opponent_play_left = _main_left + 16;
    var _opponent_play_right = _main_right - 16;
    var _opponent_permanent_w = _opponent_play_right - _opponent_play_left;
    var _opponent_lab_w = _main_right - 12 - _opponent_lab_lane_x;
    var _opponent_layout_rects = [];
    var _opponent_play_top = _opponent_top + 54;
    var _opponent_play_bottom = _opponent_bottom - 38;
    var _opponent_location_left = _main_left + 12;
    // Locations float on their own side layer. They no longer reserve horizontal
    // space from the combat formation centered on SR388.
    var _opponent_main_play_left = _opponent_play_left;
    for (var _opponent_layout_zone = 0;
         _opponent_layout_zone < 3;
         _opponent_layout_zone++) {
        var _opponent_layout_cards = _opponent_sources[_opponent_layout_zone];
        var _opponent_layout_count = array_length(_opponent_layout_cards);
        var _opponent_layout_w = _opponent_layout_zone == 0
            ? 184
            : (_opponent_layout_zone == 1 ? 116 : 104);
        var _opponent_layout_h = _opponent_layout_zone == 0
            ? 132
            : (_opponent_layout_zone == 1 ? 162 : 146);
        var _opponent_layout_start_x = _opponent_main_play_left;
        var _opponent_layout_start_y = _opponent_play_top;
        var _opponent_layout_step = 0;
        if (_opponent_layout_zone < 2) {
            var _opponent_row_left = _opponent_main_play_left;
            var _opponent_row_right = _opponent_play_right;
            var _opponent_row_available = max(
                1,
                _opponent_row_right - _opponent_row_left
            );
            _opponent_layout_step = _opponent_layout_count <= 1
                ? 0
                : min(
                    _opponent_layout_w + 10,
                    (_opponent_row_available - _opponent_layout_w)
                        / max(1, _opponent_layout_count - 1)
                );
            var _opponent_layout_row_w = _opponent_layout_w
                + (_opponent_layout_step
                    * max(0, _opponent_layout_count - 1));
            _opponent_layout_start_x = _opponent_row_left
                + ((_opponent_row_available - _opponent_layout_row_w) * 0.5);
            _opponent_layout_start_y = _opponent_layout_zone == 0
                ? _opponent_play_bottom - _opponent_layout_h - 8
                : _opponent_play_top + 8;
        } else {
            _opponent_layout_start_x = _opponent_location_left;
            _opponent_layout_start_y = (
                _opponent_play_top + _opponent_play_bottom
            ) * 0.5;
        }
        for (var _opponent_layout_index = 0;
             _opponent_layout_index < _opponent_layout_count;
             _opponent_layout_index++) {
            var _opponent_center_index =
                (_opponent_layout_count - 1) * 0.5;
            var _opponent_arc = _opponent_layout_zone < 2
                ? abs(_opponent_layout_index - _opponent_center_index) * 3
                : 0;
            var _opponent_location_position = _opponent_layout_zone == 2
                ? _get_location_cluster_position(
                    _opponent_layout_index,
                    _opponent_layout_count,
                    _opponent_layout_w,
                    _opponent_layout_h,
                    _opponent_play_left,
                    _opponent_play_right,
                    (_opponent_play_top + _opponent_play_bottom) * 0.5,
                    false,
                    true
                )
                : {x: _opponent_layout_start_x, y: _opponent_layout_start_y};
            array_push(_opponent_layout_rects, {
                x: _opponent_layout_zone == 2
                    ? _opponent_location_position.x
                    : _opponent_layout_start_x
                        + (_opponent_layout_index * _opponent_layout_step),
                y: _opponent_layout_zone == 2
                    ? _opponent_location_position.y
                    : _opponent_layout_start_y - _opponent_arc,
                width: _opponent_layout_w,
                height: _opponent_layout_h
            });
        }
    }
    for (var _opponent_zone_index = 0;
         _opponent_zone_index < 4;
         _opponent_zone_index++) {
        if (_opponent_zone_index == 1 || _opponent_zone_index == 2) {
            continue;
        }
        var _opponent_zone_w = _opponent_zone_index == 0
            ? _opponent_permanent_w
            : _opponent_lab_w;
        var _opponent_zone_x = _opponent_zone_index == 0
            ? _main_left + 5
            : _main_left + 5 + _opponent_permanent_w;
        var _opponent_visible = array_length(
            _opponent_zone_cards[_opponent_zone_index]
        );
        var _opponent_slot_w = 0;
        for (var _opponent_card_index = 0;
             _opponent_card_index < _opponent_visible;
             _opponent_card_index++) {
            var _opponent_card = _opponent_zone_cards[
                _opponent_zone_index
            ][_opponent_card_index];
            var _opponent_kind = _opponent_zone_index == 3
                ? "opponent_lab"
                : _opponent_permanent_kinds[_opponent_card_index];
            var _opponent_logical_index = _opponent_zone_index == 3
                ? _opponent_card_index
                : _opponent_permanent_indices[_opponent_card_index];
            var _opponent_rect =
                _opponent_layout_rects[_opponent_card_index];
            var _opponent_card_h = _opponent_rect.height;
            _opponent_slot_w = _opponent_rect.width;
            var _opponent_target_x = _opponent_rect.x;
            var _opponent_target_y = _opponent_rect.y;
            var _opponent_position = _get_lerped_board_position(
                _opponent_card,
                _opponent_target_x,
                _opponent_target_y,
                _opponent_target_x,
                _opponent_target_y,
                "opponent_board",
                0
            );
            var _opponent_card_x = _opponent_position.x;
            var _opponent_card_y = _opponent_position.y;
            if (_opponent_zone_index == 3) {
                _draw_metroid(
                    _opponent_card,
                    _opponent_card_x,
                    _opponent_card_y,
                    _opponent_slot_w,
                    _opponent_card_h
                );
            } else {
                _draw_card(
                    _opponent_card,
                    _opponent_card_x,
                    _opponent_card_y,
                    _opponent_slot_w,
                    _opponent_card_h,
                    false,
                    true
                );
            }
            var _opponent_bounds = _get_card_bounds(
                _opponent_card,
                _opponent_card_x,
                _opponent_card_y,
                _opponent_slot_w,
                _opponent_card_h,
                _opponent_zone_index == 3
            );
            if (_opponent_zone_index != 3
            && _card_has_usable_ability(
                _opponent_kind,
                _opponent_logical_index,
                _opponent_card
            )) {
                _draw_playability_line(
                    _opponent_bounds.x,
                    _opponent_bounds.y,
                    _opponent_bounds.width,
                    0,
                    1
                );
            }
            _add_hit_region(
                _opponent_kind,
                _opponent_logical_index,
                _opponent_card,
                _opponent_bounds.x,
                _opponent_bounds.y,
                _opponent_bounds.width,
                _opponent_bounds.height
            );
            if ((ui_selected_kind == _opponent_kind
            && ui_selected_index == _opponent_logical_index)
            || (ui_hover_kind == _opponent_kind
            && ui_hover_index == _opponent_logical_index)) {
                _draw_selection(
                    _opponent_bounds.x,
                    _opponent_bounds.y,
                    _opponent_bounds.width,
                    _opponent_bounds.height,
                    ui_selected_kind == _opponent_kind
                    && ui_selected_index == _opponent_logical_index
                );
            }
            if (!is_undefined(pending_choice)
            && (pending_choice.kind == "ability_target"
                && can_resolve_ability_target(
                    pending_choice,
                    _opponent_kind,
                    _opponent_logical_index
                )
                || pending_choice.kind == "space_pirate_ready"
                && pending_choice.owner_index != game_state.active_player
                && _opponent_kind == "opponent_character"
                && !_opponent_card.ready
                && card_has_faction(_opponent_card, "SP")
                || pending_choice.kind == "breach_character"
                && pending_choice.player_index != game_state.active_player
                && _opponent_kind == "opponent_character"
                || pending_choice.kind == "olympus_ready"
                && pending_choice.player_index != game_state.active_player
                && _opponent_kind == "opponent_character"
                && !_opponent_card.ready
                && card_has_faction(_opponent_card, "GF"))) {
                draw_set_color(ui_color_success);
                draw_rectangle(
                    _opponent_bounds.x - 3,
                    _opponent_bounds.y - 3,
                    _opponent_bounds.x + _opponent_bounds.width + 3,
                    _opponent_bounds.y + _opponent_bounds.height + 3,
                    true
                );
            }
            if (!is_undefined(pending_choice)
            && pending_choice.kind == "raid") {
                var _opponent_raid_target = pending_choice.stage == "target"
                    && _opponent_kind == "opponent_ship";
                var _opponent_raid_character = false;
                var _opponent_raid_ability =
                    _opponent_card.controller == game_state.priority_player
                    && _opponent_kind != "opponent_lab"
                    && pending_choice.stage != "target";
                if (_opponent_raid_target
                || _opponent_raid_character
                || _opponent_raid_ability) {
                    var _opponent_raid_selected = _opponent_raid_character
                        && raid_array_contains(
                            pending_choice.stage == "attackers"
                                ? pending_choice.attacker_characters
                                : pending_choice.defender_characters,
                            _opponent_logical_index
                        );
                    _opponent_raid_selected = _opponent_raid_selected
                        || (_opponent_raid_ability
                        && pending_choice.ability_source_kind
                            == get_raid_source_kind(
                                _opponent_kind,
                                _opponent_card
                            )
                        && pending_choice.ability_source_index
                            == _opponent_logical_index);
                    draw_set_color(
                        _opponent_raid_selected
                            ? ui_color_selected
                            : ui_color_success
                    );
                    draw_rectangle(
                        _opponent_bounds.x - 3,
                        _opponent_bounds.y - 3,
                        _opponent_bounds.x + _opponent_bounds.width + 3,
                        _opponent_bounds.y + _opponent_bounds.height + 3,
                        true
                    );
                }
            }
            if (_opponent_kind == "opponent_ship") {
                var _opponent_cargo_w = 24;
                var _opponent_cargo_h = 34;
                _opponent_card.ui_cargo_anchor_x = _opponent_bounds.x
                    + _opponent_bounds.width - _opponent_cargo_w;
                _opponent_card.ui_cargo_anchor_y = _opponent_bounds.y
                    + _opponent_bounds.height - _opponent_cargo_h;
                for (var _opponent_cargo_index = 0;
                     _opponent_cargo_index < array_length(_opponent_card.cargo);
                     _opponent_cargo_index++) {
                    var _opponent_cargo =
                        _opponent_card.cargo[_opponent_cargo_index];
                    if (current_time < _opponent_cargo.ui_cargo_arrival_ms) {
                        continue;
                    }
                    var _opponent_cargo_x =
                        _opponent_card.ui_cargo_anchor_x
                        - (_opponent_cargo_index * 18);
                    var _opponent_cargo_y =
                        _opponent_card.ui_cargo_anchor_y;
                    var _opponent_cargo_position =
                    _get_lerped_board_position(
                        _opponent_cargo,
                        _opponent_cargo_x,
                        _opponent_cargo_y,
                        _opponent_cargo_x,
                        _opponent_cargo_y,
                        "opponent_cargo",
                        0
                    );
                    _opponent_cargo_x = _opponent_cargo_position.x;
                    _opponent_cargo_y = _opponent_cargo_position.y;
                    _draw_metroid(
                        _opponent_cargo,
                        _opponent_cargo_x,
                        _opponent_cargo_y,
                        _opponent_cargo_w,
                        _opponent_cargo_h
                    );
                    _add_hit_region(
                        "opponent_cargo",
                        _opponent_logical_index,
                        _opponent_cargo,
                        _opponent_cargo_x,
                        _opponent_cargo_y,
                        _opponent_cargo_w,
                        _opponent_cargo_h
                    );
                }
            }
            var _opponent_attachment_count = min(
                2,
                _opponent_kind != "opponent_lab"
                    ? array_length(_opponent_card.attachments)
                    : 0
            );
            for (var _opponent_attachment_index = 0;
                 _opponent_attachment_index < _opponent_attachment_count;
                 _opponent_attachment_index++) {
                var _opponent_attachment =
                    _opponent_card.attachments[_opponent_attachment_index];
                var _opponent_attachment_x = _opponent_card_x
                    + (_opponent_attachment_index * 22);
                var _opponent_attachment_y = _opponent_card_y
                    + _opponent_card_h - 32;
                var _opponent_attachment_position =
                    _get_lerped_board_position(
                        _opponent_attachment,
                        _opponent_attachment_x,
                        _opponent_attachment_y,
                        _opponent_attachment_x,
                        _opponent_attachment_y,
                        "opponent_attachment",
                        60
                    );
                _opponent_attachment_x = _opponent_attachment_position.x;
                _opponent_attachment_y = _opponent_attachment_position.y;
                _draw_card(
                    _opponent_attachment,
                    _opponent_attachment_x,
                    _opponent_attachment_y,
                    20,
                    29,
                    false,
                    true
                );
                _add_hit_region(
                    "opponent_attachment",
                    _opponent_attachment.instance_id,
                    _opponent_attachment,
                    _opponent_attachment_x,
                    _opponent_attachment_y,
                    20,
                    29
                );
                if (!is_undefined(pending_choice)
                && pending_choice.kind == "ability_target"
                && can_resolve_ability_target(
                    pending_choice,
                    "opponent_attachment",
                    _opponent_attachment.instance_id
                )) {
                    draw_set_color(ui_color_success);
                    draw_rectangle(
                        _opponent_attachment_x - 2,
                        _opponent_attachment_y - 2,
                        _opponent_attachment_x + 22,
                        _opponent_attachment_y + 31,
                        true
                    );
                }
            }
            if (_opponent_attachment_count > 0) {
                _draw_live_stat_badge(
                    _opponent_card,
                    _opponent_bounds.x,
                    _opponent_bounds.y,
                    _opponent_bounds.width,
                    _opponent_bounds.height,
                    true
                );
            }
        }
    }

    // Public opponent piles are the 180-degree counterpart of the local piles:
    // deck at the upper-right outer edge, with discard immediately below it.
    var _pile_reference_play_top = _board_top + 38;
    var _pile_reference_play_bottom = _board_bottom - 54;
    var _pile_reference_height =
        _pile_reference_play_bottom - _pile_reference_play_top;
    var _pile_reference_character_top = _pile_reference_play_top
        + floor(_pile_reference_height * 0.40) + 10;
    var _opponent_pile_h = floor(
        (_pile_reference_play_bottom
            - _pile_reference_character_top - 8) * 0.5
    );
    var _opponent_pile_w = floor(_opponent_pile_h * (1000 / 1400));
    var _opponent_pile_x = _main_right - 10 - _opponent_pile_w;
    var _opponent_deck_y = _opponent_top + 5;
    var _opponent_discard_x = _opponent_pile_x;
    var _opponent_discard_y = _opponent_deck_y + _opponent_pile_h + 8;
    var _opponent_discard_target_x = _opponent_discard_x;
    var _opponent_discard_target_y = _opponent_discard_y;
    var _opponent_card_back = get_card_back_sprite();
    if (_opponent_card_back >= 0) {
        draw_sprite_stretched(
            _opponent_card_back,
            0,
            _opponent_pile_x,
            _opponent_deck_y,
            _opponent_pile_w,
            _opponent_pile_h
        );
    }
    draw_set_alpha(0.68);
    draw_set_color(c_black);
    draw_circle(
        _opponent_pile_x + (_opponent_pile_w * 0.5),
        _opponent_deck_y + (_opponent_pile_h * 0.5),
        14,
        false
    );
    draw_set_alpha(1);
    draw_set_color(c_white);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text(
        _opponent_pile_x + (_opponent_pile_w * 0.5),
        _opponent_deck_y + (_opponent_pile_h * 0.5),
        string(array_length(_opponent.deck))
    );
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    _add_hit_region(
        "opponent_deck",
        0,
        undefined,
        _opponent_pile_x,
        _opponent_deck_y,
        _opponent_pile_w,
        _opponent_pile_h
    );
    var _opponent_discard_count = array_length(_opponent.discard);
    var _opponent_discard_display_index = _opponent_discard_count - 1;
    if (_opponent_discard_display_index >= 0
    && current_time < _opponent.discard[
        _opponent_discard_display_index
    ].ui_hide_until_ms) {
        _opponent_discard_display_index -= 1;
    }
    if (_opponent_discard_display_index >= 0) {
        var _opponent_latest_discard =
            _opponent.discard[_opponent_discard_display_index];
        if (_opponent_latest_discard.ui_hide_until_ms > 0) {
            _opponent_latest_discard.ui_x = _opponent_discard_target_x;
            _opponent_latest_discard.ui_y = _opponent_discard_target_y;
            _opponent_latest_discard.ui_zone = "opponent_discard";
            _opponent_latest_discard.ui_move_after_ms = 0;
            _opponent_latest_discard.ui_hide_until_ms = 0;
        }
        var _opponent_discard_position = _get_lerped_board_position(
            _opponent_latest_discard,
            _opponent_discard_x,
            _opponent_discard_y,
            _opponent_pile_x,
            _opponent_deck_y,
            "opponent_discard",
            90
        );
        _opponent_discard_x = _opponent_discard_position.x;
        _opponent_discard_y = _opponent_discard_position.y;
        _draw_card(
            _opponent_latest_discard,
            _opponent_discard_x,
            _opponent_discard_y,
            _opponent_pile_w,
            _opponent_pile_h,
            true
        );
        draw_set_alpha(0.52);
        draw_set_color(c_black);
        draw_rectangle(
            _opponent_discard_x,
            _opponent_discard_y,
            _opponent_discard_x + _opponent_pile_w,
            _opponent_discard_y + _opponent_pile_h,
            false
        );
        draw_set_alpha(1);
        _add_hit_region(
            "opponent_discard",
            _opponent_discard_display_index,
            _opponent_latest_discard,
            _opponent_discard_x,
            _opponent_discard_y,
            _opponent_pile_w,
            _opponent_pile_h
        );
    } else {
        draw_set_color(ui_color_line);
        draw_rectangle(
            _opponent_discard_x,
            _opponent_discard_y,
            _opponent_discard_x + _opponent_pile_w,
            _opponent_discard_y + _opponent_pile_h,
            true
        );
    }
    if (ui_hover_kind == "opponent_discard") {
        draw_set_color(ui_color_text);
        draw_set_halign(fa_center);
        draw_set_valign(fa_bottom);
        draw_text(
            _opponent_discard_target_x + (_opponent_pile_w * 0.5),
            _opponent_discard_target_y - 3,
            string(_opponent_discard_count) + " cards"
        );
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
    }

    // The opponent's Lab mirrors the active player's drawer from the top edge.
    var _opponent_lab_strength = get_ready_character_strength(_opponent);
    var _opponent_lab_hazard = get_lab_hazard(_opponent);
    var _preview_opponent_containment_ship =
        game_state.phase == "containment"
        && game_state.active_player == 1 - game_state.view_player
        || !is_undefined(pending_choice)
            && pending_choice.kind == "special_containment_ship"
            && pending_choice.player_index == 1 - game_state.view_player;
    if (_preview_opponent_containment_ship
    && ui_selected_kind == "opponent_ship"
    && ui_selected_index >= 0
    && ui_selected_index < array_length(_opponent.board.ships)
    && _opponent.board.ships[ui_selected_index].ready) {
        _opponent_lab_strength += get_card_stat(
            _opponent.board.ships[ui_selected_index],
            "containment_ship"
        );
    }
    var _opponent_lab_tab_w = _main_right - 12 - _opponent_lab_lane_x;
    var _opponent_lab_tab_x = board_viewport_right
        - 12 - _opponent_lab_tab_w;
    var _opponent_lab_tab_h = 30;
    var _opponent_lab_preview_w = max(1, _opponent_lab_tab_w - 12);
    var _opponent_lab_preview_h = floor(_opponent_lab_preview_w * 1.4);
    var _opponent_lab_closed_y = _header_h;
    var _opponent_lab_display_indices = [];
    for (var _opponent_lab_sort_source = 0;
         _opponent_lab_sort_source < array_length(_opponent.lab);
         _opponent_lab_sort_source++) {
        var _opponent_lab_sort_card =
            _opponent.lab[_opponent_lab_sort_source];
        if (variable_struct_exists(
            _opponent_lab_sort_card,
            "ui_lab_arrival_ms"
        )
        && current_time < _opponent_lab_sort_card.ui_lab_arrival_ms) {
            continue;
        }
        array_push(
            _opponent_lab_display_indices,
            _opponent_lab_sort_source
        );
    }
    for (var _opponent_lab_sort_left = 0;
         _opponent_lab_sort_left
            < array_length(_opponent_lab_display_indices) - 1;
         _opponent_lab_sort_left++) {
        for (var _opponent_lab_sort_right = _opponent_lab_sort_left + 1;
             _opponent_lab_sort_right
                < array_length(_opponent_lab_display_indices);
             _opponent_lab_sort_right++) {
            var _opponent_lab_left_stage = _opponent.lab[
                _opponent_lab_display_indices[_opponent_lab_sort_left]
            ].definition.stage;
            var _opponent_lab_right_stage = _opponent.lab[
                _opponent_lab_display_indices[_opponent_lab_sort_right]
            ].definition.stage;
            var _opponent_lab_left_key = is_real(_opponent_lab_left_stage)
                ? _opponent_lab_left_stage
                : 0;
            var _opponent_lab_right_key = is_real(_opponent_lab_right_stage)
                ? _opponent_lab_right_stage
                : 0;
            if (_opponent_lab_right_key < _opponent_lab_left_key) {
                var _opponent_lab_sort_swap =
                    _opponent_lab_display_indices[_opponent_lab_sort_left];
                _opponent_lab_display_indices[_opponent_lab_sort_left] =
                    _opponent_lab_display_indices[_opponent_lab_sort_right];
                _opponent_lab_display_indices[_opponent_lab_sort_right] =
                    _opponent_lab_sort_swap;
            }
        }
    }
    var _opponent_lab_display_count =
        array_length(_opponent_lab_display_indices);
    var _opponent_lab_available_stack_h = max(
        _opponent_lab_preview_h,
        _opponent_bottom - _opponent_top - _opponent_lab_tab_h - 8
    );
    var _opponent_lab_stack_step = _opponent_lab_display_count <= 1
        ? 0
        : clamp(
            floor(
                (_opponent_lab_available_stack_h - _opponent_lab_preview_h)
                / (_opponent_lab_display_count - 1)
            ),
            16,
            30
        );
    var _opponent_lab_stack_h = _opponent_lab_preview_h
        + (_opponent_lab_stack_step
            * max(0, _opponent_lab_display_count - 1));
    // This tray is fixed to the HUD, so its open position must be calculated from
    // the visible screen edge rather than the opponent board's negative world Y.
    var _opponent_lab_open_y = min(
        _content_bottom - _opponent_lab_tab_h - 4,
        board_viewport_top + _opponent_lab_stack_h + 5
    );
    var _opponent_lab_tab_y = lerp(
        _opponent_lab_closed_y,
        _opponent_lab_open_y,
        opponent_lab_pull_amount
    );
    var _draw_opponent_lab_tray = function(
        _opponent_lab_display_count,
        _opponent_lab_display_indices,
        _opponent,
        _opponent_lab_tab_x,
        _opponent_lab_tab_y,
        _opponent_lab_tab_w,
        _opponent_lab_tab_h,
        _opponent_lab_stack_h,
        _opponent_lab_stack_step,
        _opponent_lab_preview_w,
        _opponent_lab_preview_h,
        _opponent_lab_strength,
        _opponent_lab_hazard,
        _opponent_lab_pull_amount,
        _opponent_lab_screen_top
    ) {
    var _opponent_lab_clip_x = _opponent_lab_tab_x;
    var _opponent_lab_clip_y = max(
        board_viewport_top,
        _opponent_lab_screen_top
    );
    gpu_set_scissor(
        _opponent_lab_clip_x,
        _opponent_lab_clip_y,
        max(
            1,
            min(
                _opponent_lab_tab_w,
                board_viewport_right - _opponent_lab_clip_x
            )
        ),
        max(1, ui_screen_height - _opponent_lab_clip_y)
    );
    if (array_length(_opponent.lab) > 0
    && _opponent_lab_pull_amount > 0.01) {
        var _opponent_lab_stack_x = _opponent_lab_tab_x
            + floor(
                (_opponent_lab_tab_w - _opponent_lab_preview_w) * 0.5
            );
        var _opponent_lab_stack_y = _opponent_lab_tab_y
            - _opponent_lab_stack_h - 5;
        var _opponent_lab_tray_left = _opponent_lab_tab_x;
        var _opponent_lab_tray_right =
            _opponent_lab_tab_x + _opponent_lab_tab_w;
        var _opponent_lab_tray_top = _opponent_lab_screen_top;
        draw_set_alpha(0.94 * max(0.15, _opponent_lab_pull_amount));
        draw_set_color(ui_color_panel_alt);
        draw_rectangle(
            _opponent_lab_tray_left,
            _opponent_lab_tray_top,
            _opponent_lab_tray_right,
            _opponent_lab_tab_y,
            false
        );
        draw_set_alpha(max(0.15, _opponent_lab_pull_amount));
        draw_set_color(ui_color_line);
        draw_rectangle(
            _opponent_lab_tray_left,
            _opponent_lab_tray_top,
            _opponent_lab_tray_right,
            _opponent_lab_tab_y,
            true
        );
        draw_set_alpha(max(0.15, _opponent_lab_pull_amount));
        for (var _opponent_lab_display_position = 0;
             _opponent_lab_display_position < _opponent_lab_display_count;
             _opponent_lab_display_position++) {
            var _opponent_lab_display_index =
                _opponent_lab_display_indices[
                    _opponent_lab_display_position
                ];
            var _opponent_lab_display_metroid =
                _opponent.lab[_opponent_lab_display_index];
            var _opponent_lab_display_y = _opponent_lab_stack_y
                + (_opponent_lab_display_position
                    * _opponent_lab_stack_step);
            var _opponent_lab_sprite = get_definition_sprite(
                _opponent_lab_display_metroid.definition,
                true
            );
            if (_opponent_lab_sprite >= 0) {
                draw_sprite_stretched(
                    _opponent_lab_sprite,
                    0,
                    _opponent_lab_stack_x,
                    _opponent_lab_display_y,
                    _opponent_lab_preview_w,
                    _opponent_lab_preview_h
                );
            } else {
                draw_set_color(ui_color_error);
                draw_rectangle(
                    _opponent_lab_stack_x,
                    _opponent_lab_display_y,
                    _opponent_lab_stack_x + _opponent_lab_preview_w,
                    _opponent_lab_display_y + _opponent_lab_preview_h,
                    true
                );
            }
            if (_opponent_lab_pull_amount > 0.35) {
                array_push(
                    ui_hit_regions,
                    {
                        kind: "opponent_lab",
                        index: _opponent_lab_display_index,
                        instance: _opponent_lab_display_metroid,
                        x1: _opponent_lab_stack_x,
                        y1: _opponent_lab_display_y,
                        x2: _opponent_lab_stack_x
                            + _opponent_lab_preview_w,
                        y2: _opponent_lab_display_y
                            + _opponent_lab_preview_h,
                        enabled: true,
                        action: ""
                    }
                );
            }
        }
        draw_set_alpha(1);
    }
    draw_set_color(
        _opponent_lab_strength < _opponent_lab_hazard
            ? ui_color_error
            : ((ui_hover_kind == "opponent_lab_tab"
                || ui_selected_kind == "opponent_lab_tab")
                ? ui_color_selected
                : ui_color_panel_alt)
    );
    draw_rectangle(
        _opponent_lab_tab_x,
        _opponent_lab_tab_y,
        _opponent_lab_tab_x + _opponent_lab_tab_w,
        _opponent_lab_tab_y + _opponent_lab_tab_h,
        false
    );
    draw_set_color(ui_color_line);
    draw_rectangle(
        _opponent_lab_tab_x,
        _opponent_lab_tab_y,
        _opponent_lab_tab_x + _opponent_lab_tab_w,
        _opponent_lab_tab_y + _opponent_lab_tab_h,
        true
    );
    draw_set_color(ui_color_text);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text(
        _opponent_lab_tab_x + (_opponent_lab_tab_w * 0.5),
        _opponent_lab_tab_y + (_opponent_lab_tab_h * 0.5),
        "Lab " + string(_opponent_lab_strength)
            + "/" + string(_opponent_lab_hazard)
    );
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    array_push(
        ui_hit_regions,
        {
            kind: "opponent_lab_tab",
            index: 0,
            instance: undefined,
            x1: _opponent_lab_tab_x,
            y1: _opponent_lab_tab_y,
            x2: _opponent_lab_tab_x + _opponent_lab_tab_w,
            y2: _opponent_lab_tab_y + _opponent_lab_tab_h,
            enabled: true,
            action: ""
        }
    );
    gpu_set_scissor(
        0,
        board_viewport_top,
        board_viewport_right,
        max(1, ui_screen_height - board_viewport_top)
    );
    };

    // Always establish the closed tab and its hit region with the opponent board.
    // The later pass redraws an opened drawer above the central board panels.
    matrix_set(matrix_world, _world_matrix_before);
    var _opponent_hud_region_start = array_length(ui_hit_regions);
    _draw_opponent_lab_tray(
        _opponent_lab_display_count,
        _opponent_lab_display_indices,
        _opponent,
        _opponent_lab_tab_x,
        _opponent_lab_tab_y,
        _opponent_lab_tab_w,
        _opponent_lab_tab_h,
        _opponent_lab_stack_h,
        _opponent_lab_stack_step,
        _opponent_lab_preview_w,
        _opponent_lab_preview_h,
        _opponent_lab_strength,
        _opponent_lab_hazard,
        opponent_lab_pull_amount,
        board_viewport_top
    );

    for (var _opponent_hud_region_index = _opponent_hud_region_start;
         _opponent_hud_region_index < array_length(ui_hit_regions);
         _opponent_hud_region_index++) {
        ui_hit_regions[_opponent_hud_region_index].screen_space = true;
    }
    matrix_set(matrix_world, _board_camera_matrix);
    gpu_set_scissor(
        0,
        board_viewport_top,
        board_viewport_right,
        max(1, _screen_height - board_viewport_top)
    );

    // Shared area: the Shop panel beside the open SR388 table centerpiece.
    // Extend the tray upward without moving the cards. This gives the SHOP label
    // a distinct header band while preserving the established grid and bottom pad.
    var _shop_panel_top = _sr_planet_y - 190;
    var _shop_panel_bottom = _sr_planet_y + 178;
    // The Shop should read as a quiet card tray beside the planet, not another
    // luminous centerpiece.
    draw_set_alpha(0.17);
    draw_set_color(merge_color(c_black, ui_color_title, 0.60));
    draw_rectangle(
        _main_left,
        _shop_panel_top,
        _shop_right,
        _shop_panel_bottom,
        false
    );
    draw_set_alpha(0.56);
    draw_set_color(ui_color_title);
    draw_rectangle(
        _main_left,
        _shop_panel_top,
        _shop_right,
        _shop_panel_bottom,
        true
    );
    draw_set_alpha(1);
    draw_set_color(ui_color_title);
    draw_set_font(FNT_METROID);
    draw_text(_main_left + 10, _shop_panel_top + 7, "SHOP");
    draw_set_font(-1);

    var _shop_inner_left = _main_left + 12;
    var _shop_inner_right = _shop_right - 12;
    var _shop_inner_w = _shop_inner_right - _shop_inner_left;
    var _shop_grid_gap = 8;
    var _shop_card_w = min(
        112,
        floor((_shop_inner_w - (_shop_grid_gap * 2)) / 3)
    );
    var _shop_card_h = floor(_shop_card_w * 1.4);
    var _shop_row_1_y = _sr_planet_y - 140;
    var _shop_row_2_y = _shop_row_1_y + _shop_card_h + _shop_grid_gap;
    // The Shop's draw and discard piles live beyond the left edge of its display.
    // They remain reachable by panning, but do not compete with the five offers in
    // the ordinary centered framing.
    var _deck_area_x = _main_left - _shop_card_w - 28;
    var _deck_area_y = _shop_row_2_y;
    var _deck_area_w = _shop_card_w;
    var _deck_area_h = _shop_card_h;
    var _shop_discard_visual_x = _deck_area_x;
    var _shop_discard_visual_y = _shop_row_1_y;
    var _shop_deck_visual_x = _deck_area_x;
    var _shop_deck_visual_y = _deck_area_y;
    var _card_back_sprite = get_card_back_sprite();
    if (_card_back_sprite >= 0) {
        var _back_source_w = sprite_get_width(_card_back_sprite);
        var _back_source_h = sprite_get_height(_card_back_sprite);
        var _back_scale = min(
            _deck_area_w / _back_source_w,
            _deck_area_h / _back_source_h
        );
        var _back_w = floor(_back_source_w * _back_scale);
        var _back_h = floor(_back_source_h * _back_scale);
        var _back_x = _deck_area_x + floor((_deck_area_w - _back_w) * 0.5);
        var _back_y = _deck_area_y + floor((_deck_area_h - _back_h) * 0.5);
        _shop_deck_visual_x = _back_x;
        _shop_deck_visual_y = _back_y;
        draw_sprite_stretched(
            _card_back_sprite,
            0,
            _back_x,
            _back_y,
            _back_w,
            _back_h
        );
        draw_set_alpha(0.72);
        draw_set_color(c_black);
        draw_circle(
            _back_x + (_back_w * 0.5),
            _back_y + (_back_h * 0.5),
            24,
            false
        );
        draw_set_alpha(1);
        draw_set_color(c_white);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_text_transformed(
            _back_x + (_back_w * 0.5),
            _back_y + (_back_h * 0.5),
            string(array_length(game_state.shop_deck)),
            1.35,
            1.35,
            0
        );
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
    } else {
        draw_set_color(ui_color_line);
        draw_rectangle(
            _deck_area_x,
            _deck_area_y,
            _deck_area_x + _deck_area_w,
            _deck_area_y + _deck_area_h,
            true
        );
    }

    var _shop_discard_count = array_length(game_state.shop_discard);
    if (_shop_discard_count > 0) {
        var _shop_discard_top = game_state.shop_discard[
            _shop_discard_count - 1
        ];
        _draw_card(
            _shop_discard_top,
            _shop_discard_visual_x,
            _shop_discard_visual_y,
            _shop_card_w,
            _shop_card_h,
            true
        );
        draw_set_alpha(0.52);
        draw_set_color(c_black);
        draw_rectangle(
            _shop_discard_visual_x,
            _shop_discard_visual_y,
            _shop_discard_visual_x + _shop_card_w,
            _shop_discard_visual_y + _shop_card_h,
            false
        );
        draw_set_alpha(1);
    } else {
        draw_set_color(ui_color_line);
        draw_rectangle(
            _shop_discard_visual_x,
            _shop_discard_visual_y,
            _shop_discard_visual_x + _shop_card_w,
            _shop_discard_visual_y + _shop_card_h,
            true
        );
    }

    for (var _shop_index = 0;
         _shop_index < array_length(game_state.shop_row);
         _shop_index++) {
        if (presentation_opening_active
        && presentation_opening_frame < 10 + (_shop_index * 6)) {
            continue;
        }
        var _shop_visual_slot = game_state.shop_row[
            _shop_index
        ].ui_shop_slot;
        if (_shop_visual_slot < 0 || _shop_visual_slot >= 5) {
            _shop_visual_slot = _shop_index;
        }
        var _shop_grid_column = _shop_visual_slot < 3
            ? _shop_visual_slot
            : _shop_visual_slot - 3;
        var _shop_row_2_width = (_shop_card_w * 2) + _shop_grid_gap;
        var _shop_row_2_x = _shop_inner_left
            + ((_shop_inner_w - _shop_row_2_width) * 0.5);
        var _shop_target_x = (_shop_visual_slot < 3
            ? _shop_inner_left
            : _shop_row_2_x)
            + (_shop_grid_column * (_shop_card_w + _shop_grid_gap));
        var _shop_target_y = _shop_visual_slot < 3
            ? _shop_row_1_y
            : _shop_row_2_y;
        var _shop_card = game_state.shop_row[_shop_index];
        var _shop_starts_on_deck = _shop_card.ui_force_shop_origin
            || _shop_card.ui_zone == "";
        if (_shop_starts_on_deck) {
            _shop_card.ui_face_down_until_move = true;
        }
        if (_shop_card.ui_force_shop_origin) {
            _shop_card.ui_x = _shop_deck_visual_x;
            _shop_card.ui_y = _shop_deck_visual_y;
            _shop_card.ui_position_initialized = true;
            _shop_card.ui_force_shop_origin = false;
        }
        var _shop_position = _get_lerped_board_position(
            _shop_card,
            _shop_target_x,
            _shop_target_y,
            _shop_deck_visual_x,
            _shop_deck_visual_y,
            "shop",
            140
        );
        var _shop_x = _shop_position.x;
        var _shop_y = _shop_position.y;
        var _shop_face_down = _shop_card.ui_face_down_until_move
            && current_time < max(
                _shop_card.ui_move_after_ms,
                _shop_card.ui_hold_until_ms
            );
        if (_shop_face_down) {
            _draw_dealt_card_back(
                _shop_x,
                _shop_y,
                _shop_card_w,
                _shop_card_h
            );
        } else {
            _shop_card.ui_face_down_until_move = false;
            _draw_card(
                _shop_card,
                _shop_x,
                _shop_y,
                _shop_card_w,
                _shop_card_h,
                true
            );
            if (ui_gameplay_input_enabled
            && game_state.phase == "action"
            && is_undefined(pending_choice)
            && game_state.priority_player == game_state.view_player) {
                var _shop_indicator_deploy_cost = get_modified_deploy_cost(
                    _active_player,
                    _shop_card
                );
                var _shop_indicator_reserve_cost = get_modified_reserve_cost(
                    _active_player,
                    _shop_card
                );
                var _shop_indicator_can_deploy =
                    _shop_card.definition.type != "event"
                    && is_real(_shop_indicator_deploy_cost)
                    && _active_player.command_points
                        >= _shop_indicator_deploy_cost;
                var _shop_indicator_can_reserve =
                    is_real(_shop_indicator_reserve_cost)
                    && _active_player.command_points
                        >= _shop_indicator_reserve_cost;
                if (_shop_indicator_can_deploy) {
                    _draw_playability_line(
                        _shop_x,
                        _shop_y,
                        _shop_card_w,
                        0,
                        0.46
                    );
                }
                if (_shop_indicator_can_reserve) {
                    _draw_playability_line(
                        _shop_x,
                        _shop_y,
                        _shop_card_w,
                        0.54,
                        1
                    );
                }
            }
        }
        if (!is_undefined(pending_choice)
        && pending_choice.kind == "ability_target"
        && can_resolve_ability_target(pending_choice, "shop", _shop_index)) {
            draw_set_color(ui_color_success);
            draw_rectangle(
                _shop_x - 3,
                _shop_y - 3,
                _shop_x + _shop_card_w + 3,
                _shop_y + _shop_card_h + 3,
                true
            );
        }
        if (!_shop_face_down) {
            _add_hit_region(
                "shop",
                _shop_index,
                _shop_card,
                _shop_x,
                _shop_y,
                _shop_card_w,
                _shop_card_h
            );
        }
        if ((ui_selected_kind == "shop" && _shop_index == ui_selected_index)
        || (ui_hover_kind == "shop" && _shop_index == ui_hover_index)) {
            _draw_selection(
                _shop_x,
                _shop_y,
                _shop_card_w,
                _shop_card_h,
                ui_selected_kind == "shop" && _shop_index == ui_selected_index
            );
        }
    }

    var _metroid_w = min(
        132,
        floor((_sr_planet_diameter * 0.72) / 4)
    );
    var _metroid_h = floor(_metroid_w * 1.4);
    var _metroid_gap = max(12, floor(_metroid_w * 0.12));
    var _metroid_row_w = (_metroid_w * 4) + (_metroid_gap * 3);
    var _metroid_start_x = _sr_planet_x - (_metroid_row_w * 0.5);
    var _metroid_row_y = _sr_planet_y - (_metroid_h * 0.5);
    for (var _slot = 0; _slot < 4; _slot++) {
        if (presentation_opening_active
        && presentation_opening_frame < 48 + (_slot * 6)) {
            continue;
        }
        var _metroid_x = _metroid_start_x
            + (_slot * (_metroid_w + _metroid_gap));
        var _metroid_y = _metroid_row_y;
        var _sr_metroid = game_state.sr388[_slot];
        if (!is_undefined(_sr_metroid)) {
            var _sr_metroid_position = _get_lerped_board_position(
                _sr_metroid,
                _metroid_x,
                _metroid_y,
                _metroid_x,
                _metroid_y,
                "sr388",
                0
            );
            _metroid_x = _sr_metroid_position.x;
            _metroid_y = _sr_metroid_position.y;
        }
        _draw_metroid(
            _sr_metroid,
            _metroid_x,
            _metroid_y,
            _metroid_w,
            _metroid_h
        );
        _add_hit_region(
            "metroid",
            _slot,
            _sr_metroid,
            _metroid_x,
            _metroid_y,
            _metroid_w,
            _metroid_h
        );
        if (!is_undefined(pending_choice)
        && (pending_choice.kind == "capture_metroid"
            || pending_choice.kind == "quiet_robe_metroids")) {
            var _legal_target = pending_choice.kind == "capture_metroid"
                ? can_capture_metroid(pending_choice.ship_index, _slot)
                : can_select_quiet_robe_metroid(_slot);
            if (!_legal_target) {
                draw_set_alpha(0.48);
                draw_set_color(c_black);
                draw_rectangle(
                    _metroid_x,
                    _metroid_y,
                    _metroid_x + _metroid_w,
                    _metroid_y + _metroid_h,
                    false
                );
                draw_set_alpha(1);
            }
            draw_set_color(_legal_target ? ui_color_success : ui_color_muted);
            draw_rectangle(
                _metroid_x - 3,
                _metroid_y - 3,
                _metroid_x + _metroid_w + 3,
                _metroid_y + _metroid_h + 3,
                true
            );
        } else if ((ui_selected_kind == "metroid" && _slot == ui_selected_index)
        || (ui_hover_kind == "metroid" && _slot == ui_hover_index)) {
            _draw_selection(
                _metroid_x,
                _metroid_y,
                _metroid_w,
                _metroid_h,
                ui_selected_kind == "metroid" && _slot == ui_selected_index
            );
        }
    }

    // Cavern Omegas are not a fifth surface slot. Once one exists, a hard-light
    // underground-activity contact fades in just beyond the planet's right edge.
    var _cavern_x = _sr_right + 24;
    var _cavern_y = _sr_planet_y - (_metroid_h * 0.5);
    if (cavern_sensor_alpha > 0.005) {
        var _sensor_pad = 14;
        var _sensor_x1 = _cavern_x - _sensor_pad;
        var _sensor_y1 = _cavern_y - 34;
        var _sensor_x2 = _cavern_x + _metroid_w + _sensor_pad;
        var _sensor_y2 = _cavern_y + _metroid_h + 24;
        draw_set_alpha(0.17 * cavern_sensor_alpha);
        draw_set_color(merge_color(c_black, ui_color_title, 0.60));
        draw_rectangle(_sensor_x1, _sensor_y1, _sensor_x2, _sensor_y2, false);
        draw_set_alpha(0.56 * cavern_sensor_alpha);
        draw_set_color(ui_color_title);
        draw_rectangle(_sensor_x1, _sensor_y1, _sensor_x2, _sensor_y2, true);
        // A short leader turns the panel into a magnified underground sensor view
        // instead of reading as a fifth location on SR388's surface.
        draw_line(
            _sensor_x1,
            _sensor_y1 + floor((_sensor_y2 - _sensor_y1) * 0.58),
            _sensor_x1 - 54,
            _sensor_y1 + floor((_sensor_y2 - _sensor_y1) * 0.58) + 34
        );
        draw_set_alpha(cavern_sensor_alpha);
        draw_set_color(ui_color_title);
        draw_set_font(FNT_METROID);
        draw_text(_sensor_x1 + 10, _sensor_y1 + 3, "CAVERNS");
        draw_set_font(-1);
        draw_set_alpha(1);
    }
    if (array_length(game_state.cavern) > 0) {
        var _cavern_metroid =
            game_state.cavern[array_length(game_state.cavern) - 1];
        var _cavern_position = _get_lerped_board_position(
            _cavern_metroid,
            _cavern_x,
            _cavern_y,
            _cavern_x,
            _cavern_y,
            "cavern",
            0
        );
        _cavern_x = _cavern_position.x;
        _cavern_y = _cavern_position.y;
        draw_set_alpha(cavern_sensor_alpha);
        _draw_metroid(
            _cavern_metroid,
            _cavern_x,
            _cavern_y,
            _metroid_w,
            _metroid_h
        );
        draw_set_alpha(1);
    }
    var _cavern_instance = array_length(game_state.cavern) > 0
        ? game_state.cavern[array_length(game_state.cavern) - 1]
        : undefined;
    if (!is_undefined(_cavern_instance) && cavern_sensor_alpha >= 0.5) {
        _add_hit_region(
            "metroid",
            4,
            _cavern_instance,
            _cavern_x,
            _cavern_y,
            _metroid_w,
            _metroid_h
        );
    }
    if (!is_undefined(_cavern_instance)
    && !is_undefined(pending_choice)
    && (pending_choice.kind == "capture_metroid"
        || pending_choice.kind == "quiet_robe_metroids")) {
        var _legal_cavern = pending_choice.kind == "capture_metroid"
            ? can_capture_metroid(pending_choice.ship_index, 4)
            : can_select_quiet_robe_metroid(4);
        if (!_legal_cavern) {
            draw_set_alpha(0.48);
            draw_set_color(c_black);
            draw_rectangle(
                _cavern_x,
                _cavern_y,
                _cavern_x + _metroid_w,
                _cavern_y + _metroid_h,
                false
            );
            draw_set_alpha(1);
        }
        draw_set_color(_legal_cavern ? ui_color_success : ui_color_muted);
        draw_rectangle(
            _cavern_x - 3,
            _cavern_y - 3,
            _cavern_x + _metroid_w + 3,
            _cavern_y + _metroid_h + 3,
            true
        );
    } else if (!is_undefined(_cavern_instance)
    && ((ui_selected_kind == "metroid" && ui_selected_index == 4)
    || (ui_hover_kind == "metroid" && ui_hover_index == 4))) {
        _draw_selection(
            _cavern_x,
            _cavern_y,
            _metroid_w,
            _metroid_h,
            ui_selected_kind == "metroid" && ui_selected_index == 4
        );
    }

    // Player identity is anchored to the contested SR388 formation itself.
    draw_set_font(FNT_METROID);
    var _sr_player_name_y = _metroid_row_y + _metroid_h + 10;
    var _sr_player_name_w = string_width(_active_player.name);
    var _sr_player_plate_x1 = _metroid_start_x - 8;
    var _sr_player_plate_x2 = _metroid_start_x + _sr_player_name_w + 12;
    var _sr_player_plate_y1 = _sr_player_name_y - 2;
    var _sr_player_plate_y2 = _sr_player_name_y + 35;
    var _sr_player_plate_center_y = (
        _sr_player_plate_y1 + _sr_player_plate_y2
    ) * 0.5;
    var _sr_player_cp_x = _sr_player_plate_x2 + 5;

    var _sr_opponent_name_right = _metroid_start_x + _metroid_row_w + 4;
    var _sr_opponent_name_y = _metroid_row_y - 40;
    var _sr_opponent_name_w = string_width(_opponent.name);
    var _sr_opponent_name_left = _sr_opponent_name_right
        - _sr_opponent_name_w;
    var _sr_opponent_plate_x1 = _sr_opponent_name_left - 8;
    var _sr_opponent_plate_x2 = _sr_opponent_name_right + 12;
    var _sr_opponent_plate_y1 = _sr_opponent_name_y - 2;
    var _sr_opponent_plate_y2 = _sr_opponent_name_y + 35;
    var _sr_opponent_plate_center_y = (
        _sr_opponent_plate_y1 + _sr_opponent_plate_y2
    ) * 0.5;
    var _sr_opponent_cp_right = _sr_opponent_plate_x1 - 2;

    var _identity_nameplate_color = function(_player, _fallback) {
        if (game_state.game_mode != "ai_watch") {
            return _fallback;
        }
        switch (_player.favored_faction) {
            case "GF": return LOC_COLOR_GF;
            case "SP": return LOC_COLOR_SP;
            case "CZ": return LOC_COLOR_CZ;
            case "BH": return LOC_COLOR_BH;
            case "PZ": return LOC_COLOR_PZ;
            default: return LOC_COLOR_NEUTRAL;
        }
    };
    var _sr_player_identity_color = _identity_nameplate_color(
        _active_player,
        LOC_COLOR_GF
    );
    var _sr_opponent_identity_color = _identity_nameplate_color(
        _opponent,
        ui_color_error
    );
    var _sr_player_identity_fill = merge_color(
        c_black,
        _sr_player_identity_color,
        0.62
    );
    var _sr_opponent_identity_fill = merge_color(
        c_black,
        _sr_opponent_identity_color,
        0.62
    );

    // A dark underlay supplies contrast over either hemisphere; the restrained
    // allegiance colors remain cyan/red except in AI-watch mode, where each
    // identity uses its faction's hard-light palette.
    draw_set_alpha(0.52);
    draw_set_color(c_black);
    draw_rectangle(
        _sr_player_plate_x1,
        _sr_player_plate_y1,
        _sr_player_plate_x2,
        _sr_player_plate_y2,
        false
    );
    draw_rectangle(
        _sr_opponent_plate_x1,
        _sr_opponent_plate_y1,
        _sr_opponent_plate_x2,
        _sr_opponent_plate_y2,
        false
    );
    draw_set_alpha(0.15);
    draw_set_color(_sr_player_identity_fill);
    draw_rectangle(
        _sr_player_plate_x1,
        _sr_player_plate_y1,
        _sr_player_plate_x2,
        _sr_player_plate_y2,
        false
    );
    draw_set_color(_sr_opponent_identity_fill);
    draw_rectangle(
        _sr_opponent_plate_x1,
        _sr_opponent_plate_y1,
        _sr_opponent_plate_x2,
        _sr_opponent_plate_y2,
        false
    );
    draw_set_alpha(0.52);
    draw_set_color(_sr_player_identity_color);
    draw_rectangle(
        _sr_player_plate_x1,
        _sr_player_plate_y1,
        _sr_player_plate_x2,
        _sr_player_plate_y2,
        true
    );
    draw_set_color(_sr_opponent_identity_color);
    draw_rectangle(
        _sr_opponent_plate_x1,
        _sr_opponent_plate_y1,
        _sr_opponent_plate_x2,
        _sr_opponent_plate_y2,
        true
    );
    draw_set_alpha(1);

    draw_set_color(_sr_player_identity_color);
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_text(
        _metroid_start_x,
        _sr_player_plate_center_y,
        _active_player.name
    );
    // Local CP reads left-to-right immediately after the local player's name.
    for (var _sr_player_cp_index = 0;
         _sr_player_cp_index < _active_player.command_points;
         _sr_player_cp_index++) {
        draw_sprite_stretched(
            sprCP,
            0,
            _sr_player_cp_x + (_sr_player_cp_index * 23),
            _sr_player_plate_center_y - 10,
            20,
            20
        );
    }
    draw_set_halign(fa_right);
    draw_set_color(_sr_opponent_identity_color);
    draw_text(
        _sr_opponent_name_right,
        _sr_opponent_plate_center_y,
        _opponent.name
    );
    _draw_cp_row(
        _sr_opponent_cp_right,
        _sr_opponent_plate_center_y - 10,
        _opponent.command_points
    );
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_font(-1);

    // The active board is the uncovered table surface. Card type affects its
    // preferred position, but no panel, lane, or outer frame divides that surface.
    var _active_layout_cards = [];
    var _active_layout_kinds = [];
    var _active_layout_indices = [];
    var _active_layout_rects = [];
    var _play_left = _main_left + 16;
    var _play_top = _board_top + 38;
    var _play_bottom = _board_bottom - 54;
    var _location_left = _main_left
        + floor((_main_right - _main_left) * 0.86);
    // The SR388-facing rows span the whole play surface. Locations remain a
    // separate overlay at the right edge rather than squeezing those rows.
    var _main_play_right = _main_right - 16;
    var _play_height = _play_bottom - _play_top;
    var _ship_row_bottom = _play_top + floor(_play_height * 0.40);
    var _character_row_top = _ship_row_bottom + 10;

    var _layout_sources = [
        _active_player.board.ships,
        _active_player.board.characters,
        _active_player.board.locations
    ];
    var _layout_kinds = ["ship", "character", "location"];
    for (var _layout_zone = 0; _layout_zone < 3; _layout_zone++) {
        var _layout_cards = _layout_sources[_layout_zone];
        var _layout_count = array_length(_layout_cards);
        var _layout_card_w = _layout_zone == 0
            ? 184
            : (_layout_zone == 1 ? 116 : 104);
        var _layout_card_h = _layout_zone == 0
            ? 132
            : (_layout_zone == 1 ? 162 : 146);
        var _layout_start_x = _play_left;
        var _layout_start_y = _play_top;
        var _layout_step = 0;
        if (_layout_zone < 2) {
            var _row_left = _play_left;
            var _row_right = _main_play_right;
            var _row_available = max(1, _row_right - _row_left);
            _layout_step = _layout_count <= 1
                ? 0
                : min(
                    _layout_card_w + 10,
                    (_row_available - _layout_card_w)
                        / max(1, _layout_count - 1)
                );
            var _layout_row_w = _layout_card_w
                + (_layout_step * max(0, _layout_count - 1));
            _layout_start_x = _row_left
                + ((_row_available - _layout_row_w) * 0.5);
            _layout_start_y = _layout_zone == 0
                ? _play_top + 8
                : _play_bottom - _layout_card_h - 8;
        } else {
            _layout_start_x = _main_right - 12 - _layout_card_w;
            _layout_start_y = (_play_top + _play_bottom) * 0.5;
        }
        for (var _layout_index = 0;
             _layout_index < _layout_count;
             _layout_index++) {
            var _layout_center_index = (_layout_count - 1) * 0.5;
            var _layout_arc = _layout_zone < 2
                ? abs(_layout_index - _layout_center_index) * 3
                : 0;
            var _location_position = _layout_zone == 2
                ? _get_location_cluster_position(
                    _layout_index,
                    _layout_count,
                    _layout_card_w,
                    _layout_card_h,
                    _play_left,
                    _main_right - 12,
                    (_play_top + _play_bottom) * 0.5,
                    true,
                    false
                )
                : {x: _layout_start_x, y: _layout_start_y};
            array_push(_active_layout_cards, _layout_cards[_layout_index]);
            array_push(_active_layout_kinds, _layout_kinds[_layout_zone]);
            array_push(_active_layout_indices, _layout_index);
            array_push(_active_layout_rects, {
                x: _layout_zone == 2
                    ? _location_position.x
                    : _layout_start_x + (_layout_index * _layout_step),
                y: _layout_zone == 2
                    ? _location_position.y
                    : _layout_start_y + _layout_arc,
                width: _layout_card_w,
                height: _layout_card_h
            });
        }
    }

    for (var _active_layout_index = 0;
         _active_layout_index < array_length(_active_layout_cards);
         _active_layout_index++) {
            var _active_card = _active_layout_cards[_active_layout_index];
            var _zone_kind = _active_layout_kinds[_active_layout_index];
             var _logical_zone_index =
                 _active_layout_indices[_active_layout_index];
             var _active_rect = _active_layout_rects[_active_layout_index];
            var _active_position = _get_lerped_board_position(
                _active_card,
                _active_rect.x,
                _active_rect.y,
                _active_rect.x,
                _active_rect.y,
                "active_board",
                0
            );
            _active_rect.x = _active_position.x;
            _active_rect.y = _active_position.y;
             _draw_card(
                _active_card,
                _active_rect.x,
                _active_rect.y,
                _active_rect.width,
                _active_rect.height,
                false,
                true
            );
            var _active_bounds = _get_card_bounds(
                _active_card,
                _active_rect.x,
                _active_rect.y,
                _active_rect.width,
                _active_rect.height,
                false
            );
            if (_card_has_usable_ability(
                _zone_kind,
                _logical_zone_index,
                _active_card
            )) {
                _draw_playability_line(
                    _active_bounds.x,
                    _active_bounds.y,
                    _active_bounds.width,
                    0,
                    1
                );
            }

            _add_hit_region(
                _zone_kind,
                _logical_zone_index,
                _active_card,
                _active_bounds.x,
                _active_bounds.y,
                _active_bounds.width,
                _active_bounds.height
            );
            if (!is_undefined(pending_choice)
            && (pending_choice.kind == "ability_target"
                && can_resolve_ability_target(
                    pending_choice,
                    _zone_kind,
                    _logical_zone_index
                )
                || pending_choice.kind == "space_pirate_ready"
                && pending_choice.owner_index == game_state.active_player
                && _zone_kind == "character"
                && !_active_card.ready
                && card_has_faction(_active_card, "SP")
                || pending_choice.kind == "breach_character"
                && pending_choice.player_index == game_state.active_player
                && _zone_kind == "character"
                || pending_choice.kind == "olympus_ready"
                && pending_choice.player_index == game_state.active_player
                && _zone_kind == "character"
                && !_active_card.ready
                && card_has_faction(_active_card, "GF"))) {
                draw_set_color(ui_color_success);
                draw_rectangle(
                    _active_bounds.x - 3,
                    _active_bounds.y - 3,
                    _active_bounds.x + _active_bounds.width + 3,
                    _active_bounds.y + _active_bounds.height + 3,
                    true
                );
            }

            if ((ui_selected_kind == _zone_kind
            && _logical_zone_index == ui_selected_index)
            || (ui_hover_kind == _zone_kind
            && _logical_zone_index == ui_hover_index)) {
                _draw_selection(
                    _active_bounds.x,
                    _active_bounds.y,
                    _active_bounds.width,
                    _active_bounds.height,
                    ui_selected_kind == _zone_kind
                    && _logical_zone_index == ui_selected_index
                );
            }
            if (!is_undefined(pending_choice)
            && pending_choice.kind == "raid"
            && _active_card.controller == game_state.priority_player
            && pending_choice.stage != "target") {
                var _active_raid_source_kind = get_raid_source_kind(
                    _zone_kind,
                    _active_card
                );
                draw_set_color(
                    pending_choice.ability_source_kind == _active_raid_source_kind
                    && pending_choice.ability_source_index == _logical_zone_index
                        ? ui_color_selected
                        : ui_color_success
                );
                draw_rectangle(
                    _active_bounds.x - 3,
                    _active_bounds.y - 3,
                    _active_bounds.x + _active_bounds.width + 3,
                    _active_bounds.y + _active_bounds.height + 3,
                    true
                );
            }

            if (_zone_kind == "ship") {
                var _ship = _active_card;
                _ship.ui_cargo_anchor_x =
                    _active_bounds.x + _active_bounds.width - 30;
                _ship.ui_cargo_anchor_y =
                    _active_bounds.y + _active_bounds.height - 42;
                for (var _cargo_index = 0;
                     _cargo_index < array_length(_ship.cargo);
                     _cargo_index++) {
                    var _cargo = _ship.cargo[_cargo_index];
                    if (current_time < _cargo.ui_cargo_arrival_ms) {
                        continue;
                    }
                    var _cargo_x = _ship.ui_cargo_anchor_x
                        - (_cargo_index * 22);
                    var _cargo_y = _ship.ui_cargo_anchor_y;
                    var _cargo_position = _get_lerped_board_position(
                        _cargo,
                        _cargo_x,
                        _cargo_y,
                        _cargo_x,
                        _cargo_y,
                        "active_cargo",
                        0
                    );
                    _cargo_x = _cargo_position.x;
                    _cargo_y = _cargo_position.y;
                    _draw_metroid(
                        _cargo,
                        _cargo_x,
                        _cargo_y,
                        30,
                        42
                    );
                    _add_hit_region(
                        "cargo",
                        _logical_zone_index,
                        _cargo,
                        _cargo_x,
                        _cargo_y,
                        30,
                        42
                    );
                }
            }
            var _attachment_count = min(
                2,
                array_length(_active_card.attachments)
            );
            for (var _attachment_index = 0;
                 _attachment_index < _attachment_count;
                 _attachment_index++) {
                var _attachment =
                    _active_card.attachments[_attachment_index];
                var _attachment_x = _active_bounds.x
                    + (_attachment_index * 25);
                var _attachment_y = _active_bounds.y
                    + _active_bounds.height - 30;
                var _attachment_position = _get_lerped_board_position(
                    _attachment,
                    _attachment_x,
                    _attachment_y,
                    _attachment_x,
                    _attachment_y,
                    "active_attachment",
                    60
                );
                _attachment_x = _attachment_position.x;
                _attachment_y = _attachment_position.y;
                _draw_card(
                    _attachment,
                    _attachment_x,
                    _attachment_y,
                    23,
                    33,
                    false,
                    true
                );
                _add_hit_region(
                    "attachment",
                    _attachment.instance_id,
                    _attachment,
                    _attachment_x,
                    _attachment_y,
                    23,
                    33
                );
            }
            if (_attachment_count > 0) {
                _draw_live_stat_badge(
                    _active_card,
                    _active_bounds.x,
                    _active_bounds.y,
                    _active_bounds.width,
                    _active_bounds.height,
                    true
                );
            }
    }

    matrix_set(matrix_world, _world_matrix_before);
    gpu_set_scissor(
        0,
        _header_h,
        board_viewport_right,
        max(1, _screen_height - _header_h)
    );
    var _lab_hud_region_start = array_length(ui_hit_regions);

    // The Lab stays tucked beneath the location lane. Opening its tab lifts a
    // stage-ordered vertical stack, leaving each covered card's title visible.
    var _lab_strength = get_ready_character_strength(_active_player);
    var _lab_hazard = get_lab_hazard(_active_player);
    var _preview_active_containment_ship =
        game_state.phase == "containment"
        && game_state.active_player == game_state.view_player
        || !is_undefined(pending_choice)
            && pending_choice.kind == "special_containment_ship"
            && pending_choice.player_index == game_state.view_player;
    if (_preview_active_containment_ship
    && ui_selected_kind == "ship"
    && ui_selected_index >= 0
    && ui_selected_index < array_length(_active_player.board.ships)
    && _active_player.board.ships[ui_selected_index].ready) {
        _lab_strength += get_card_stat(
            _active_player.board.ships[ui_selected_index],
            "containment_ship"
        );
    }
    var _lab_tab_w = _main_right - 12 - _location_left;
    var _lab_tab_x = board_viewport_right - 12 - _lab_tab_w;
    var _lab_tab_h = 30;
    var _lab_preview_w = max(1, _lab_tab_w - 12);
    var _lab_preview_h = floor(_lab_preview_w * 1.4);
    var _lab_closed_y = _screen_height - _lab_tab_h;
    var _lab_display_indices = [];
    for (var _lab_sort_source = 0;
         _lab_sort_source < array_length(_active_player.lab);
         _lab_sort_source++) {
        var _lab_sort_card = _active_player.lab[_lab_sort_source];
        if (variable_struct_exists(_lab_sort_card, "ui_lab_arrival_ms")
        && current_time < _lab_sort_card.ui_lab_arrival_ms) {
            continue;
        }
        array_push(_lab_display_indices, _lab_sort_source);
    }
    // Hunters have no numbered evolutionary stage. Put them before the standard
    // progression, which also matches their first-to-breach identity.
    for (var _lab_sort_left = 0;
         _lab_sort_left < array_length(_lab_display_indices) - 1;
         _lab_sort_left++) {
        for (var _lab_sort_right = _lab_sort_left + 1;
             _lab_sort_right < array_length(_lab_display_indices);
             _lab_sort_right++) {
            var _lab_left_stage = _active_player.lab[
                _lab_display_indices[_lab_sort_left]
            ].definition.stage;
            var _lab_right_stage = _active_player.lab[
                _lab_display_indices[_lab_sort_right]
            ].definition.stage;
            var _lab_left_key = is_real(_lab_left_stage) ? _lab_left_stage : 0;
            var _lab_right_key = is_real(_lab_right_stage) ? _lab_right_stage : 0;
            if (_lab_right_key < _lab_left_key) {
                var _lab_sort_swap = _lab_display_indices[_lab_sort_left];
                _lab_display_indices[_lab_sort_left] =
                    _lab_display_indices[_lab_sort_right];
                _lab_display_indices[_lab_sort_right] = _lab_sort_swap;
            }
        }
    }
    var _lab_display_count = array_length(_lab_display_indices);
    var _lab_hidden_x = _lab_tab_x
        + floor((_lab_tab_w - _lab_preview_w) * 0.5);
    var _lab_hidden_y = _lab_closed_y + _lab_tab_h + 5;
    var _lab_available_stack_h = max(
        _lab_preview_h,
        _screen_height - _board_top - _lab_tab_h - 12
    );
    var _lab_stack_step = _lab_display_count <= 1
        ? 0
        : clamp(
            floor(
                (_lab_available_stack_h - _lab_preview_h)
                / (_lab_display_count - 1)
            ),
            16,
            30
        );
    if (lab_pull_amount <= 0.01) {
        for (var _lab_hidden_position = 0;
             _lab_hidden_position < _lab_display_count;
             _lab_hidden_position++) {
            var _lab_hidden_index =
                _lab_display_indices[_lab_hidden_position];
            var _lab_stage_metroid =
                _active_player.lab[_lab_hidden_index];
            _lab_stage_metroid.ui_x = _lab_hidden_x;
            _lab_stage_metroid.ui_y = _lab_hidden_y
                + (_lab_hidden_position * _lab_stack_step);
            _lab_stage_metroid.ui_position_initialized = true;
            _lab_stage_metroid.ui_zone = "active_lab_hidden";
            _lab_stage_metroid.ui_move_after_ms = 0;
        }
    }
    var _lab_stack_h = _lab_preview_h
        + (_lab_stack_step * max(0, _lab_display_count - 1));
    var _lab_open_y = max(
        _board_top + 4,
        _screen_height - _lab_tab_h - _lab_stack_h - 5
    );
    var _lab_tab_y = lerp(_lab_closed_y, _lab_open_y, lab_pull_amount);
    var _show_torizo_lab_choice = !is_undefined(pending_choice)
        && pending_choice.kind == "torizo_metroid"
        && pending_choice.player_index == game_state.view_player;
    if (array_length(_active_player.lab) > 0 && lab_pull_amount > 0.01) {
        var _lab_stack_x = _lab_tab_x
            + floor((_lab_tab_w - _lab_preview_w) * 0.5);
        var _lab_stack_y = _lab_tab_y + _lab_tab_h + 5;
        var _lab_tray_left = _lab_tab_x;
        var _lab_tray_right = _lab_tab_x + _lab_tab_w;
        var _lab_tray_bottom = _screen_height + 24;
        draw_set_alpha(0.94 * max(0.15, lab_pull_amount));
        draw_set_color(ui_color_panel_alt);
        draw_rectangle(
            _lab_tray_left,
            _lab_tab_y + _lab_tab_h,
            _lab_tray_right,
            _lab_tray_bottom,
            false
        );
        draw_set_alpha(max(0.15, lab_pull_amount));
        draw_set_color(ui_color_line);
        draw_rectangle(
            _lab_tray_left,
            _lab_tab_y + _lab_tab_h,
            _lab_tray_right,
            _lab_tray_bottom,
            true
        );
        draw_set_alpha(max(0.15, lab_pull_amount));
        for (var _lab_display_position = 0;
             _lab_display_position < _lab_display_count;
             _lab_display_position++) {
            var _lab_display_index =
                _lab_display_indices[_lab_display_position];
            var _lab_display_metroid =
                _active_player.lab[_lab_display_index];
            var _lab_display_y = _lab_stack_y
                + (_lab_display_position * _lab_stack_step);
            // The cards are seated in the drawer. Its lerped tab position supplies
            // their movement, so the tray and contents travel as a single object.
            var _lab_display_x = _lab_stack_x;
            _lab_display_metroid.ui_x = _lab_display_x;
            _lab_display_metroid.ui_y = _lab_display_y;
            _lab_display_metroid.ui_position_initialized = true;
            _lab_display_metroid.ui_zone = "active_lab";
            var _lab_display_stage = _lab_display_metroid.definition.stage;
            var _lab_torizo_eligible = is_real(_lab_display_stage)
                && _lab_display_stage < 5;
            _draw_metroid(
                _lab_display_metroid,
                _lab_display_x,
                _lab_display_y,
                _lab_preview_w,
                _lab_preview_h
            );
            if (_show_torizo_lab_choice) {
                draw_set_color(
                    _lab_torizo_eligible
                        ? ui_color_success
                        : ui_color_muted
                );
                draw_rectangle(
                    _lab_display_x - 2,
                    _lab_display_y - 2,
                    _lab_display_x + _lab_preview_w + 2,
                    _lab_display_y + _lab_preview_h + 2,
                    true
                );
            }
            if (lab_pull_amount > 0.35) {
                _add_hit_region(
                    "lab",
                    _lab_display_index,
                    _lab_display_metroid,
                    _lab_display_x,
                    _lab_display_y,
                    _lab_preview_w,
                    _lab_preview_h
                );
            }
        }
        draw_set_alpha(1);
    }
    draw_set_color(
        _lab_strength < _lab_hazard
            ? ui_color_error
            : ((ui_hover_kind == "lab_tab" || ui_selected_kind == "lab_tab")
                ? ui_color_selected
                : ui_color_panel_alt)
    );
    draw_rectangle(
        _lab_tab_x,
        _lab_tab_y,
        _lab_tab_x + _lab_tab_w,
        _lab_tab_y + _lab_tab_h,
        false
    );
    draw_set_color(ui_color_line);
    draw_rectangle(
        _lab_tab_x,
        _lab_tab_y,
        _lab_tab_x + _lab_tab_w,
        _lab_tab_y + _lab_tab_h,
        true
    );
    draw_set_color(ui_color_text);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text(
        _lab_tab_x + (_lab_tab_w * 0.5),
        _lab_tab_y + (_lab_tab_h * 0.5),
        "Lab " + string(_lab_strength) + "/" + string(_lab_hazard)
    );
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    _add_hit_region(
        "lab_tab",
        0,
        undefined,
        _lab_tab_x,
        _lab_tab_y,
        _lab_tab_w,
        _lab_tab_h
    );

    // Draw the upper Lab last so its expanded tray remains above the shared
    // Shop/SR388 strip rather than being covered by those board panels.
    _draw_opponent_lab_tray(
        _opponent_lab_display_count,
        _opponent_lab_display_indices,
        _opponent,
        _opponent_lab_tab_x,
        _opponent_lab_tab_y,
        _opponent_lab_tab_w,
        _opponent_lab_tab_h,
        _opponent_lab_stack_h,
        _opponent_lab_stack_step,
        _opponent_lab_preview_w,
        _opponent_lab_preview_h,
        _opponent_lab_strength,
        _opponent_lab_hazard,
        opponent_lab_pull_amount,
        _header_h
    );
    for (var _lab_hud_region_index = _lab_hud_region_start;
         _lab_hud_region_index < array_length(ui_hit_regions);
         _lab_hud_region_index++) {
        ui_hit_regions[_lab_hud_region_index].screen_space = true;
    }
    matrix_set(matrix_world, _board_camera_matrix);
    gpu_set_scissor(
        0,
        _header_h,
        board_viewport_right,
        max(1, _screen_height - _header_h)
    );

    // The deck and latest discard occupy the lower-left table edge. The discard
    // is darkened so it reads as an inactive pile while remaining inspectable.
    var _pile_h = floor((_play_bottom - _character_row_top - 8) * 0.5);
    var _pile_w = floor(_pile_h * (1000 / 1400));
    var _pile_y = _content_bottom - _pile_h - 5;
    var _deck_pile_x = _main_left + 10;
    var _discard_pile_x = _deck_pile_x;
    var _discard_pile_y = _pile_y - _pile_h - 8;
    var _discard_target_x = _discard_pile_x;
    var _discard_target_y = _discard_pile_y;
    if (_card_back_sprite >= 0) {
        draw_sprite_stretched(
            _card_back_sprite,
            0,
            _deck_pile_x,
            _pile_y,
            _pile_w,
            _pile_h
        );
    }
    draw_set_alpha(0.68);
    draw_set_color(c_black);
    draw_circle(
        _deck_pile_x + (_pile_w * 0.5),
        _pile_y + (_pile_h * 0.5),
        15,
        false
    );
    draw_set_alpha(1);
    draw_set_color(c_white);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text(
        _deck_pile_x + (_pile_w * 0.5),
        _pile_y + (_pile_h * 0.5),
        string(array_length(_active_player.deck))
    );
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    _add_hit_region(
        "deck",
        0,
        undefined,
        _deck_pile_x,
        _pile_y,
        _pile_w,
        _pile_h
    );

    var _discard_count = array_length(_active_player.discard);
    var _discard_display_index = _discard_count - 1;
    if (_discard_display_index >= 0
    && current_time < _active_player.discard[
        _discard_display_index
    ].ui_hide_until_ms) {
        _discard_display_index -= 1;
    }
    if (_discard_display_index >= 0) {
        var _latest_discard = _active_player.discard[_discard_display_index];
        if (_latest_discard.ui_hide_until_ms > 0) {
            _latest_discard.ui_x = _discard_target_x;
            _latest_discard.ui_y = _discard_target_y;
            _latest_discard.ui_zone = "active_discard";
            _latest_discard.ui_move_after_ms = 0;
            _latest_discard.ui_hide_until_ms = 0;
        }
        var _discard_position = _get_lerped_board_position(
            _latest_discard,
            _discard_pile_x,
            _discard_pile_y,
            _deck_pile_x,
            _pile_y,
            "active_discard",
            90
        );
        _discard_pile_x = _discard_position.x;
        _discard_pile_y = _discard_position.y;
        _draw_card(
            _latest_discard,
            _discard_pile_x,
            _discard_pile_y,
            _pile_w,
            _pile_h,
            true
        );
        var _discard_bounds = {
            x: _discard_pile_x,
            y: _discard_pile_y,
            width: _pile_w,
            height: _pile_h
        };
        draw_set_alpha(0.52);
        draw_set_color(c_black);
        draw_rectangle(
            _discard_bounds.x,
            _discard_bounds.y,
            _discard_bounds.x + _discard_bounds.width,
            _discard_bounds.y + _discard_bounds.height,
            false
        );
        draw_set_alpha(1);
        _add_hit_region(
            "discard",
            _discard_display_index,
            _latest_discard,
            _discard_bounds.x,
            _discard_bounds.y,
            _discard_bounds.width,
            _discard_bounds.height
        );
    } else {
        draw_set_color(ui_color_line);
        draw_rectangle(
            _discard_pile_x,
            _discard_pile_y,
            _discard_pile_x + _pile_w,
            _discard_pile_y + _pile_h,
            true
        );
    }
    if (ui_hover_kind == "discard") {
        draw_set_color(ui_color_text);
        draw_set_halign(fa_center);
        draw_set_valign(fa_bottom);
        draw_text(
            _discard_target_x + (_pile_w * 0.5),
            _discard_target_y - 4,
            string(_discard_count) + " cards"
        );
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
    }

    // Presentation-only cards bridge resolved zone changes. Refresh discards move
    // together, while a recycled discard stack travels back into its deck.
    for (var _transit_draw_index = 0;
         _transit_draw_index < array_length(presentation_card_transits);
         _transit_draw_index++) {
        var _transit = presentation_card_transits[_transit_draw_index];
        if (current_time < _transit.started_at_ms) {
            continue;
        }
        var _transit_t = clamp(
            (current_time - _transit.started_at_ms)
                / max(1, _transit.duration_ms),
            0,
            1
        );
        var _transit_ease = 1 - power(1 - _transit_t, 3);
        var _transit_x1 = _transit.start_x;
        var _transit_y1 = _transit.start_y;
        var _transit_x2 = _discard_target_x;
        var _transit_y2 = _discard_target_y;
        var _transit_w1 = 145;
        var _transit_h1 = 203;
        var _transit_w2 = _pile_w;
        var _transit_h2 = _pile_h;
        if (_transit.kind == "discard_to_deck") {
            var _transit_is_view_player =
                _transit.player_index == game_state.view_player;
            _transit_x1 = _transit_is_view_player
                ? _discard_target_x
                : _opponent_discard_target_x;
            _transit_y1 = _transit_is_view_player
                ? _discard_target_y
                : _opponent_discard_target_y;
            _transit_x2 = _transit_is_view_player
                ? _deck_pile_x
                : _opponent_pile_x;
            _transit_y2 = _transit_is_view_player
                ? _pile_y
                : _opponent_deck_y;
            _transit_w1 = _transit_is_view_player
                ? _pile_w
                : _opponent_pile_w;
            _transit_h1 = _transit_is_view_player
                ? _pile_h
                : _opponent_pile_h;
            _transit_w2 = _transit_w1;
            _transit_h2 = _transit_h1;
        } else if (_transit.kind == "shop_to_discard"
        && _transit.player_index != game_state.view_player) {
            _transit_x2 = _opponent_discard_target_x;
            _transit_y2 = _opponent_discard_target_y;
            _transit_w2 = _opponent_pile_w;
            _transit_h2 = _opponent_pile_h;
        } else if (_transit.kind == "shop_refresh_out") {
            _transit_x2 = _shop_discard_visual_x;
            _transit_y2 = _shop_discard_visual_y;
            _transit_w1 = _shop_card_w;
            _transit_h1 = _shop_card_h;
            _transit_w2 = _shop_card_w;
            _transit_h2 = _shop_card_h;
        } else if (_transit.kind == "metroid_to_ship") {
            var _transit_ship_is_view_player =
                _transit.player_index == game_state.view_player;
            var _transit_ship = _transit.target_ship;
            var _transit_cargo_spacing = _transit_ship_is_view_player ? 22 : 18;
            var _transit_cargo_w = _transit_ship_is_view_player ? 30 : 24;
            var _transit_cargo_h = _transit_ship_is_view_player ? 42 : 34;
            _transit_x2 = variable_struct_exists(
                _transit_ship,
                "ui_cargo_anchor_x"
            )
                ? _transit_ship.ui_cargo_anchor_x
                    - (_transit.cargo_index * _transit_cargo_spacing)
                : _transit.start_x;
            _transit_y2 = variable_struct_exists(
                _transit_ship,
                "ui_cargo_anchor_y"
            )
                ? _transit_ship.ui_cargo_anchor_y
                : _transit.start_y;
            _transit_w1 = 30;
            _transit_h1 = 42;
            _transit_w2 = _transit_cargo_w;
            _transit_h2 = _transit_cargo_h;
        } else if (_transit.kind == "metroid_to_lab") {
            var _transit_lab_is_view_player =
                _transit.player_index == game_state.view_player;
            var _transit_lab_screen_x = _transit_lab_is_view_player
                ? _lab_hidden_x
                : _opponent_lab_tab_x
                    + floor(
                        (_opponent_lab_tab_w - _opponent_lab_preview_w)
                        * 0.5
                    );
            var _transit_lab_screen_y = _transit_lab_is_view_player
                ? _lab_tab_y + _lab_tab_h + 5
                : _opponent_lab_tab_y
                    - _opponent_lab_stack_h - 5;
            _transit_x2 = board_camera_x
                + (_transit_lab_screen_x / max(0.01, board_camera_zoom));
            _transit_y2 = board_camera_y
                + ((_transit_lab_screen_y - _header_h)
                    / max(0.01, board_camera_zoom));
            _transit_w1 = 30;
            _transit_h1 = 42;
            _transit_w2 = _transit_lab_is_view_player
                ? _lab_preview_w / max(0.01, board_camera_zoom)
                : _opponent_lab_preview_w / max(0.01, board_camera_zoom);
            _transit_h2 = _transit_lab_is_view_player
                ? _lab_preview_h / max(0.01, board_camera_zoom)
                : _opponent_lab_preview_h / max(0.01, board_camera_zoom);
        }
        var _transit_x = lerp(_transit_x1, _transit_x2, _transit_ease);
        var _transit_y = lerp(_transit_y1, _transit_y2, _transit_ease);
        var _transit_w = lerp(_transit_w1, _transit_w2, _transit_ease);
        var _transit_h = lerp(_transit_h1, _transit_h2, _transit_ease);
        if (_transit.kind == "metroid_to_ship") {
            // The cargo renderer takes over as soon as this explicit transit is
            // removed. Persist the transit position so it inherits the endpoint
            // instead of lerping a second time from the old SR388 position.
            _transit.card.ui_x = _transit_x;
            _transit.card.ui_y = _transit_y;
            _transit.card.ui_position_initialized = true;
            _transit.card.ui_zone = _transit.player_index
                == game_state.view_player
                ? "active_cargo"
                : "opponent_cargo";
            _transit.card.ui_move_after_ms = 0;
        }
        if (_transit.kind == "metroid_to_lab"
        || _transit.kind == "metroid_to_ship") {
            _draw_metroid(
                _transit.card,
                _transit_x,
                _transit_y,
                _transit_w,
                _transit_h
            );
        } else {
            _draw_card(
                _transit.card,
                _transit_x,
                _transit_y,
                _transit_w,
                _transit_h,
                true
            );
        }
    }

    // A breached Metroid emerges from the closed Lab edge, hangs above it while
    // its owner chooses a Character, then retreats toward SR388.
    for (var _breach_draw_index = 0;
         _breach_draw_index < array_length(presentation_breaches);
         _breach_draw_index++) {
        var _breach = presentation_breaches[_breach_draw_index];
        var _breach_is_view_player = _breach.player_index
            == game_state.view_player;
        var _breach_screen_w = min(
            120,
            (_breach_is_view_player ? _lab_tab_w : _opponent_lab_tab_w) - 12
        );
        var _breach_screen_h = floor(_breach_screen_w * 1.4);
        var _breach_screen_x = _breach_is_view_player
            ? _lab_tab_x + ((_lab_tab_w - _breach_screen_w) * 0.5)
            : _opponent_lab_tab_x
                + ((_opponent_lab_tab_w - _breach_screen_w) * 0.5);
        var _breach_start_screen_y = _breach_is_view_player
            ? _lab_closed_y + _lab_tab_h + 5
            : _opponent_lab_closed_y - _breach_screen_h - 5;
        var _breach_hover_screen_y = _breach_is_view_player
            ? _lab_closed_y - _breach_screen_h - 18
            : _opponent_lab_closed_y + _opponent_lab_tab_h + 18;
        var _breach_start_x = board_camera_x
            + (_breach_screen_x / max(0.01, board_camera_zoom));
        var _breach_start_y = board_camera_y
            + ((_breach_start_screen_y - _header_h)
                / max(0.01, board_camera_zoom));
        var _breach_hover_x = board_camera_x
            + (_breach_screen_x / max(0.01, board_camera_zoom));
        var _breach_hover_y = board_camera_y
            + ((_breach_hover_screen_y - _header_h)
                / max(0.01, board_camera_zoom));
        var _breach_w = _breach_screen_w / max(0.01, board_camera_zoom);
        var _breach_h = _breach_screen_h / max(0.01, board_camera_zoom);
        var _breach_emerge_t = clamp(
            (current_time - _breach.started_at_ms)
                / max(1, _breach.emerge_duration_ms),
            0,
            1
        );
        var _breach_emerge_ease = 1 - power(1 - _breach_emerge_t, 3);
        var _breach_sway = sin(
            (current_time - _breach.started_at_ms) / 170
        ) * (9 / max(0.01, board_camera_zoom));
        var _breach_bob = sin(
            (current_time - _breach.started_at_ms) / 260
        ) * (4 / max(0.01, board_camera_zoom));
        var _breach_x = lerp(
            _breach_start_x,
            _breach_hover_x,
            _breach_emerge_ease
        ) + (_breach_sway * _breach_emerge_ease);
        var _breach_y = lerp(
            _breach_start_y,
            _breach_hover_y,
            _breach_emerge_ease
        ) + (_breach_bob * _breach_emerge_ease);
        if (_breach.return_started_at_ms >= 0
        && current_time >= _breach.return_started_at_ms) {
            var _breach_return_t = clamp(
                (current_time - _breach.return_started_at_ms)
                    / max(1, _breach.return_duration_ms),
                0,
                1
            );
            var _breach_return_ease = _breach_return_t
                * _breach_return_t * (3 - (2 * _breach_return_t));
            _breach_x = lerp(
                _breach_hover_x + _breach_sway,
                _sr_planet_x - (_breach_w * 0.5),
                _breach_return_ease
            );
            _breach_y = lerp(
                _breach_hover_y + _breach_bob,
                _sr_planet_y - (_breach_h * 0.5),
                _breach_return_ease
            );
            draw_set_alpha(1 - power(_breach_return_t, 3));
        }
        _draw_metroid(
            _breach.card,
            _breach_x,
            _breach_y,
            _breach_w,
            _breach_h
        );
        draw_set_alpha(1);
    }

    // Destroyed cards burn to white, then the white silhouette disappears. The
    // rules state has already removed the card; this queue preserves only its last
    // visible position long enough to communicate destruction.
    for (var _destruction_draw_index = 0;
         _destruction_draw_index < array_length(presentation_card_destructions);
         _destruction_draw_index++) {
        var _destruction = presentation_card_destructions[_destruction_draw_index];
        var _destruction_t = clamp(
            (current_time - _destruction.started_at_ms)
                / max(1, _destruction.duration_ms),
            0,
            1
        );
        if (_destruction_t < 0.5) {
            draw_set_alpha(1);
            _draw_card(
                _destruction.card,
                _destruction.x,
                _destruction.y,
                _destruction.width,
                _destruction.height,
                _destruction.rotate_ship,
                false
            );
        }
        var _destruction_white_alpha = _destruction_t < 0.5
            ? _destruction_t / 0.5
            : 1 - ((_destruction_t - 0.5) / 0.5);
        draw_set_alpha(clamp(_destruction_white_alpha, 0, 1));
        draw_set_color(c_white);
        draw_rectangle(
            _destruction.x,
            _destruction.y,
            _destruction.x + _destruction.width,
            _destruction.y + _destruction.height,
            false
        );
        draw_set_alpha(1);
    }

    matrix_set(matrix_world, _world_matrix_before);
    gpu_set_scissor(
        0,
        _header_h,
        board_viewport_right,
        max(1, _screen_height - _header_h)
    );
    var _hand_hud_region_start = array_length(ui_hit_regions);
    var _deck_pile_screen_x = (_deck_pile_x - board_camera_x)
        * board_camera_zoom;
    var _deck_pile_screen_y = _header_h
        + ((_pile_y - board_camera_y) * board_camera_zoom);

    // The hand sits below the board rather than occupying its own panel. Cards
    // peek over the screen edge and rise into view on hover or selection.
    var _hand_count = max(1, array_length(_active_player.hand));
    var _hand_slot_w = min(
        120,
        floor((board_viewport_right - _main_left - 280) / _hand_count)
    );
    var _hand_card_w = 145;
    var _hand_card_h = 203;
    var _hand_total_w = _hand_slot_w * array_length(_active_player.hand);
    var _hand_start_x = floor(
        (board_viewport_right - _hand_total_w) * 0.5
    );
    for (var _hand_index = 0;
         _hand_index < array_length(_active_player.hand);
         _hand_index++) {
        if (presentation_opening_active
        && presentation_opening_frame < 78 + (_hand_index * 6)) {
            continue;
        }
        var _hand_target_x = _hand_start_x
            + (_hand_index * _hand_slot_w)
            - floor(_hand_card_w * 0.5);
        var _hand_raised =
            (ui_selected_kind == "hand" && _hand_index == ui_selected_index)
            || (ui_hover_kind == "hand" && _hand_index == ui_hover_index)
            || (ui_context_preview_kind == "hand"
                && _hand_index == ui_context_preview_index
                && current_time < ui_context_preview_until_ms)
            || (!is_undefined(pending_choice)
                && pending_choice.kind == "hand_refresh"
                && raid_array_contains(
                    pending_choice.selected_indices,
                    _hand_index
                ));
        var _hand_target_y = _hand_raised
            ? _screen_height - _margin - _hand_card_h - 6
            : _screen_height - _margin - 46;
        var _hand_card = _active_player.hand[_hand_index];
        var _hand_starts_on_deck = _hand_card.ui_force_deck_origin
            || _hand_card.ui_zone == "";
        if (_hand_starts_on_deck) {
            _hand_card.ui_face_down_until_move = true;
        }
        if (_hand_card.ui_force_deck_origin) {
            _hand_card.ui_x = _deck_pile_screen_x;
            _hand_card.ui_y = _deck_pile_screen_y;
            _hand_card.ui_position_initialized = true;
            _hand_card.ui_force_deck_origin = false;
        }
        var _hand_position = _get_lerped_board_position(
            _hand_card,
            _hand_target_x,
            _hand_target_y,
            _deck_pile_screen_x,
            _deck_pile_screen_y,
            "active_hand",
            120
        );
        var _hand_x = _hand_position.x;
        var _hand_y = _hand_position.y;
        var _hand_face_down = _hand_card.ui_face_down_until_move
            && current_time < max(
                _hand_card.ui_move_after_ms,
                _hand_card.ui_hold_until_ms
            );
        if (_hand_face_down) {
            _draw_dealt_card_back(
                _hand_x,
                _hand_y,
                _hand_card_w,
                _hand_card_h
            );
        } else {
            _hand_card.ui_face_down_until_move = false;
            _draw_card(
                _hand_card,
                _hand_x,
                _hand_y,
                _hand_card_w,
                _hand_card_h,
                true
            );
            if (ui_gameplay_input_enabled
            && is_undefined(pending_choice)
            && game_state.priority_player == game_state.view_player
            && can_play_hand_card(_hand_index)) {
                _draw_playability_line(
                    _hand_x,
                    _hand_y,
                    _hand_card_w,
                    0,
                    1
                );
            }
            _add_hit_region(
                "hand",
                _hand_index,
                _hand_card,
                _hand_x,
                _hand_y,
                _hand_card_w,
                _hand_card_h
            );
        }
        if ((ui_selected_kind == "hand" && _hand_index == ui_selected_index)
        || (ui_hover_kind == "hand" && _hand_index == ui_hover_index)) {
            _draw_selection(
                _hand_x,
                _hand_y,
                _hand_card_w,
                _hand_card_h,
                ui_selected_kind == "hand" && _hand_index == ui_selected_index
            );
        }
        if (!is_undefined(pending_choice)
        && pending_choice.kind == "hand_refresh") {
            draw_set_color(
                raid_array_contains(
                    pending_choice.selected_indices,
                    _hand_index
                )
                    ? ui_color_selected
                    : ui_color_success
            );
            draw_rectangle(
                _hand_x - 3,
                _hand_y - 3,
                _hand_x + _hand_card_w + 3,
                _hand_y + _hand_card_h + 3,
                true
            );
        }
    }
    for (var _hand_hud_region_index = _hand_hud_region_start;
         _hand_hud_region_index < array_length(ui_hit_regions);
         _hand_hud_region_index++) {
        ui_hit_regions[_hand_hud_region_index].screen_space = true;
    }

    matrix_set(matrix_world, _world_matrix_before);
    gpu_set_scissor(0, 0, _screen_width, _screen_height);
    for (var _world_region_index = _world_hit_region_start;
         _world_region_index < array_length(ui_hit_regions);
         _world_region_index++) {
        var _world_region = ui_hit_regions[_world_region_index];
        if (variable_struct_exists(_world_region, "screen_space")
        && _world_region.screen_space) {
            continue;
        }
        _world_region.x1 = (_world_region.x1 - board_camera_x)
            * board_camera_zoom;
        _world_region.x2 = (_world_region.x2 - board_camera_x)
            * board_camera_zoom;
        _world_region.y1 = _header_h
            + ((_world_region.y1 - board_camera_y) * board_camera_zoom);
        _world_region.y2 = _header_h
            + ((_world_region.y2 - board_camera_y) * board_camera_zoom);
        _world_region.world_space = true;
        // Write the converted struct back explicitly. After an application-
        // surface resize, later screen-space consumers (notably contextual
        // button anchoring) must never observe the pre-camera world coordinates.
        ui_hit_regions[_world_region_index] = _world_region;
    }

    // Resolve the selected instance separately from hover so actions never change
    // just because the pointer moved across another card.
    var _actual_selected_kind = ui_selected_kind;
    var _actual_selected_index = ui_selected_index;
    var _raid_hover_context = !is_undefined(pending_choice)
        && pending_choice.kind == "raid"
        && (pending_choice.stage == "attackers"
            || pending_choice.stage == "defenders");
    var _hover_can_supply_context =
        ui_hover_kind == "shop"
        || ui_hover_kind == "hand"
        || ui_hover_kind == "ship"
        || ui_hover_kind == "character"
        || ui_hover_kind == "location"
        || (_raid_hover_context
            && (ui_hover_kind == "opponent_ship"
                || ui_hover_kind == "opponent_character"
                || ui_hover_kind == "opponent_location"));
    if (_hover_can_supply_context) {
        ui_context_preview_kind = ui_hover_kind;
        ui_context_preview_index = ui_hover_index;
        ui_context_preview_until_ms = ui_hover_kind == "hand"
            ? current_time + 120
            : 0;
        ui_selected_kind = ui_context_preview_kind;
        ui_selected_index = ui_context_preview_index;
    } else if ((ui_hover_kind == "action"
        || ui_hover_kind == "context_bridge")
    && ui_hover_action_has_context
        && ui_context_preview_kind != "") {
        if (ui_context_preview_kind == "hand") {
            ui_context_preview_until_ms = current_time + 120;
        }
        ui_selected_kind = ui_context_preview_kind;
        ui_selected_index = ui_context_preview_index;
    } else if (ui_context_preview_kind == "hand"
    && current_time < ui_context_preview_until_ms) {
        ui_selected_kind = ui_context_preview_kind;
        ui_selected_index = ui_context_preview_index;
    } else {
        ui_context_preview_kind = "";
        ui_context_preview_index = -1;
        ui_context_preview_until_ms = 0;
    }

    var _selected_instance = undefined;
    var _selected_is_metroid = false;
    switch (ui_selected_kind) {
        case "shop":
            if (ui_selected_index >= 0
            && ui_selected_index < array_length(game_state.shop_row)) {
                _selected_instance = game_state.shop_row[ui_selected_index];
            }
            break;

        case "hand":
            if (ui_selected_index >= 0
            && ui_selected_index < array_length(_active_player.hand)) {
                _selected_instance = _active_player.hand[ui_selected_index];
            }
            break;

        case "discard":
            if (ui_selected_index >= 0
            && ui_selected_index < array_length(_active_player.discard)) {
                _selected_instance = _active_player.discard[ui_selected_index];
            }
            break;

        case "ship":
            if (ui_selected_index >= 0
            && ui_selected_index < array_length(_active_player.board.ships)) {
                _selected_instance = _active_player.board.ships[ui_selected_index];
            }
            break;

        case "character":
            if (ui_selected_index >= 0
            && ui_selected_index < array_length(_active_player.board.characters)) {
                _selected_instance = _active_player.board.characters[
                    ui_selected_index
                ];
            }
            break;

        case "location":
            if (ui_selected_index >= 0
            && ui_selected_index < array_length(_active_player.board.locations)) {
                _selected_instance = _active_player.board.locations[
                    ui_selected_index
                ];
            }
            break;

        case "opponent_character":
            if (ui_selected_index >= 0
            && ui_selected_index < array_length(_opponent.board.characters)) {
                _selected_instance = _opponent.board.characters[ui_selected_index];
            }
            break;

        case "opponent_ship":
            if (ui_selected_index >= 0
            && ui_selected_index < array_length(_opponent.board.ships)) {
                _selected_instance = _opponent.board.ships[ui_selected_index];
            }
            break;

        case "opponent_location":
            if (ui_selected_index >= 0
            && ui_selected_index < array_length(_opponent.board.locations)) {
                _selected_instance = _opponent.board.locations[ui_selected_index];
            }
            break;

        case "opponent_discard":
            if (ui_selected_index >= 0
            && ui_selected_index < array_length(_opponent.discard)) {
                _selected_instance = _opponent.discard[ui_selected_index];
            }
            break;

        case "opponent_lab":
            _selected_is_metroid = true;
            if (ui_selected_index >= 0
            && ui_selected_index < array_length(_opponent.lab)) {
                _selected_instance = _opponent.lab[ui_selected_index];
            }
            break;

        case "opponent_cargo":
            _selected_is_metroid = true;
            if (ui_selected_index >= 0
            && ui_selected_index < array_length(_opponent.board.ships)
            && array_length(
                _opponent.board.ships[ui_selected_index].cargo
            ) > 0) {
                _selected_instance = _opponent.board.ships[
                    ui_selected_index
                ].cargo[0];
            }
            break;

        case "lab":
            _selected_is_metroid = true;
            if (ui_selected_index >= 0
            && ui_selected_index < array_length(_active_player.lab)) {
                _selected_instance = _active_player.lab[ui_selected_index];
            }
            break;

        case "cargo":
            _selected_is_metroid = true;
            if (ui_selected_index >= 0
            && ui_selected_index < array_length(_active_player.board.ships)
            && array_length(
                _active_player.board.ships[ui_selected_index].cargo
            ) > 0) {
                _selected_instance = _active_player.board.ships[
                    ui_selected_index
                ].cargo[0];
            }
            break;

        case "metroid":
            _selected_is_metroid = true;
            if (ui_selected_index == 4) {
                if (array_length(game_state.cavern) > 0) {
                    _selected_instance = game_state.cavern[
                        array_length(game_state.cavern) - 1
                    ];
                }
            } else if (ui_selected_index >= 0 && ui_selected_index < 4) {
                _selected_instance = game_state.sr388[ui_selected_index];
            }
            break;
    }

    var _detail_instance = !is_undefined(ui_hover_instance)
        ? ui_hover_instance
        : _selected_instance;
    var _detail_is_deck = ui_hover_kind == "deck";
    var _detail_kind = !is_undefined(ui_hover_instance)
        ? ui_hover_kind
        : ui_selected_kind;

    var _rail_right = _screen_width - _margin;
    var _hud_content_bottom = _screen_height - _margin;
    var _details_bottom = min(
        _content_top + max(110, floor(_screen_height * 0.44)),
        _hud_content_bottom - 310
    );
    var _mutation_hud_top = _details_bottom;
    var _mutation_hud_bottom = _mutation_hud_top + 54;
    var _action_top = _mutation_hud_bottom;
    // The permanent rail never needs more than two button rows. Card abilities
    // belong to their source cards, including during containment.
    var _action_bottom = _action_top + 106;
    var _log_top = _action_bottom;

    // Targeted card effects telegraph their locked source and target before rules
    // resolution changes either card's state or zone.
    if (!is_undefined(presentation_target_effect)) {
        var _effect_line_source_region = undefined;
        var _effect_line_target_region = undefined;
        for (var _effect_line_region_index = 0;
             _effect_line_region_index < array_length(ui_hit_regions);
             _effect_line_region_index++) {
            var _effect_line_region =
                ui_hit_regions[_effect_line_region_index];
            if (variable_struct_exists(_effect_line_region, "instance")
            && !is_undefined(_effect_line_region.instance)) {
                if (_effect_line_region.instance.instance_id
                == presentation_target_effect.source.instance_id) {
                    _effect_line_source_region = _effect_line_region;
                }
                if (_effect_line_region.instance.instance_id
                == presentation_target_effect.target.instance_id) {
                    _effect_line_target_region = _effect_line_region;
                }
            }
        }
        if (!is_undefined(_effect_line_source_region)
        && !is_undefined(_effect_line_target_region)) {
            var _effect_line_source_x =
                (_effect_line_source_region.x1
                    + _effect_line_source_region.x2) * 0.5;
            var _effect_line_source_y =
                (_effect_line_source_region.y1
                    + _effect_line_source_region.y2) * 0.5;
            var _effect_line_target_x =
                (_effect_line_target_region.x1
                    + _effect_line_target_region.x2) * 0.5;
            var _effect_line_target_y =
                (_effect_line_target_region.y1
                    + _effect_line_target_region.y2) * 0.5;
            var _effect_line_progress = clamp(
                (current_time - presentation_target_effect.started_at_ms)
                    / max(
                        1,
                        presentation_target_effect.resolve_at_ms
                            - presentation_target_effect.started_at_ms
                    ),
                0,
                1
            );
            var _effect_line_alpha = 0.72
                + (0.28 * sin(_effect_line_progress * pi * 5));
            draw_set_alpha(_effect_line_alpha);
            draw_set_color(make_color_rgb(74, 48, 5));
            draw_line_width(
                _effect_line_source_x,
                _effect_line_source_y,
                _effect_line_target_x,
                _effect_line_target_y,
                10
            );
            draw_set_color(make_color_rgb(255, 218, 72));
            draw_line_width(
                _effect_line_source_x,
                _effect_line_source_y,
                _effect_line_target_x,
                _effect_line_target_y,
                6
            );
            draw_circle(
                _effect_line_source_x,
                _effect_line_source_y,
                7,
                false
            );
            draw_circle(
                _effect_line_target_x,
                _effect_line_target_y,
                7,
                false
            );
            draw_set_alpha(1);
        }
    }

    // Make the two Ships involved in the current raid visually unambiguous.
    // Resolve their screen positions by instance rather than by player-facing
    // region names so this remains correct in hotseat and fixed-view modes.
    if (!is_undefined(pending_choice)
    && pending_choice.kind == "raid"
    && pending_choice.defender_ship_index >= 0) {
        var _raid_line_attacker_player =
            game_state.players[game_state.active_player];
        var _raid_line_defender_player =
            game_state.players[1 - game_state.active_player];
        if (pending_choice.attacker_ship_index >= 0
        && pending_choice.attacker_ship_index
        < array_length(_raid_line_attacker_player.board.ships)
        && pending_choice.defender_ship_index
        < array_length(_raid_line_defender_player.board.ships)) {
            var _raid_line_attacker =
                _raid_line_attacker_player.board.ships[
                    pending_choice.attacker_ship_index
                ];
            var _raid_line_defender =
                _raid_line_defender_player.board.ships[
                    pending_choice.defender_ship_index
                ];
            var _raid_line_source_region = undefined;
            var _raid_line_target_region = undefined;
            for (var _raid_line_region_index = 0;
                 _raid_line_region_index < array_length(ui_hit_regions);
                 _raid_line_region_index++) {
                var _raid_line_region = ui_hit_regions[_raid_line_region_index];
                if ((_raid_line_region.kind == "ship"
                    || _raid_line_region.kind == "opponent_ship")
                && variable_struct_exists(_raid_line_region, "instance")
                && !is_undefined(_raid_line_region.instance)) {
                    if (_raid_line_region.instance.instance_id
                    == _raid_line_attacker.instance_id) {
                        _raid_line_source_region = _raid_line_region;
                    } else if (_raid_line_region.instance.instance_id
                    == _raid_line_defender.instance_id) {
                        _raid_line_target_region = _raid_line_region;
                    }
                }
            }
            if (!is_undefined(_raid_line_source_region)
            && !is_undefined(_raid_line_target_region)) {
                var _raid_line_source_x =
                    (_raid_line_source_region.x1
                    + _raid_line_source_region.x2) * 0.5;
                var _raid_line_source_y =
                    (_raid_line_source_region.y1
                    + _raid_line_source_region.y2) * 0.5;
                var _raid_line_target_x =
                    (_raid_line_target_region.x1
                    + _raid_line_target_region.x2) * 0.5;
                var _raid_line_target_y =
                    (_raid_line_target_region.y1
                    + _raid_line_target_region.y2) * 0.5;

                draw_set_alpha(0.85);
                draw_set_color(make_color_rgb(30, 4, 7));
                draw_line_width(
                    _raid_line_source_x,
                    _raid_line_source_y,
                    _raid_line_target_x,
                    _raid_line_target_y,
                    10
                );
                draw_set_alpha(1);
                draw_set_color(ui_color_error);
                draw_line_width(
                    _raid_line_source_x,
                    _raid_line_source_y,
                    _raid_line_target_x,
                    _raid_line_target_y,
                    6
                );
                draw_circle(
                    _raid_line_source_x,
                    _raid_line_source_y,
                    7,
                    false
                );
                draw_circle(
                    _raid_line_target_x,
                    _raid_line_target_y,
                    7,
                    false
                );
            }
        }
    }

    draw_set_color(ui_color_hud_line);
    draw_line(
        _log_left + 10,
        _details_bottom,
        _rail_right - 10,
        _details_bottom
    );
    draw_set_color(ui_color_title);
    draw_set_font(FNT_METROID);
    draw_text(_log_left + 10, _content_top + 7, "DETAILS");
    draw_set_font(-1);
    if (_detail_is_deck) {
        var _detail_deck = _active_player.deck;
        var _deck_ids = [];
        var _deck_counts = [];
        for (var _deck_card_index = 0;
             _deck_card_index < array_length(_detail_deck);
             _deck_card_index++) {
            var _deck_card_id = string(
                _detail_deck[_deck_card_index].definition.name
            );
            var _deck_found_index = -1;
            for (var _deck_id_index = 0;
                 _deck_id_index < array_length(_deck_ids);
                 _deck_id_index++) {
                if (_deck_ids[_deck_id_index] == _deck_card_id) {
                    _deck_found_index = _deck_id_index;
                    break;
                }
            }
            if (_deck_found_index >= 0) {
                _deck_counts[_deck_found_index] += 1;
            } else {
                array_push(_deck_ids, _deck_card_id);
                array_push(_deck_counts, 1);
            }
        }

        // Alphabetize the manifest so it reveals deck contents, never deck order.
        for (var _deck_sort_a = 0;
             _deck_sort_a < array_length(_deck_ids) - 1;
             _deck_sort_a++) {
            for (var _deck_sort_b = _deck_sort_a + 1;
                 _deck_sort_b < array_length(_deck_ids);
                 _deck_sort_b++) {
                if (string_lower(_deck_ids[_deck_sort_b])
                < string_lower(_deck_ids[_deck_sort_a])) {
                    var _deck_swap_id = _deck_ids[_deck_sort_a];
                    var _deck_swap_count = _deck_counts[_deck_sort_a];
                    _deck_ids[_deck_sort_a] = _deck_ids[_deck_sort_b];
                    _deck_counts[_deck_sort_a] = _deck_counts[_deck_sort_b];
                    _deck_ids[_deck_sort_b] = _deck_swap_id;
                    _deck_counts[_deck_sort_b] = _deck_swap_count;
                }
            }
        }

        var _deck_detail_x = _log_left + 12;
        var _deck_detail_y = _content_top + 38;
        draw_set_color(ui_color_text);
        draw_text(
            _deck_detail_x,
            _deck_detail_y,
            "DECK - " + string(array_length(_detail_deck)) + " CARDS"
        );
        draw_set_color(ui_color_muted);
        draw_text(
            _deck_detail_x,
            _deck_detail_y + 27,
            "CONTENTS - ORDER HIDDEN"
        );

        var _deck_unique_count = array_length(_deck_ids);
        if (_deck_unique_count <= 0) {
            draw_text(_deck_detail_x, _deck_detail_y + 65, "Deck is empty.");
        } else {
            var _deck_column_count = 1;
            var _deck_rows_per_column = _deck_unique_count;
            var _deck_list_y = _deck_detail_y + 65;
            var _deck_available_height = _details_bottom
                - _deck_list_y - 10;
            var _deck_line_height = min(
                17,
                _deck_available_height / max(1, _deck_rows_per_column)
            );
            var _deck_text_scale = clamp(_deck_line_height / 20, 0.48, 0.78);
            var _deck_column_width = (_log_w - 24) / _deck_column_count;
            for (var _deck_list_index = 0;
                 _deck_list_index < _deck_unique_count;
                 _deck_list_index++) {
                var _deck_column = floor(
                    _deck_list_index / _deck_rows_per_column
                );
                var _deck_row = _deck_list_index mod _deck_rows_per_column;
                var _deck_entry = _deck_ids[_deck_list_index];
                if (_deck_counts[_deck_list_index] > 1) {
                    _deck_entry += " x" + string(_deck_counts[_deck_list_index]);
                }
                draw_text_transformed(
                    _deck_detail_x + (_deck_column * _deck_column_width),
                    _deck_list_y + (_deck_row * _deck_line_height),
                    _deck_entry,
                    _deck_text_scale,
                    _deck_text_scale,
                    0
                );
            }
        }
    } else if (!is_undefined(_detail_instance)) {
        var _detail_definition = _detail_instance.definition;
        var _detail_x = _log_left + 12;
        var _detail_y = _content_top + 38;
        var _detail_width = _log_w - 24;
        draw_set_color(ui_color_text);
        draw_text(_detail_x, _detail_y, _detail_definition.name);
        _detail_y += 30;

        var _detail_header = "";
        if (variable_struct_exists(_detail_definition, "costs")
        && !is_undefined(_detail_definition.costs)) {
            var _costs = _detail_definition.costs;
            if (variable_struct_exists(_costs, "deploy")
            && !is_undefined(_costs.deploy)) {
                _detail_header = "DEPLOY " + string(_costs.deploy);
            }
            if (variable_struct_exists(_costs, "reserve")
            && !is_undefined(_costs.reserve)) {
                if (_detail_header != "") {
                    _detail_header += "    ";
                }
                _detail_header += "RESERVE " + string(_costs.reserve);
            }
        }
        if (variable_struct_exists(_detail_definition, "stat")
        && !is_undefined(_detail_definition.stat)
        && variable_struct_exists(_detail_definition.stat, "kind")
        && !is_undefined(_detail_definition.stat.kind)
        && variable_struct_exists(_detail_definition.stat, "value")
        && !is_undefined(_detail_definition.stat.value)) {
            var _stat = _detail_definition.stat;
            if (_detail_header != "") {
                _detail_header += "    ";
            }
            var _detail_stat_value = get_card_stat(_detail_instance);
            _detail_header += string_upper(_stat.kind)
                + " " + string(_detail_stat_value);
        }
        if (_detail_header != "") {
            draw_set_color(ui_color_title);
            draw_text(_detail_x, _detail_y, _detail_header);
            _detail_y += 30;
        }
        if (variable_struct_exists(_detail_instance, "phazon_tokens")) {
            var _detail_phazon_danger = card_discards_from_phazon(
                _detail_instance
            );
            draw_set_color(
                _detail_phazon_danger ? ui_color_error : ui_color_title
            );
            draw_text(
                _detail_x,
                _detail_y,
                "PHAZON LEVEL " + string(_detail_instance.phazon_tokens)
            );
            _detail_y += 30;
        }

        var _has_effect = variable_struct_exists(_detail_definition, "effect")
            && !is_undefined(_detail_definition.effect)
            && string(_detail_definition.effect) != "";
        var _has_flavor = variable_struct_exists(_detail_definition, "flavor")
            && !is_undefined(_detail_definition.flavor)
            && string(_detail_definition.flavor) != "";
        var _flavor_y = _details_bottom - 12;
        if (_has_flavor) {
            var _flavor_text = string(_detail_definition.flavor);
            var _flavor_height = string_height_ext(
                _flavor_text,
                22,
                _detail_width
            );
            _flavor_y = max(
                _detail_y + 24,
                _details_bottom - _flavor_height - 12
            );
        }

        if (_has_effect) {
            draw_set_color(ui_color_muted);
            _draw_rich_text(
                _detail_x,
                _detail_y,
                _detail_definition.effect,
                _detail_width,
                (_has_flavor ? _flavor_y - 14 : _details_bottom - 12)
                    - _detail_y,
                22
            );
        } else if (!_has_flavor) {
            draw_set_color(ui_color_muted);
            draw_text(_detail_x, _detail_y, "No rules text.");
        }

        if (_has_flavor) {
            draw_set_color(ui_color_line);
            draw_text(_detail_x, _flavor_y - 22, "-----");
            draw_set_color(ui_color_muted);
            draw_text_ext(
                _detail_x,
                _flavor_y,
                _detail_definition.flavor,
                22,
                _detail_width
            );
        }
    } else {
        draw_set_color(ui_color_muted);
        draw_set_halign(fa_center);
        draw_text(
            _log_left + (_log_w * 0.5),
            _content_top + 178,
            "Hover over a card"
        );
        draw_text(
            _log_left + (_log_w * 0.5),
            _content_top + 202,
            "to inspect its details."
        );
        draw_set_halign(fa_left);
    }

    // Mutation is persistent match state, so give its track the full dashboard
    // width between inspection and interaction controls.
    var _hud_mutation_gap = 5;
    var _hud_mutation_available = _rail_right - _log_left - 20;
    var _hud_mutation_square = floor(
        (_hud_mutation_available
            - max(0, game_state.mutation_limit - 1) * _hud_mutation_gap)
        / max(1, game_state.mutation_limit)
    );
    _hud_mutation_square = min(
        _hud_mutation_square,
        _mutation_hud_bottom - _mutation_hud_top - 12
    );
    var _hud_mutation_width = game_state.mutation_limit
        * _hud_mutation_square
        + max(0, game_state.mutation_limit - 1) * _hud_mutation_gap;
    var _hud_mutation_x = _log_left
        + ((_rail_right - _log_left - _hud_mutation_width) * 0.5);
    var _hud_mutation_y = _mutation_hud_top
        + floor((_mutation_hud_bottom - _mutation_hud_top
            - _hud_mutation_square) * 0.5);
    for (var _hud_mutation_index = 0;
         _hud_mutation_index < game_state.mutation_limit;
         _hud_mutation_index++) {
        var _hud_mutation_cell_x = _hud_mutation_x
            + (_hud_mutation_index
                * (_hud_mutation_square + _hud_mutation_gap));
        draw_set_color(
            _hud_mutation_index < game_state.mutation
                ? ui_color_mutation
                : c_black
        );
        draw_rectangle(
            _hud_mutation_cell_x,
            _hud_mutation_y,
            _hud_mutation_cell_x + _hud_mutation_square,
            _hud_mutation_y + _hud_mutation_square,
            false
        );
        draw_set_color(make_color_rgb(92, 102, 112));
        draw_rectangle(
            _hud_mutation_cell_x,
            _hud_mutation_y,
            _hud_mutation_cell_x + _hud_mutation_square,
            _hud_mutation_y + _hud_mutation_square,
            true
        );
    }
    draw_set_color(ui_color_hud_line);
    draw_line(
        _log_left + 10,
        _mutation_hud_bottom,
        _rail_right - 10,
        _mutation_hud_bottom
    );
    var _button_gap = 8;
    var _button_w = floor((_log_w - 32 - _button_gap) * 0.5);
    var _button_h = 36;
    var _button_x1 = _log_left + 12;
    var _button_x2 = _button_x1 + _button_w + _button_gap;
    var _button_y = _action_top + 12;
    var _pane_button_w = _button_w;
    var _pane_button_x1 = _button_x1;
    var _pane_button_x2 = _button_x2;
    var _pane_button_y = _button_y;
    var _network_waiting_for_opponent = game_state.game_mode == "network"
        && network_local_player != network_expected_player()
        && game_state.phase != "game_over";
    context_button_source_kind = "";
    context_button_source_index = -1;
    var _raid_context_window = !is_undefined(pending_choice)
        && pending_choice.kind == "raid"
        && (pending_choice.stage == "attackers"
            || pending_choice.stage == "defenders");
    var _context_source_is_priority_card = !_raid_context_window
        || (!is_undefined(_selected_instance)
            && _selected_instance.controller == game_state.priority_player);
    if (!_network_waiting_for_opponent
    && (is_undefined(pending_choice) || _raid_context_window)
    && (game_state.phase == "action"
        || game_state.phase == "containment")
    && ui_selected_kind != ""
    && !is_undefined(_selected_instance)
    && _context_source_is_priority_card
    && !_selected_is_metroid
    && (game_state.phase != "containment"
        || array_length(get_activated_abilities(_selected_instance)) > 0)) {
        var _context_anchor_region = undefined;
        for (var _context_region_index = 0;
             _context_region_index < array_length(ui_hit_regions);
             _context_region_index++) {
            var _context_region = ui_hit_regions[_context_region_index];
            if (_context_region.kind == ui_selected_kind
            && _context_region.index == ui_selected_index
            && variable_struct_exists(_context_region, "instance")
            && !is_undefined(_context_region.instance)
            && _context_region.instance.instance_id
                == _selected_instance.instance_id) {
                _context_anchor_region = _context_region;
                break;
            }
        }
        if (!is_undefined(_context_anchor_region)) {
            context_button_source_kind = ui_selected_kind;
            context_button_source_index = ui_selected_index;
            _button_w = 108;
            var _context_total_w = (_button_w * 2) + _button_gap;
            var _context_center_x = (
                _context_anchor_region.x1 + _context_anchor_region.x2
            ) * 0.5;
            _button_x1 = clamp(
                _context_center_x - (_context_total_w * 0.5),
                _main_left + 4,
                board_viewport_right - _context_total_w - 4
            );
            _button_x2 = _button_x1 + _button_w + _button_gap;
            var _context_button_rows = 1;
            if (_raid_context_window) {
                _context_button_rows = min(
                    3,
                    array_length(get_activated_abilities(_selected_instance))
                );
                if (_selected_instance.definition.type == "character"
                && _selected_instance.ready) _context_button_rows += 1;
                if (can_salvage_permanent(
                    ui_selected_kind,
                    ui_selected_index
                )) _context_button_rows += 1;
                _context_button_rows = max(1, _context_button_rows);
            } else if (game_state.phase == "containment") {
                _context_button_rows = max(
                    1,
                    ceil(
                        min(
                            3,
                            array_length(
                                get_activated_abilities(_selected_instance)
                            )
                        ) / 2
                    )
                );
            } else if (ui_selected_kind == "ship") {
                _context_button_rows = array_length(
                    get_activated_abilities(_selected_instance)
                ) > 0 ? 3 : 2;
            } else if (ui_selected_kind == "character"
            || ui_selected_kind == "location") {
                _context_button_rows = max(
                    1,
                    min(3, array_length(
                        get_activated_abilities(_selected_instance)
                    )) + 1
                );
            }
            _button_y = max(
                _header_h + 4,
                _context_anchor_region.y1
                    - (_context_button_rows * (_button_h + 8))
                    - 4
            );
            // One continuous invisible region sits behind the entire control
            // cluster and the gap down to its card. Visible buttons are added
            // afterward and therefore retain click priority over this bridge.
            array_push(
                ui_hit_regions,
                {
                    kind: "context_bridge",
                    index: "",
                    instance: undefined,
                    x1: min(_button_x1, _context_anchor_region.x1),
                    y1: _button_y,
                    x2: max(
                        _button_x2 + _button_w,
                        _context_anchor_region.x2
                    ),
                    y2: _context_anchor_region.y1 + 4,
                    enabled: false,
                    action: "",
                    context_kind: context_button_source_kind,
                    context_index: context_button_source_index
                }
            );
        }
    }
    var _context_ability_count = is_undefined(_selected_instance)
        || _selected_is_metroid
        ? 0
        : array_length(get_activated_abilities(_selected_instance));
    var _draw_action_required_prompt = function(
        _prompt_text,
        _prompt_main_left,
        _prompt_main_right,
        _prompt_content_top,
        _prompt_screen_height
    ) {
        var _prompt_width = min(
            570,
            (_prompt_main_right - _prompt_main_left) - 40
        );
        var _prompt_x1 = floor(
            _prompt_main_left
                + (((_prompt_main_right - _prompt_main_left) - _prompt_width)
                    * 0.5)
        );
        var _prompt_y1 = _prompt_content_top + 28;
        var _prompt_x2 = _prompt_x1 + _prompt_width;
        var _prompt_body_width = _prompt_width - 20;
        var _prompt_line_spacing = 24;
        draw_set_font(FNT_METROID);
        var _prompt_body_height = string_height_ext(
            _prompt_text,
            _prompt_line_spacing,
            _prompt_body_width
        );
        var _prompt_y2 = min(
            _prompt_screen_height - 10,
            _prompt_y1 + max(108, 34 + _prompt_body_height + 12)
        );
        draw_set_alpha(0.84);
        draw_set_color(c_black);
        draw_rectangle(_prompt_x1, _prompt_y1, _prompt_x2, _prompt_y2, false);
        draw_set_alpha(0.28);
        draw_set_color(merge_color(c_black, ui_color_title, 0.60));
        draw_rectangle(_prompt_x1, _prompt_y1, _prompt_x2, _prompt_y2, false);
        draw_set_alpha(0.92);
        draw_set_color(ui_color_title);
        draw_rectangle(_prompt_x1, _prompt_y1, _prompt_x2, _prompt_y2, true);
        draw_set_alpha(1);
        draw_set_color(ui_color_title);
        var _prompt_header = "TRANSMISSION RECEIVED // ACTION REQUIRED";
        var _prompt_header_scale = min(
            1,
            (_prompt_width - 32) / max(1, string_width(_prompt_header))
        );
        draw_text_transformed(
            _prompt_x1 + 12,
            _prompt_y1 + 7,
            _prompt_header,
            _prompt_header_scale,
            1,
            0
        );
        draw_set_color(ui_color_text);
        draw_text_ext(
            _prompt_x1 + 10,
            _prompt_y1 + 34,
            _prompt_text,
            _prompt_line_spacing,
            _prompt_body_width
        );
    };

    if (_network_waiting_for_opponent) {
        _draw_action_button(
            "OPPONENT'S TURN",
            "",
            _pane_button_x1,
            _pane_button_y + 10,
            (_pane_button_w * 2) + _button_gap,
            _button_h + 18,
            false
        );
    } else if (!is_undefined(pending_choice)) {
        var _pending_prompt = variable_struct_exists(pending_choice, "prompt")
            ? pending_choice.prompt
            : "Complete the current choice.";
        if (pending_choice.kind == "hand_refresh") {
            _pending_prompt += "\n"
                + string(array_length(pending_choice.selected_indices))
                + " card(s) currently selected.";
        }
        if (pending_choice.kind == "ability_target"
        && variable_struct_exists(pending_choice, "multi_select")
        && pending_choice.multi_select) {
            _pending_prompt += "\nSelected Strength: "
                + string(pending_choice.selected_strength) + " / "
                + string(pending_choice.source.phazon_tokens
                    + pending_choice.selected_pz_bonus);
        }
        _draw_action_required_prompt(
            _pending_prompt,
            _main_left,
            _main_right,
            _content_top,
            _screen_height
        );

        // Keep both sides' current totals visible while a raid is being built.
        if (pending_choice.kind == "raid"
        || pending_choice.kind == "raid_cargo") {
            var _raid_attack_total = 0;
            var _raid_defense_total = 0;
            var _raid_defense_known = true;

            if (pending_choice.kind == "raid_cargo") {
                _raid_attack_total = pending_choice.attacker_total;
                _raid_defense_total = pending_choice.defender_total;
            } else {
                var _raid_attack_player =
                    game_state.players[game_state.active_player];
                var _raid_defense_player =
                    game_state.players[1 - game_state.active_player];

                _raid_attack_total = pending_choice.attacker_ability_bonus;
                if (pending_choice.attacker_ship_index >= 0
                && pending_choice.attacker_ship_index
                < array_length(_raid_attack_player.board.ships)) {
                    _raid_attack_total += get_card_stat(
                        _raid_attack_player.board.ships[
                            pending_choice.attacker_ship_index
                        ],
                        "raid_attacker_ship"
                    );
                }
                for (var _raid_attack_character_index = 0;
                     _raid_attack_character_index
                     < array_length(pending_choice.attacker_characters);
                     _raid_attack_character_index++) {
                    var _raid_attack_board_index =
                        pending_choice.attacker_characters[
                            _raid_attack_character_index
                        ];
                    if (_raid_attack_board_index >= 0
                    && _raid_attack_board_index
                    < array_length(_raid_attack_player.board.characters)) {
                        var _raid_attack_character =
                            _raid_attack_player.board.characters[
                                _raid_attack_board_index
                            ];
                        if (_raid_attack_character.ready) {
                            _raid_attack_total += get_card_stat(
                                _raid_attack_character,
                                "raid_character"
                            );
                        }
                    }
                }

                _raid_defense_known =
                    pending_choice.defender_ship_index >= 0
                    && pending_choice.defender_ship_index
                    < array_length(_raid_defense_player.board.ships);
                _raid_defense_total = pending_choice.defender_ability_bonus;
                if (_raid_defense_known) {
                    _raid_defense_total += get_card_stat(
                        _raid_defense_player.board.ships[
                            pending_choice.defender_ship_index
                        ],
                        "raid_defender_ship"
                    );
                }
                for (var _raid_defense_character_index = 0;
                     _raid_defense_character_index
                     < array_length(pending_choice.defender_characters);
                     _raid_defense_character_index++) {
                    var _raid_defense_board_index =
                        pending_choice.defender_characters[
                            _raid_defense_character_index
                        ];
                    if (_raid_defense_board_index >= 0
                    && _raid_defense_board_index
                    < array_length(_raid_defense_player.board.characters)) {
                        var _raid_defense_character =
                            _raid_defense_player.board.characters[
                                _raid_defense_board_index
                            ];
                        if (_raid_defense_character.ready) {
                            _raid_defense_total += get_card_stat(
                                _raid_defense_character,
                                "raid_character"
                            );
                        }
                    }
                }
            }

            var _raid_score_left = _log_left + 12;
            var _raid_score_right = _rail_right - 12;
            var _raid_score_top = _details_bottom - 38;
            var _raid_score_text_y = _raid_score_top + 16;
            var _raid_score_bottom = _raid_score_top + 36;
            var _raid_score_mid =
                floor((_raid_score_left + _raid_score_right) * 0.5);
            draw_set_alpha(0.94);
            draw_set_color(make_color_rgb(10, 15, 24));
            draw_rectangle(
                _raid_score_left,
                _raid_score_top,
                _raid_score_right,
                _raid_score_bottom,
                false
            );
            draw_set_alpha(1);
            draw_set_color(ui_color_line);
            draw_rectangle(
                _raid_score_left,
                _raid_score_top,
                _raid_score_right,
                _raid_score_bottom,
                true
            );
            draw_line(
                _raid_score_mid,
                _raid_score_top + 4,
                _raid_score_mid,
                _raid_score_bottom - 4
            );

            draw_set_font(FNT_METROID);
            draw_set_valign(fa_middle);
            draw_set_halign(fa_left);
            draw_set_color(make_color_rgb(255, 82, 82));
            draw_text(
                _raid_score_left + 8,
                _raid_score_text_y,
                "ATTACK"
            );
            draw_set_halign(fa_right);
            draw_text(
                _raid_score_mid - 8,
                _raid_score_text_y,
                string(_raid_attack_total)
            );

            draw_set_halign(fa_left);
            draw_set_color(make_color_rgb(80, 170, 255));
            draw_text(
                _raid_score_mid + 8,
                _raid_score_text_y,
                "DEFENSE"
            );
            draw_set_halign(fa_right);
            draw_text(
                _raid_score_right - 8,
                _raid_score_text_y,
                _raid_defense_known ? string(_raid_defense_total) : "--"
            );
            draw_set_font(-1);
            draw_set_halign(fa_left);
            draw_set_valign(fa_top);
        }

        if (pending_choice.kind == "queen_event"
        && pending_choice.stage == "resolved") {
            _draw_action_button(
                "CONTINUE",
                "finish_queen",
                _button_x1,
                _action_bottom - 48,
                (_button_w * 2) + _button_gap,
                _button_h,
                true
            );
        } else if (pending_choice.kind == "special_containment_ship") {
            var _special_ship_kind =
                pending_choice.player_index == game_state.active_player
                    ? "ship"
                    : "opponent_ship";
            var _special_ship_legal =
                ui_selected_kind == _special_ship_kind
                && !is_undefined(_selected_instance)
                && _selected_instance.ready;
            _draw_action_button(
                _special_ship_legal ? "USE SELECTED SHIP" : "NO SHIP",
                _special_ship_legal
                    ? "special_containment_use_ship"
                    : "special_containment_no_ship",
                _button_x1,
                _action_bottom - 48,
                (_button_w * 2) + _button_gap,
                _button_h,
                true
            );
        } else if (pending_choice.kind == "adam_breach") {
            _draw_action_button(
                "DESTROY ADAM",
                "adam_prevent_breach",
                _button_x1,
                _action_bottom - 48,
                _button_w,
                _button_h,
                true
            );
            _draw_action_button(
                "ALLOW BREACH",
                "adam_allow_breach",
                _button_x2,
                _action_bottom - 48,
                _button_w,
                _button_h,
                true
            );
        } else if (pending_choice.kind == "space_pirate_payment") {
            _draw_action_button(
                "PAY 1 CP",
                "space_pirate_pay",
                _button_x1,
                _action_bottom - 48,
                _button_w,
                _button_h,
                game_state.players[pending_choice.payer_index].command_points >= 1
            );
            _draw_action_button(
                "DECLINE",
                "space_pirate_decline",
                _button_x2,
                _action_bottom - 48,
                _button_w,
                _button_h,
                true
            );
        } else if (pending_choice.kind == "space_pirate_ready") {
            // Selection instruction is shown in the transmission panel.
        } else if (pending_choice.kind == "choose_faction") {
            var _faction_gap = 6;
            var _faction_third = floor(
                ((_button_w * 2) + _button_gap - (_faction_gap * 2)) / 3
            );
            _draw_action_button(
                "GF", "faction_gf",
                _button_x1, _action_bottom - 82,
                _faction_third, 32, true
            );
            _draw_action_button(
                "SP", "faction_sp",
                _button_x1 + _faction_third + _faction_gap,
                _action_bottom - 82,
                _faction_third, 32, true
            );
            _draw_action_button(
                "CZ", "faction_cz",
                _button_x1 + ((_faction_third + _faction_gap) * 2),
                _action_bottom - 82,
                _faction_third, 32, true
            );
            _draw_action_button(
                "BH", "faction_bh",
                _button_x1, _action_bottom - 42,
                _button_w,
                32, true
            );
            _draw_action_button(
                "PZ", "faction_pz",
                _button_x2, _action_bottom - 42,
                _button_w,
                32, true
            );
        } else if (pending_choice.kind == "researcher_discard") {
            // Selection instruction is shown in the transmission panel.
        } else if (pending_choice.kind == "torizo_metroid") {
            // Selection instruction is shown in the transmission panel.
        } else if (pending_choice.kind == "breach_character"
        || pending_choice.kind == "olympus_ready") {
            // Selection instruction is shown in the transmission panel.
        } else if (pending_choice.kind == "raid_cargo") {
            var _cargo_choice_ship = pending_choice.winner_is_attacker
                ? game_state.players[
                    1 - game_state.active_player
                ].board.ships[pending_choice.defender_ship_index]
                : game_state.players[
                    game_state.active_player
                ].board.ships[pending_choice.attacker_ship_index];
            var _cargo_choice_count = min(4, array_length(_cargo_choice_ship.cargo));
            for (var _cargo_choice_index = 0;
                 _cargo_choice_index < _cargo_choice_count;
                 _cargo_choice_index++) {
                var _cargo_choice_col = _cargo_choice_index mod 2;
                var _cargo_choice_row = floor(_cargo_choice_index / 2);
                _draw_action_button(
                    _cargo_choice_ship.cargo[
                        _cargo_choice_index
                    ].definition.name,
                    "raid_cargo_" + string(_cargo_choice_index),
                    _cargo_choice_col == 0 ? _button_x1 : _button_x2,
                    _action_bottom - 86 + (_cargo_choice_row * 40),
                    _button_w,
                    34,
                    true
                );
            }
        } else if (pending_choice.kind == "raid"
        && (pending_choice.stage == "attackers"
        || pending_choice.stage == "defenders")) {
            var _raid_source = _selected_instance;
            if (!is_undefined(_raid_source)
            && _raid_source.controller == game_state.priority_player
            && context_button_source_kind != "") {
                var _raid_source_kind = get_raid_source_kind(
                    ui_selected_kind, _raid_source
                );
                var _raid_abilities = get_activated_abilities(_raid_source);
                var _raid_button_row = 0;
                for (var _raid_ability_index = 0;
                     _raid_ability_index < min(3, array_length(_raid_abilities));
                     _raid_ability_index++) {
                    _draw_action_button(
                        _raid_abilities[_raid_ability_index].label,
                        "raid_use_" + string(_raid_ability_index),
                        _button_x1,
                        _button_y + _raid_button_row * (_button_h + 8),
                        (_button_w * 2) + _button_gap,
                        _button_h,
                        can_activate_selected_ability(
                            _raid_source_kind,
                            ui_selected_index,
                            _raid_ability_index
                        )
                    );
                    _raid_button_row += 1;
                }
                var _raid_is_character = _raid_source.definition.type
                    == "character";
                var _raid_contributors = pending_choice.stage == "attackers"
                    ? pending_choice.attacker_characters
                    : pending_choice.defender_characters;
                var _raid_is_contributing = _raid_is_character
                    && raid_array_contains(
                        _raid_contributors, ui_selected_index
                    );
                if (_raid_is_character
                && (_raid_source.ready || _raid_is_contributing)) {
                    _draw_action_button(
                        _raid_is_contributing
                            ? "REMOVE CONTRIBUTION"
                            : "EXHAUST: +" + string(get_card_stat(
                                _raid_source, "raid_character"
                            )) + " SECURITY",
                        "raid_contribute",
                        _button_x1,
                        _button_y + _raid_button_row * (_button_h + 8),
                        (_button_w * 2) + _button_gap,
                        _button_h,
                        true
                    );
                    _raid_button_row += 1;
                }
                if (can_salvage_permanent(
                    _raid_source_kind, ui_selected_index
                )) {
                    _draw_action_button(
                        "SALVAGE +" + string(get_salvage_refund(
                            _raid_source
                        )) + " CP",
                        "salvage",
                        _button_x1,
                        _button_y + _raid_button_row * (_button_h + 8),
                        (_button_w * 2) + _button_gap,
                        _button_h,
                        true
                    );
                }
            }
            _draw_action_button(
                pending_choice.stage == "attackers"
                    ? "LOCK ATTACKERS"
                    : "RESOLVE RAID",
                pending_choice.stage == "attackers"
                    ? "lock_raid_attackers"
                    : "resolve_raid",
                _pane_button_x1,
                _action_bottom - 48,
                (_pane_button_w * 2) + _button_gap,
                _button_h,
                true
            );
        } else if (pending_choice.kind == "ability_target"
        && variable_struct_exists(pending_choice, "multi_select")
        && pending_choice.multi_select) {
            _draw_action_button(
                "CANCEL",
                "cancel",
                _button_x1,
                _action_bottom - 48,
                _button_w,
                _button_h,
                true
            );
            _draw_action_button(
                "DISCARD SELECTED",
                "confirm_dark_samus_discard",
                _button_x1,
                _action_bottom - 48,
                (_button_w * 2) + _button_gap,
                _button_h,
                array_length(pending_choice.selected_targets) > 0
            );
        } else if (pending_choice.kind == "hand_refresh") {
            var _refresh_selection_count =
                array_length(pending_choice.selected_indices);
            _draw_action_button(
                "CANCEL",
                "cancel",
                _button_x1,
                _action_bottom - 48,
                _button_w,
                _button_h,
                true
            );
            _draw_action_button(
                "REFRESH SELECTED",
                "confirm_hand_refresh",
                _button_x2,
                _action_bottom - 48,
                _button_w,
                _button_h,
                _refresh_selection_count > 0
                    || array_length(_active_player.hand) < 5
            );
        } else {
            _draw_action_button(
                "CANCEL",
                "cancel",
                _button_x1,
                _action_bottom - 48,
                (_button_w * 2) + _button_gap,
                _button_h,
                true
            );
        }
    } else if (game_state.phase == "action") {
        if (ui_selected_kind == "shop") {
            var _can_reserve = false;
            var _can_deploy = false;
            if (!is_undefined(_selected_instance)) {
                var _reserve_cost = get_modified_reserve_cost(
                    _active_player,
                    _selected_instance
                );
                var _deploy_cost = get_modified_deploy_cost(
                    _active_player,
                    _selected_instance
                );
                if (is_real(_reserve_cost)) {
                    _can_reserve =
                        _active_player.command_points >= _reserve_cost;
                }
                _can_deploy = _selected_instance.definition.type != "event"
                    && is_real(_deploy_cost)
                    && _active_player.command_points >= _deploy_cost;
            }
            _draw_action_button(
                "DEPLOY",
                "deploy",
                _button_x1,
                _button_y,
                _button_w,
                _button_h,
                _can_deploy
            );
            _draw_action_button(
                "RESERVE",
                "reserve",
                _button_x2,
                _button_y,
                _button_w,
                _button_h,
                _can_reserve
            );
        } else if (ui_selected_kind == "hand") {
            var _can_play = can_play_hand_card(ui_selected_index);
            _draw_action_button(
                "PLAY",
                "play",
                _button_x1,
                _button_y,
                (_button_w * 2) + _button_gap,
                _button_h,
                _can_play
            );
        } else if (ui_selected_kind == "ship") {
            var _capture_cost = get_capture_cost(_active_player);
            var _capture_has_target = false;
            if (!is_undefined(_selected_instance)) {
                for (var _capture_source_index = 0;
                     _capture_source_index < 5;
                     _capture_source_index++) {
                    if (can_capture_metroid(
                        ui_selected_index,
                        _capture_source_index
                    )) {
                        _capture_has_target = true;
                        break;
                    }
                }
            }
            var _can_begin_capture = !is_undefined(_selected_instance)
                && _selected_instance.ready
                && array_length(_selected_instance.cargo) < 1
                && _active_player.command_points >= _capture_cost
                && _capture_has_target;
            var _ship_abilities = get_activated_abilities(_selected_instance);
            var _has_ship_ability = array_length(_ship_abilities) > 0;
            var _raid_cost = get_raid_cost(_active_player);
            var _can_raid = !is_undefined(_selected_instance)
                && _selected_instance.ready
                && array_length(_opponent.board.ships) > 0
                && _active_player.command_points >= _raid_cost;
            _draw_action_button(
                "CAPTURE - " + string(_capture_cost) + " CP",
                "capture",
                _button_x1,
                _button_y,
                _button_w,
                _button_h,
                _can_begin_capture
            );
            _draw_action_button(
                "RAID - " + string(_raid_cost) + " CP",
                "raid",
                _button_x2,
                _button_y,
                _button_w,
                _button_h,
                _can_raid
            );
            if (_has_ship_ability) {
                _draw_action_button(
                    _ship_abilities[0].label,
                    "activate_0",
                    _button_x1,
                    _button_y + _button_h + 8,
                    (_button_w * 2) + _button_gap,
                    _button_h,
                    can_activate_selected_ability(
                        "ship",
                        ui_selected_index,
                        0
                    )
                );
            }
            _draw_action_button(
                "SALVAGE +" + string(get_salvage_refund(_selected_instance)) + " CP",
                "salvage",
                _button_x1,
                _button_y + ((_button_h + 8) * (1 + _has_ship_ability)),
                (_button_w * 2) + _button_gap,
                _button_h,
                can_salvage_permanent("ship", ui_selected_index)
            );
        } else if (ui_selected_kind == "character"
        || ui_selected_kind == "location"
        || ui_selected_kind == "opponent_location") {
            var _selected_abilities = get_activated_abilities(_selected_instance);
            if (array_length(_selected_abilities) > 0) {
                _draw_action_button(
                    _selected_abilities[0].label,
                    "activate_0",
                    _button_x1,
                    _button_y,
                    (_button_w * 2) + _button_gap,
                    _button_h,
                    can_activate_selected_ability(
                        ui_selected_kind,
                        ui_selected_index,
                        0
                    )
                );
                if (array_length(_selected_abilities) > 1) {
                    _draw_action_button(
                        _selected_abilities[1].label,
                        "activate_1",
                        _button_x1,
                        _button_y + _button_h + 8,
                        (_button_w * 2) + _button_gap,
                        _button_h,
                        can_activate_selected_ability(
                            ui_selected_kind,
                            ui_selected_index,
                            1
                        )
                    );
                }
                if (array_length(_selected_abilities) > 2) {
                    _draw_action_button(
                        _selected_abilities[2].label,
                        "activate_2",
                        _button_x1,
                        _button_y + ((_button_h + 8) * 2),
                        (_button_w * 2) + _button_gap,
                        _button_h,
                        can_activate_selected_ability(
                            ui_selected_kind,
                            ui_selected_index,
                            2
                        )
                    );
                }
            }
            if (ui_selected_kind != "opponent_location") {
                _draw_action_button(
                    "SALVAGE +" + string(get_salvage_refund(_selected_instance)) + " CP",
                    "salvage",
                    _button_x1,
                    _button_y + ((_button_h + 8) * array_length(_selected_abilities)),
                    (_button_w * 2) + _button_gap,
                    _button_h,
                    can_salvage_permanent(ui_selected_kind, ui_selected_index)
                );
            }
        }

        // Global turn controls stay in the Actions pane. Contextual controls are
        // drawn over their source card and do not replace these.
        context_button_source_kind = "";
        context_button_source_index = -1;
        _draw_action_button(
            "REFRESH HAND",
            "refresh_hand",
            _pane_button_x1,
            _pane_button_y,
            _pane_button_w,
            _button_h,
            _active_player.command_points >= 1
        );
        _draw_action_button(
            "REFRESH SHOP",
            "refresh_shop",
            _pane_button_x2,
            _pane_button_y,
            _pane_button_w,
            _button_h,
            _active_player.command_points >= 1
        );
        _draw_action_button(
            "END TURN",
            "end_turn",
            _pane_button_x1,
            _pane_button_y + _button_h + 10,
            (_pane_button_w * 2) + _button_gap,
            _button_h,
            true
        );
    } else if (game_state.phase == "containment") {
        _draw_action_required_prompt(
            "Select a ready Ship to contribute its Security to Containment, "
                + "or choose NO SHIP.",
            _main_left,
            _main_right,
            _content_top,
            _screen_height
        );
        var _containment_ship_legal = ui_selected_kind == "ship"
            && !is_undefined(_selected_instance)
            && _selected_instance.ready;
        var _containment_abilities = [];
        if (!is_undefined(_selected_instance)
        && !_selected_is_metroid
        && (ui_selected_kind == "ship"
            || ui_selected_kind == "character"
            || ui_selected_kind == "location")) {
            _containment_abilities = get_activated_abilities(_selected_instance);
        }
        if (array_length(_containment_abilities) > 0) {
            for (var _containment_ability_index = 0;
                 _containment_ability_index
                    < min(3, array_length(_containment_abilities));
                 _containment_ability_index++) {
                var _containment_ability_row =
                    floor(_containment_ability_index / 2);
                var _containment_ability_column =
                    _containment_ability_index mod 2;
                _draw_action_button(
                    _containment_abilities[_containment_ability_index].label,
                    "activate_" + string(_containment_ability_index),
                    _containment_ability_column == 0
                        ? _button_x1
                        : _button_x2,
                    _button_y + (_containment_ability_row * (_button_h + 8)),
                    _button_w,
                    _button_h,
                    can_activate_selected_ability(
                        ui_selected_kind,
                        ui_selected_index,
                        _containment_ability_index
                    )
                );
            }
        }
        _draw_action_button(
            _containment_ship_legal ? "USE SELECTED SHIP" : "NO SHIP",
            _containment_ship_legal
                ? "containment_use_ship"
                : "containment_no_ship",
            _pane_button_x1,
            _action_bottom - 48,
            (_pane_button_w * 2) + _button_gap,
            _button_h,
            true
        );
    } else if (game_state.phase == "game_over") {
        _draw_action_button(
            "RESTART",
            "restart",
            _button_x1,
            _button_y,
            (_button_w * 2) + _button_gap,
            _button_h,
            true
        );
    } else if (game_state.phase == "mutation"
    || (game_state.phase == "pass_turn"
        && presentation_evolution_until_ms > current_time)) {
        // Evolution advances after its presentation timer. It is deliberately
        // non-interactive so the animation cannot be skipped.
    } else {
        draw_set_color(ui_color_muted);
        draw_text(
            _log_left + 12,
            _button_y,
            "Resolve: " + string_upper(game_state.phase)
        );
        _draw_action_button(
            "ADVANCE PHASE",
            "advance_phase",
            _button_x1,
            _button_y + 32,
            (_button_w * 2) + _button_gap,
            _button_h,
            true
        );
    }

    ui_selected_kind = _actual_selected_kind;
    ui_selected_index = _actual_selected_index;
    context_button_source_kind = "";
    context_button_source_index = -1;

    draw_set_color(ui_color_hud_line);
    draw_line(_log_left + 10, _log_top, _rail_right - 10, _log_top);
    draw_set_color(ui_color_title);
    draw_set_font(FNT_METROID);
    draw_text(_log_left + 10, _log_top + 7, "RECENT EVENTS");
    draw_set_font(-1);
    var _diagnostic_y = _log_top + 36;
    if (array_length(load_errors) > 0 || array_length(setup_errors) > 0) {
        draw_set_color(ui_color_error);
        draw_text(_log_left + 12, _diagnostic_y, "STATE ERRORS");
        _diagnostic_y += 23;
        for (var _load_error_index = 0;
             _load_error_index < array_length(load_errors);
             _load_error_index++) {
            var _load_error_text = "LOAD: " + string(load_errors[_load_error_index]);
            draw_text_ext(
                _log_left + 12,
                _diagnostic_y,
                _load_error_text,
                15,
                _log_w - 30
            );
            _diagnostic_y += max(
                22,
                string_height_ext(_load_error_text, 15, _log_w - 30)
            ) + 6;
        }
        for (var _setup_error_index = 0;
             _setup_error_index < array_length(setup_errors);
             _setup_error_index++) {
            var _setup_error_text = "SETUP: "
                + string(setup_errors[_setup_error_index]);
            draw_text_ext(
                _log_left + 12,
                _diagnostic_y,
                _setup_error_text,
                15,
                _log_w - 30
            );
            _diagnostic_y += max(
                22,
                string_height_ext(_setup_error_text, 15, _log_w - 30)
            ) + 6;
        }
        draw_set_color(ui_color_hud_line);
        draw_line(
            _log_left + 12,
            _diagnostic_y,
            _rail_right - 12,
            _diagnostic_y
        );
        _diagnostic_y += 8;
    } else {
        draw_set_color(ui_color_success);
        draw_text(_log_left + 12, _diagnostic_y, "State checks passed.");
        _diagnostic_y += 27;
    }

    var _chat_field_h = 40;
    var _chat_field_y = _hud_content_bottom - _chat_field_h;
    var _event_bottom = _chat_field_y - 10;
    var _event_count = array_length(game_state.event_log);
    event_log_scroll = clamp(event_log_scroll, 0, max(0, _event_count - 1));

    // Scroll zero is the live edge. Measure backward from that edge, then render
    // the visible slice in chronological order with the newest entry at bottom.
    var _event_end_index = _event_count - 1 - event_log_scroll;
    var _visible_event_indices = [];
    var _visible_event_heights = [];
    var _visible_event_height = 0;
    for (var _measure_index = _event_end_index;
         _measure_index >= 0;
         _measure_index--) {
        var _measure_entry = game_state.event_log[_measure_index];
        var _measure_text = is_struct(_measure_entry)
            && variable_struct_exists(_measure_entry, "text")
            ? string(_measure_entry.text)
            : string(_measure_entry);
        var _measure_height = max(
            30,
            string_height_ext(_measure_text, 15, _log_w - 30)
        ) + 12;
        if (_visible_event_height + _measure_height
        > max(0, _event_bottom - _diagnostic_y)
        && array_length(_visible_event_indices) > 0) break;
        array_insert(_visible_event_indices, 0, _measure_index);
        array_insert(_visible_event_heights, 0, _measure_height);
        _visible_event_height += _measure_height;
    }
    var _event_y = max(_diagnostic_y, _event_bottom - _visible_event_height);
    for (var _visible_index = 0;
         _visible_index < array_length(_visible_event_indices);
         _visible_index++) {
        var _event_entry = game_state.event_log[
            _visible_event_indices[_visible_index]
        ];
        var _event_text = is_struct(_event_entry)
            && variable_struct_exists(_event_entry, "text")
            ? string(_event_entry.text)
            : string(_event_entry);
        var _event_is_chat = is_struct(_event_entry)
            && variable_struct_exists(_event_entry, "kind")
            && _event_entry.kind == "chat";
        // System history recedes into a desaturated straw tone so player chat is
        // immediately distinguishable without sacrificing legibility.
        var _event_color = _event_is_chat
            ? ui_color_text
            : merge_color(ui_color_muted, make_color_rgb(194, 178, 126), 0.38);
        draw_set_color(_event_color);
        draw_text_ext(_log_left + 12, _event_y, _event_text, 15, _log_w - 30);
        if (_event_is_chat
        && variable_struct_exists(_event_entry, "name_text")
        && variable_struct_exists(_event_entry, "name_color")) {
            draw_set_color(_event_entry.name_color);
            draw_text(_log_left + 12, _event_y, _event_entry.name_text);
        }
        _event_y += _visible_event_heights[_visible_index];
        if (_visible_index < array_length(_visible_event_indices) - 1) {
            draw_set_alpha(0.20);
            draw_set_color(ui_color_muted);
            draw_line(
                _log_left + 12,
                _event_y - 6,
                _rail_right - 12,
                _event_y - 6
            );
            draw_set_alpha(1);
        }
    }
    if (_event_count > 1) {
        var _scroll_track_top = _log_top + 36;
        var _scroll_track_bottom = _event_bottom;
        var _scroll_track_h = max(1, _scroll_track_bottom - _scroll_track_top);
        var _scroll_thumb_h = max(22, floor(_scroll_track_h * 0.18));
        var _scroll_fraction = 1
            - (event_log_scroll / max(1, _event_count - 1));
        var _scroll_thumb_y = _scroll_track_top
            + floor((_scroll_track_h - _scroll_thumb_h) * _scroll_fraction);
        draw_set_alpha(0.35);
        draw_set_color(ui_color_muted);
        draw_rectangle(_rail_right - 5, _scroll_track_top,
            _rail_right - 2, _scroll_track_bottom, false);
        draw_set_alpha(0.9);
        draw_set_color(ui_color_title);
        draw_rectangle(_rail_right - 6, _scroll_thumb_y,
            _rail_right - 1, _scroll_thumb_y + _scroll_thumb_h, false);
        draw_set_alpha(1);
    }

    draw_set_alpha(0.92);
    draw_set_color(chat_input_active
        ? merge_color(ui_color_background, ui_color_title, 0.16)
        : merge_color(ui_color_background, c_black, 0.22));
    draw_rectangle(_log_left + 10, _chat_field_y,
        _rail_right - 10, _hud_content_bottom, false);
    draw_set_alpha(1);
    draw_set_color(chat_input_active ? ui_color_title : ui_color_muted);
    draw_rectangle(_log_left + 10, _chat_field_y,
        _rail_right - 10, _hud_content_bottom, true);
    var _chat_display_text = chat_input_text;
    if (_chat_display_text == "") {
        _chat_display_text = chat_input_active
            ? "TYPE A MESSAGE..." : "CLICK TO CHAT";
    } else if (chat_input_active && (current_time div 450) mod 2 == 0) {
        _chat_display_text += "|";
    }
    draw_set_color(chat_input_text == "" ? ui_color_muted : ui_color_text);
    draw_set_valign(fa_middle);
    draw_text_ext(_log_left + 20, _chat_field_y + (_chat_field_h * 0.5),
        _chat_display_text, 15, _log_w - 48);
    draw_set_valign(fa_top);
    array_push(ui_hit_regions, {
        kind: "chat_input",
        index: 0,
        instance: undefined,
        x1: _log_left + 10,
        y1: _chat_field_y,
        x2: _rail_right - 10,
        y2: _hud_content_bottom,
        enabled: true,
        action: ""
    });

    if (test_tools_open) {
        ui_hit_regions = [];
        draw_set_alpha(0.72);
        draw_set_color(c_black);
        draw_rectangle(0, 0, _screen_width, _screen_height, false);
        draw_set_alpha(1);

        var _test_w = 650;
        var _test_h = 520;
        var _test_x = floor((_screen_width - _test_w) * 0.5);
        var _test_y = floor((_screen_height - _test_h) * 0.5);
        _draw_modal_panel(
            _test_x,
            _test_y,
            _test_x + _test_w,
            _test_y + _test_h,
            "TEST TOOLS - NOT PART OF NORMAL PLAY"
        );

        var _test_tab_y = _test_y + 38;
        var _test_tab_w = 292;
        _draw_action_button(
            "GAME",
            "test_tab_game",
            _test_x + 22,
            _test_tab_y,
            _test_tab_w,
            36,
            test_tools_tab != "game"
        );
        _draw_action_button(
            "ANIMATION",
            "test_tab_animation",
            _test_x + 336,
            _test_tab_y,
            _test_tab_w,
            36,
            test_tools_tab != "animation"
        );

        draw_set_color(ui_color_muted);
        var _test_selection_name = "none";
        if (test_selected_kind == "shop"
        && test_selected_index >= 0
        && test_selected_index < array_length(game_state.shop_row)) {
            _test_selection_name =
                game_state.shop_row[test_selected_index].definition.name;
        } else if (test_selected_kind == "ship"
        && test_selected_index >= 0
        && test_selected_index < array_length(_active_player.board.ships)) {
            _test_selection_name =
                _active_player.board.ships[test_selected_index].definition.name;
        }
        var _test_button_w = 292;
        var _test_button_h = 42;
        var _test_left = _test_x + 22;
        var _test_right = _test_x + 336;
        var _test_row_1 = _test_y + 126;
        var _test_row_gap = 52;
        if (test_tools_tab == "game") {
        draw_text(
            _test_x + 22,
            _test_y + 86,
            "Captured selection: " + _test_selection_name
            + "  |  Seed: " + string(game_seed)
        );
        _draw_action_button(
            "+5 ACTIVE CP",
            "test_cp",
            _test_left,
            _test_row_1,
            _test_button_w,
            _test_button_h,
            true
        );
        _draw_action_button(
            "READY ACTIVE BOARD",
            "test_ready",
            _test_right,
            _test_row_1,
            _test_button_w,
            _test_button_h,
            true
        );
        _draw_action_button(
            "DEPLOY SELECTED SHOP CARD",
            "test_deploy",
            _test_left,
            _test_row_1 + _test_row_gap,
            _test_button_w,
            _test_button_h,
            true
        );
        _draw_action_button(
            "ADD LARVA TO SELECTED SHIP",
            "test_larva",
            _test_right,
            _test_row_1 + _test_row_gap,
            _test_button_w,
            _test_button_h,
            true
        );
        _draw_action_button(
            "ADD OMEGA TO SELECTED SHIP",
            "test_omega",
            _test_left,
            _test_row_1 + (_test_row_gap * 2),
            _test_button_w,
            _test_button_h,
            true
        );
        _draw_action_button(
            "FORCE QUEEN EVENT",
            "test_queen",
            _test_right,
            _test_row_1 + (_test_row_gap * 2),
            _test_button_w,
            _test_button_h,
            true
        );
        _draw_action_button(
            "RESTART - SEED 388",
            "test_fixed_seed",
            _test_left,
            _test_row_1 + (_test_row_gap * 3),
            _test_button_w,
            _test_button_h,
            true
        );
        _draw_action_button(
            "RESTART - RANDOM SEED",
            "test_random_seed",
            _test_right,
            _test_row_1 + (_test_row_gap * 3),
            _test_button_w,
            _test_button_h,
            true
        );
        _draw_action_button(
            "SIMULATE TO GAME OVER",
            "test_game_over",
            _test_left,
            _test_row_1 + (_test_row_gap * 4),
            (_test_button_w * 2) + 22,
            _test_button_h,
            true
        );
        _draw_action_button(
            "RANDOM WIN SCREEN",
            "test_random_win",
            _test_left,
            _test_row_1 + (_test_row_gap * 5),
            (_test_button_w * 2) + 22,
            _test_button_h,
            true
        );
        } else {
            draw_set_halign(fa_left);
            draw_set_color(make_color_rgb(255, 210, 72));
            draw_text(
                _test_left,
                _test_y + 88,
                "LIVE-STATE TESTS - MUTATES CURRENT MATCH"
            );
            _draw_action_button(
                test_animation_page == 0 ? "PAGE 1: MOVEMENT" : "PAGE 2: INTERACTION",
                "test_anim_page",
                _test_right,
                _test_y + 80,
                _test_button_w,
                34,
                true
            );
            if (test_animation_page == 0) {
            _draw_action_button("HAND DEPLOY", "test_anim_deploy",
                _test_left, _test_row_1, _test_button_w, _test_button_h, true);
            _draw_action_button("EVENT TO DISCARD", "test_anim_event",
                _test_right, _test_row_1, _test_button_w, _test_button_h, true);
            _draw_action_button("RESERVE SHOP CARD", "test_anim_reserve",
                _test_left, _test_row_1 + _test_row_gap,
                _test_button_w, _test_button_h, true);
            _draw_action_button("REFRESH HAND", "test_anim_refresh_hand",
                _test_right, _test_row_1 + _test_row_gap,
                _test_button_w, _test_button_h, true);
            _draw_action_button("REFRESH SHOP", "test_anim_refresh_shop",
                _test_left, _test_row_1 + (_test_row_gap * 2),
                _test_button_w, _test_button_h, true);
            _draw_action_button("DISCARD TO DECK", "test_anim_shuffle",
                _test_right, _test_row_1 + (_test_row_gap * 2),
                _test_button_w, _test_button_h, true);
            _draw_action_button("METROID EVOLVE", "test_anim_evolve",
                _test_left, _test_row_1 + (_test_row_gap * 3),
                _test_button_w, _test_button_h, true);
            _draw_action_button("PHAZON FLASH", "test_anim_phazon",
                _test_right, _test_row_1 + (_test_row_gap * 3),
                _test_button_w, _test_button_h, true);
            _draw_action_button("SHIP TO LAB", "test_anim_lab",
                _test_left, _test_row_1 + (_test_row_gap * 4),
                (_test_button_w * 2) + 22, _test_button_h, true);
            } else {
            _draw_action_button("CAPTURE METROID", "test_anim_capture",
                _test_left, _test_row_1, _test_button_w, _test_button_h, true);
            _draw_action_button("CREATE ATTACHMENT", "test_anim_attachment",
                _test_right, _test_row_1, _test_button_w, _test_button_h, true);
            _draw_action_button("FRIENDLY TARGET LINE", "test_anim_target_friendly",
                _test_left, _test_row_1 + _test_row_gap,
                _test_button_w, _test_button_h, true);
            _draw_action_button("ENEMY TARGET LINE", "test_anim_target_enemy",
                _test_right, _test_row_1 + _test_row_gap,
                _test_button_w, _test_button_h, true);
            _draw_action_button("DISCARD FROM PLAY", "test_anim_discard",
                _test_left, _test_row_1 + (_test_row_gap * 2),
                _test_button_w, _test_button_h, true);
            _draw_action_button("DESTROY FROM PLAY", "test_anim_destroy",
                _test_right, _test_row_1 + (_test_row_gap * 2),
                _test_button_w, _test_button_h, true);
            _draw_action_button("RAID TARGET LINE", "test_anim_raid",
                _test_left, _test_row_1 + (_test_row_gap * 3),
                _test_button_w, _test_button_h, true);
            _draw_action_button("TWO OMEGA BREACHES", "test_anim_breaches",
                _test_right, _test_row_1 + (_test_row_gap * 3),
                _test_button_w, _test_button_h, true);
            _draw_action_button("QUEEN EVENT", "test_anim_queen",
                _test_left, _test_row_1 + (_test_row_gap * 4),
                (_test_button_w * 2) + 22, _test_button_h, true);
            }
        }
        _draw_action_button(
            "CLOSE",
            "test_close",
            _test_left,
            _test_y + _test_h - 58,
            (_test_button_w * 2) + 22,
            _test_button_h,
            true
        );
    }

    // Holding Alt over a card temporarily replaces the board with its full art.
    if (keyboard_check(vk_alt) && !is_undefined(ui_hover_instance)) {
        var _art_definition = ui_hover_instance.definition;
        var _art_is_metroid = ui_hover_kind == "metroid"
            || ui_hover_kind == "lab"
            || ui_hover_kind == "opponent_lab"
            || ui_hover_kind == "cargo"
            || ui_hover_kind == "opponent_cargo";
        var _art_sprite = get_definition_sprite(
            _art_definition,
            _art_is_metroid
        );
        if (_art_sprite >= 0) {
            var _art_is_ship = !_art_is_metroid
                && variable_struct_exists(_art_definition, "type")
                && _art_definition.type == "ship";
            var _art_source_width = _art_is_ship ? 1400 : 1000;
            var _art_source_height = _art_is_ship ? 1000 : 1400;
            var _art_padding = 24;
            var _art_scale = min(
                (_screen_width - (_art_padding * 2)) / _art_source_width,
                (_screen_height - (_art_padding * 2)) / _art_source_height
            );
            var _art_width = floor(_art_source_width * _art_scale);
            var _art_height = floor(_art_source_height * _art_scale);
            var _art_x = floor((_screen_width - _art_width) * 0.5);
            var _art_y = floor((_screen_height - _art_height) * 0.5);

            draw_set_alpha(0.94);
            draw_set_color(c_black);
            draw_rectangle(0, 0, _screen_width, _screen_height, false);
            draw_set_alpha(1);
            draw_set_color(c_white);
            draw_sprite_stretched(
                _art_sprite,
                0,
                _art_x,
                _art_y,
                _art_width,
                _art_height
            );
            draw_set_color(ui_color_selected);
            draw_rectangle(
                _art_x - 2,
                _art_y - 2,
                _art_x + _art_width + 2,
                _art_y + _art_height + 2,
                true
            );
            var _art_has_stat = !_art_is_metroid
                && variable_struct_exists(_art_definition, "stat")
                && !is_undefined(_art_definition.stat)
                && variable_struct_exists(_art_definition.stat, "value")
                && !is_undefined(_art_definition.stat.value);
            var _art_show_live_stat = false;
            if (_art_has_stat) {
                var _art_printed_stat = _art_definition.stat.value;
                var _art_current_stat = get_card_stat(ui_hover_instance);
                _art_show_live_stat = !is_real(_art_printed_stat)
                    || _art_current_stat != _art_printed_stat;
            }
            if (_art_show_live_stat) {
                var _art_stat_radius = 34;
                var _art_stat_x = _art_x + _art_stat_radius + 16;
                var _art_stat_y = _art_y + _art_height
                    - _art_stat_radius - 16;
                draw_set_alpha(0.86);
                draw_set_color(c_black);
                draw_circle(
                    _art_stat_x,
                    _art_stat_y,
                    _art_stat_radius,
                    false
                );
                draw_set_alpha(1);
                draw_set_color(ui_color_selected);
                draw_set_halign(fa_center);
                draw_set_valign(fa_middle);
                draw_text_transformed(
                    _art_stat_x,
                    _art_stat_y,
                    string(get_card_stat(ui_hover_instance)),
                    2,
                    2,
                    0
                );
            }
        }
    }

    if (handoff_active && game_state.phase != "game_over") {
        draw_set_alpha(0.98);
        draw_set_color(
            game_state.active_player == 0
                ? make_color_rgb(6, 14, 24)
                : make_color_rgb(27, 12, 8)
        );
        draw_rectangle(0, 0, _screen_width, _screen_height, false);
        draw_set_alpha(1);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_color(ui_color_muted);
        draw_set_font(FNT_METROID);
        draw_text_transformed(
            _screen_width * 0.5,
            _screen_height * 0.5 - 126,
            "PASS CONTROL TO",
            2,
            2,
            0
        );
        draw_set_color(ui_color_title);
        draw_text_transformed(
            _screen_width * 0.5,
            _screen_height * 0.5 - 62,
            game_state.players[game_state.active_player].name,
            4,
            4,
            0
        );
        draw_set_color(ui_color_text);
        draw_text(
            _screen_width * 0.5,
            _screen_height * 0.5 + 2,
            "Turn " + string(game_state.turn_number)
        );
        draw_set_font(-1);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        _draw_action_button(
            "BEGIN TURN",
            "handoff_continue",
            _screen_width * 0.5 - 130,
            _screen_height * 0.5 + 58,
            260,
            52,
            true
        );
    }

    if (game_state.phase == "game_over") {
        draw_set_alpha(0.94);
        draw_set_color(c_black);
        draw_rectangle(0, 0, _screen_width, _screen_height, false);
        draw_set_alpha(1);
        var _end_w = min(1100, _screen_width - 80);
        var _end_h = min(720, _screen_height - 40);
        var _end_x = floor((_screen_width - _end_w) * 0.5);
        var _end_y = floor((_screen_height - _end_h) * 0.5);
        var _end_center_x = floor(_screen_width * 0.5);
        draw_set_color(make_color_rgb(13, 22, 32));
        draw_rectangle(
            _end_x,
            _end_y,
            _end_x + _end_w,
            _end_y + _end_h,
            false
        );
        draw_set_color(ui_color_selected);
        draw_rectangle(
            _end_x,
            _end_y,
            _end_x + _end_w,
            _end_y + _end_h,
            true
        );
        var _end_preview_active = !is_undefined(end_screen_preview);
        var _end_research_0 = _end_preview_active
            ? end_screen_preview.research[0]
            : get_player_research(game_state.players[0]);
        var _end_research_1 = _end_preview_active
            ? end_screen_preview.research[1]
            : get_player_research(game_state.players[1]);
        var _end_cp_0 = _end_preview_active
            ? end_screen_preview.cp[0]
            : game_state.players[0].command_points;
        var _end_cp_1 = _end_preview_active
            ? end_screen_preview.cp[1]
            : game_state.players[1].command_points;
        var _end_winner = _end_preview_active
            ? end_screen_preview.winner : game_state.winner;
        var _end_title = _end_winner < 0
            ? "DRAW"
            : (_end_preview_active
                ? end_screen_preview.names[_end_winner]
                : game_state.players[_end_winner].name) + " WINS";
        var _end_reason = _end_research_0 != _end_research_1
            ? "Highest Research"
            : (_end_cp_0 != _end_cp_1
                ? "Research tied - CP tiebreaker"
                : "Research and CP tied");
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_color(ui_color_selected);
        draw_set_font(FNT_METROID);
        var _end_title_scale = max(
            1,
            floor(min(
                4,
                (_end_w - 64) / max(1, string_width(_end_title)),
                64 / max(1, string_height(_end_title))
            ))
        );
        var _end_title_filtering = gpu_get_texfilter();
        gpu_set_texfilter(false);
        draw_text_transformed(
            _end_center_x,
            _end_y + 64,
            _end_title,
            _end_title_scale,
            _end_title_scale,
            0
        );
        gpu_set_texfilter(_end_title_filtering);
        draw_set_color(ui_color_muted);
        draw_text(
            _screen_width * 0.5,
            _end_y + 124,
            "Turn " + string(game_state.turn_number)
            + "  |  Seed " + string(game_state.seed)
            + "  |  " + _end_reason
        );
        draw_set_font(-1);
        var _score_gap = 22;
        var _score_w = floor((_end_w - 72 - _score_gap) * 0.5);
        var _score_y = _end_y + 150;
        var _score_h = 225;
        var _end_score_palette = function(_player_index, _preview_active) {
            if (_preview_active) {
                switch (end_screen_preview.factions[_player_index]) {
                    case "GF": return LOC_COLOR_GF;
                    case "SP": return LOC_COLOR_SP;
                    case "CZ": return LOC_COLOR_CZ;
                    case "BH": return LOC_COLOR_BH;
                    case "PZ": return LOC_COLOR_PZ;
                    default: return LOC_COLOR_NEUTRAL;
                }
            }
            if (game_state.game_mode != "ai_watch") {
                return _player_index == 0 ? LOC_COLOR_GF : LOC_COLOR_SP;
            }
            switch (game_state.players[_player_index].favored_faction) {
                case "GF": return LOC_COLOR_GF;
                case "SP": return LOC_COLOR_SP;
                case "CZ": return LOC_COLOR_CZ;
                case "BH": return LOC_COLOR_BH;
                case "PZ": return LOC_COLOR_PZ;
                default: return LOC_COLOR_NEUTRAL;
            }
        };
        var _draw_end_score_counter = function(
            _sprite,
            _center_x,
            _center_y,
            _max_width,
            _max_height,
            _value,
            _palette
        ) {
            var _source_w = max(1, sprite_get_width(_sprite));
            var _source_h = max(1, sprite_get_height(_sprite));
            var _icon_scale = min(
                _max_width / _source_w,
                _max_height / _source_h
            );
            var _icon_w = _source_w * _icon_scale;
            var _icon_h = _source_h * _icon_scale;
            var _tint_surface_w = max(1, ceil(_max_width));
            var _tint_surface_h = max(1, ceil(_max_height));
            if (!surface_exists(end_counter_tint_surface)
            || surface_get_width(end_counter_tint_surface) != _tint_surface_w
            || surface_get_height(end_counter_tint_surface) != _tint_surface_h) {
                if (surface_exists(end_counter_tint_surface)) {
                    surface_free(end_counter_tint_surface);
                }
                end_counter_tint_surface = surface_create(
                    _tint_surface_w,
                    _tint_surface_h
                );
            }
            surface_set_target(end_counter_tint_surface);
            draw_clear_alpha(c_black, 0);
            draw_set_alpha(1);
            draw_set_color(c_white);
            draw_sprite_ext(
                _sprite,
                0,
                (_tint_surface_w - _icon_w) * 0.5,
                (_tint_surface_h - _icon_h) * 0.5,
                _icon_scale,
                _icon_scale,
                0,
                c_white,
                1
            );
            // Replace RGB using the sprite's rendered alpha as a mask. A normal
            // image_blend multiplies the source cyan and cannot produce red/yellow.
            gpu_set_blendmode_ext(bm_dest_alpha, bm_zero);
            draw_set_color(_palette);
            draw_rectangle(0, 0, _tint_surface_w, _tint_surface_h, false);
            gpu_set_blendmode(bm_normal);
            surface_reset_target();
            draw_set_color(c_white);
            draw_surface(
                end_counter_tint_surface,
                floor(_center_x - (_tint_surface_w * 0.5)),
                floor(_center_y - (_tint_surface_h * 0.5))
            );
            var _counter_text = string(_value);
            var _counter_text_scale = 1;
            draw_set_font(FNT_NUMBER);
            // FNT_NUMBER uses a fixed 48px advance, but its visible digit bounds
            // differ (notably the narrower, offset digit 1). Center the ink rather
            // than the advance box so every value sits visually on the icon.
            var _counter_length = string_length(_counter_text);
            var _counter_first = _counter_length > 0
                ? string_char_at(_counter_text, 1) : "0";
            var _counter_visible_left = _counter_first == "1" ? 6 : 0;
            var _counter_visible_right = max(0, _counter_length - 1) * 48
                + 42;
            var _counter_visual_center = (
                _counter_visible_left + _counter_visible_right
            ) * 0.5;
            var _counter_draw_x = floor(_center_x - _counter_visual_center);
            var _counter_draw_y = floor(_center_y);
            draw_set_halign(fa_left);
            draw_set_valign(fa_middle);
            draw_set_color(make_color_rgb(4, 8, 12));
            for (var _outline_x = -2; _outline_x <= 2; _outline_x += 2) {
                for (var _outline_y = -2; _outline_y <= 2; _outline_y += 2) {
                    if (_outline_x != 0 || _outline_y != 0) {
                        draw_text_transformed(
                            _counter_draw_x + _outline_x,
                            _counter_draw_y + _outline_y,
                            _counter_text,
                            _counter_text_scale,
                            _counter_text_scale,
                            0
                        );
                    }
                }
            }
            draw_set_color(c_white);
            draw_text_transformed(
                _counter_draw_x,
                _counter_draw_y,
                _counter_text,
                _counter_text_scale,
                _counter_text_scale,
                0
            );
            draw_set_halign(fa_center);
            draw_set_font(FNT_METROID);
        };
        draw_set_font(FNT_METROID);
        for (var _score_player_index = 0;
             _score_player_index < 2;
             _score_player_index++) {
            var _score_x = _end_x + 36
                + (_score_player_index * (_score_w + _score_gap));
            var _score_palette = _end_score_palette(
                _score_player_index,
                _end_preview_active
            );
            draw_set_alpha(0.30);
            draw_set_color(_score_palette);
            draw_rectangle(
                _score_x,
                _score_y,
                _score_x + _score_w,
                _score_y + _score_h,
                false
            );
            draw_set_alpha(0.88);
            draw_set_color(_score_palette);
            draw_rectangle(
                _score_x,
                _score_y,
                _score_x + _score_w,
                _score_y + _score_h,
                true
            );
            if (_end_winner == _score_player_index) {
                draw_set_alpha(0.72);
                draw_set_color(ui_color_selected);
                draw_rectangle(
                    _score_x - 2,
                    _score_y - 2,
                    _score_x + _score_w + 2,
                    _score_y + _score_h + 2,
                    true
                );
            }
            draw_set_alpha(1);
            draw_set_color(_score_palette);
            var _score_player_name = string_upper(_end_preview_active
                ? end_screen_preview.names[_score_player_index]
                : game_state.players[_score_player_index].name);
            var _score_name_scale = 0.5;
            draw_set_font(FNT_NUMBER);
            draw_text_transformed(
                _score_x + (_score_w * 0.5),
                _score_y + 34,
                _score_player_name,
                _score_name_scale,
                _score_name_scale,
                0
            );
            draw_set_font(FNT_METROID);
            var _score_counter_y = _score_y + 133;
            var _score_counter_cell_w = _score_w / 3;
            _draw_end_score_counter(
                sprResearchBox,
                _score_x + (_score_counter_cell_w * 0.5),
                _score_counter_y,
                _score_counter_cell_w - 18,
                112,
                _score_player_index == 0
                    ? _end_research_0
                    : _end_research_1,
                _score_palette
            );
            _draw_end_score_counter(
                sprCommandBox,
                _score_x + (_score_counter_cell_w * 1.5),
                _score_counter_y,
                _score_counter_cell_w - 18,
                112,
                _score_player_index == 0 ? _end_cp_0 : _end_cp_1,
                _score_palette
            );
            _draw_end_score_counter(
                sprMetroidBox,
                _score_x + (_score_counter_cell_w * 2.5),
                _score_counter_y,
                _score_counter_cell_w - 18,
                112,
                _end_preview_active
                    ? end_screen_preview.metroids[_score_player_index]
                    : array_length(game_state.players[_score_player_index].lab),
                _score_palette
            );
        }
        draw_set_font(-1);
        draw_set_color(ui_color_text);
        draw_text(
            _screen_width * 0.5,
            _end_y + 405,
            "Captures "
                + string(count_event_log_matches(" captured "))
            + "  |  Raids "
                + string(count_event_log_prefix("Raid "))
            + "  |  Breaches "
                + string(count_event_log_matches(" breached"))
            + "  |  Evolutions "
                + string(count_event_log_matches(" evolved"))
        );
        draw_set_color(ui_color_muted);
        draw_text(
            floor(_screen_width * 0.5),
            _end_y + 438,
            game_state.balance_log_path == ""
                ? "Balance log could not be saved."
                : "Match summary and full trace saved to the balance log."
        );
        if (!_end_preview_active) {
            end_report_page = clamp(end_report_page, 0, 2);
            if (end_report_page > 0) {
                var _end_detail_player_index = end_report_page - 1;
                var _end_detail_player =
                    game_state.players[_end_detail_player_index];
                var _end_detail_stats = batch_player_telemetry_snapshot(
                    _end_detail_player
                );
                var _end_detail_color = _end_score_palette(
                    _end_detail_player_index,
                    false
                );
                draw_set_color(make_color_rgb(13, 22, 32));
                draw_rectangle(
                    _end_x + 20,
                    _end_y + 140,
                    _end_x + _end_w - 20,
                    _end_y + 500,
                    false
                );
                draw_set_color(_end_detail_color);
                draw_rectangle(
                    _end_x + 20,
                    _end_y + 140,
                    _end_x + _end_w - 20,
                    _end_y + 500,
                    true
                );
                draw_set_halign(fa_center);
                draw_set_font(FNT_METROID);
                var _end_detail_filtering = gpu_get_texfilter();
                gpu_set_texfilter(false);
                draw_text_transformed(
                    _end_center_x,
                    _end_y + 174,
                    string_upper(_end_detail_player.name) + " DETAILS",
                    2,
                    2,
                    0
                );
                gpu_set_texfilter(_end_detail_filtering);
                draw_set_halign(fa_left);
                draw_set_valign(fa_top);
                draw_set_font(FNT_METROID);
                draw_set_color(ui_color_title);
                draw_text(_end_x + 60, _end_y + 220, "DECISIONS");
                draw_set_color(ui_color_text);
                draw_text(
                    _end_x + 60,
                    _end_y + 262,
                    "Peak CP: " + string(_end_detail_stats.max_cp)
                    + "\nCaptures: " + string(_end_detail_stats.captures)
                    + "\nRaids initiated: "
                        + string(_end_detail_stats.raids_started)
                    + "\nRaids won: " + string(_end_detail_stats.raids_won)
                    + "\nRaids lost: " + string(_end_detail_stats.raids_lost)
                    + "\nRaid ties: " + string(_end_detail_stats.raid_ties)
                    + "\nBreaches suffered: "
                        + string(_end_detail_stats.breaches)
                );
                draw_set_color(ui_color_title);
                draw_text(
                    _screen_width * 0.5 - 80,
                    _end_y + 220,
                    "METROIDS SCORED"
                );
                var _end_stage_names = [
                    "Larva", "Alpha", "Gamma", "Zeta", "Omega", "Hunter"
                ];
                var _end_stage_text = "";
                for (var _end_stage = 0; _end_stage < 6; _end_stage++) {
                    _end_stage_text += _end_stage_names[_end_stage]
                        + ": "
                        + string(_end_detail_stats.metroid_counts[_end_stage])
                        + " (" + string(
                            _end_detail_stats.metroid_research[_end_stage]
                        ) + " RP)"
                        + (_end_stage < 5 ? "\n" : "");
                }
                draw_set_color(ui_color_text);
                draw_text(
                    _screen_width * 0.5 - 80,
                    _end_y + 262,
                    _end_stage_text
                );
                var _end_top_definition = get_card_definition(
                    _end_detail_stats.most_taken_id
                );
                draw_set_color(ui_color_title);
                draw_text(_end_x + _end_w - 320, _end_y + 220, "SHOP HABITS");
                draw_set_color(ui_color_text);
                draw_text(
                    _end_x + _end_w - 320,
                    _end_y + 262,
                    "Most taken card:\n"
                    + (is_undefined(_end_top_definition)
                        ? "None"
                        : _end_top_definition.name + " x"
                            + string(_end_detail_stats.most_taken_count))
                    + "\n\nTotal Metroids: "
                        + string(batch_array_total(
                            _end_detail_stats.metroid_counts
                        ))
                    + "\nFinal Research: "
                        + string(get_player_research(_end_detail_player))
                );
            }
            _draw_action_button(
                "RESULT",
                "end_report_result",
                _end_center_x - 340,
                _end_y + 516,
                220,
                36,
                end_report_page != 0
            );
            _draw_action_button(
                string_upper(game_state.players[0].name),
                "end_report_p1",
                _end_center_x - 110,
                _end_y + 516,
                220,
                36,
                end_report_page != 1
            );
            _draw_action_button(
                string_upper(game_state.players[1].name),
                "end_report_p2",
                _end_center_x + 120,
                _end_y + 516,
                220,
                36,
                end_report_page != 2
            );
        }
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        var _end_button_gap = 16;
        var _end_button_w = 220;
        _draw_action_button(
            _end_preview_active ? "REROLL" : "REMATCH",
            _end_preview_active ? "test_random_win" : "rematch",
            _screen_width * 0.5 - _end_button_w - (_end_button_gap * 0.5),
            _end_y + _end_h - 82,
            _end_button_w,
            48,
            true
        );
        _draw_action_button(
            "BACK TO MENU",
            "back_to_menu",
            _screen_width * 0.5 + (_end_button_gap * 0.5),
            _end_y + _end_h - 82,
            _end_button_w,
            48,
            true
        );
    }

    var _draw_help_page = function(
        _help_screen_width,
        _help_screen_height,
        _help_draw_modal_panel,
        _help_draw_action_button,
        _help_add_hit_region
    ) {
        ui_hit_regions = [];
        draw_set_alpha(0.98);
        draw_set_color(ui_color_menu_background);
        draw_rectangle(0, 0, _help_screen_width, _help_screen_height, false);
        draw_set_alpha(1);

        var _help_w = min(1040, _help_screen_width - 48);
        var _help_h = min(760, _help_screen_height - 48);
        var _help_x = floor((_help_screen_width - _help_w) * 0.5);
        var _help_y = floor((_help_screen_height - _help_h) * 0.5);
        _help_draw_modal_panel(
            _help_x,
            _help_y,
            _help_x + _help_w,
            _help_y + _help_h,
            "HELP / RULES REFERENCE"
        );

        var _help_pad = 28;
        var _help_content_top = _help_y + 66;
        var _help_bottom = _help_y + _help_h - 24;
        var _help_left_w = min(280, floor(_help_w * 0.31));
        var _help_left_x = _help_x + _help_pad;
        var _help_right_x = _help_left_x + _help_left_w + 28;
        var _help_right_w = _help_x + _help_w - _help_pad - _help_right_x;
        var _help_back_y = _help_bottom - 44;

        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_color(ui_color_line);
        draw_line(
            _help_right_x - 14,
            _help_content_top,
            _help_right_x - 14,
            _help_bottom
        );

        var _help_topic_y = _help_content_top;
        var _help_topic_gap = 4;
        var _help_topic_count = array_length(help_topics);
        var _help_topic_button_h = min(
            40,
            max(
                24,
                floor((
                    _help_back_y - 10 - _help_topic_y
                        - ((_help_topic_count - 1) * _help_topic_gap)
                ) / max(1, _help_topic_count))
            )
        );
        for (var _help_topic_index = 0;
             _help_topic_index < _help_topic_count;
             _help_topic_index++) {
            _help_draw_action_button(
                help_topics[_help_topic_index].title,
                "help_topic_" + string(_help_topic_index),
                _help_left_x,
                _help_topic_y + _help_topic_index
                    * (_help_topic_button_h + _help_topic_gap),
                _help_left_w,
                _help_topic_button_h,
                true
            );
        }
        _help_draw_action_button(
            "BACK",
            "help_back",
            _help_left_x,
            _help_back_y,
            _help_left_w,
            40,
            true
        );

        help_selected_index = clamp(
            help_selected_index,
            0,
            max(0, _help_topic_count - 1)
        );
        var _help_topic = help_topics[help_selected_index];
        var _help_text_x = _help_right_x + 16;
        var _help_text_w = _help_right_w - 34;
        var _help_text_top = _help_content_top;
        var _help_text_bottom = _help_bottom - 20;
        draw_set_font(FNT_METROID);
        draw_set_color(ui_color_title);
        draw_text(_help_text_x, _help_text_top, _help_topic.title);
        draw_set_font(-1);
        draw_set_color(ui_color_line);
        draw_line(
            _help_text_x,
            _help_text_top + 29,
            _help_right_x + _help_right_w - 12,
            _help_text_top + 29
        );
        var _help_body_top = _help_text_top + 45;
        draw_set_font(FNT_METROID);
        var _help_body_line_spacing = 28;
        var _help_body_h = string_height_ext(
            _help_topic.summary,
            _help_body_line_spacing,
            _help_text_w
        );
        help_scroll_max = max(
            0,
            _help_body_h - max(1, _help_text_bottom - _help_body_top)
        );
        help_scroll = clamp(help_scroll, 0, help_scroll_max);
        gpu_set_scissor(
            _help_text_x,
            _help_body_top,
            _help_text_w,
            max(1, _help_text_bottom - _help_body_top)
        );
        draw_set_color(ui_color_text);
        draw_text_ext(
            _help_text_x,
            _help_body_top - help_scroll,
            _help_topic.summary,
            _help_body_line_spacing,
            _help_text_w
        );
        draw_set_font(-1);
        gpu_set_scissor(0, 0, _help_screen_width, _help_screen_height);
        _help_add_hit_region(
            "help_scroll",
            0,
            undefined,
            _help_right_x,
            _help_body_top,
            _help_right_w,
            _help_text_bottom - _help_body_top
        );
        if (help_scroll_max > 0) {
            var _help_track_x = _help_right_x + _help_right_w - 7;
            var _help_track_h = _help_text_bottom - _help_body_top;
            var _help_thumb_h = max(
                28,
                floor(_help_track_h * _help_track_h
                    / max(1, _help_track_h + help_scroll_max))
            );
            var _help_thumb_y = _help_body_top
                + floor((_help_track_h - _help_thumb_h)
                    * help_scroll / max(1, help_scroll_max));
            draw_set_alpha(0.30);
            draw_set_color(ui_color_muted);
            draw_rectangle(
                _help_track_x,
                _help_body_top,
                _help_track_x + 3,
                _help_text_bottom,
                false
            );
            draw_set_alpha(0.9);
            draw_set_color(ui_color_title);
            draw_rectangle(
                _help_track_x - 1,
                _help_thumb_y,
                _help_track_x + 4,
                _help_thumb_y + _help_thumb_h,
                false
            );
            draw_set_alpha(1);
        }
    };

    if (title_menu_active) {
        draw_set_alpha(1);
        draw_set_color(ui_color_menu_background);
        draw_rectangle(0, 0, _screen_width, _screen_height, false);
        var _title_panel_w = min(1040, _screen_width - 96);
        var _title_panel_h = min(700, _screen_height - 96);
        var _title_panel_x = floor((_screen_width - _title_panel_w) * 0.5);
        var _title_panel_y = floor((_screen_height - _title_panel_h) * 0.5);
        draw_set_color(ui_color_menu_panel);
        draw_rectangle(
            _title_panel_x,
            _title_panel_y,
            _title_panel_x + _title_panel_w,
            _title_panel_y + _title_panel_h,
            false
        );
        draw_set_color(ui_color_menu_line);
        draw_rectangle(
            _title_panel_x,
            _title_panel_y,
            _title_panel_x + _title_panel_w,
            _title_panel_y + _title_panel_h,
            true
        );
        draw_set_color(ui_color_mutation);
        //draw_rectangle(
        //    _title_panel_x + 60,
        //    _title_panel_y + 42,
        //    _title_panel_x + _title_panel_w - 60,
        //    _title_panel_y + 47,
        //    false
        //);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        var _title_logo_scale = min(
            (_title_panel_w - 120) / max(1, sprite_get_width(TITLELOGO)),
            150 / max(1, sprite_get_height(TITLELOGO))
        );
        draw_set_alpha(1);
        draw_sprite_ext(
            TITLELOGO,
            0,
            _screen_width * 0.5,
            _title_panel_y + 137,
            _title_logo_scale,
            _title_logo_scale,
            0,
            c_white,
            1
        );
        draw_set_font(-1);
        draw_set_color(ui_color_text);
        draw_text(
            _screen_width * 0.5,
            _title_panel_y + 226,
            ""//subtitle below title logo
        );
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        var _title_content_top = _title_panel_y + 240;
        var _title_content_bottom = _title_panel_y + _title_panel_h - 48;
        var _title_left_x = _title_panel_x + 42;
        var _title_left_w = 260;
        var _title_right_x = _title_left_x + _title_left_w + 34;
        var _title_right_w = _title_panel_x + _title_panel_w - 42
            - _title_right_x;
        draw_set_color(ui_color_line);
        draw_line(
            _title_right_x - 17,
            _title_content_top,
            _title_right_x - 17,
            _title_content_bottom
        );

        var _mode_labels = [
            "VS. AI", "HOTSEAT", "NETWORK PLAY", "AI VS AI",
            "SETTINGS", "HELP", "BATCH TESTS", "REGRESSION TESTS"
        ];
        var _mode_keys = [
            "ai", "hotseat", "network", "ai_watch",
            "settings", "help", "batch", "regression"
        ];
        var _mode_y = _title_content_top;
        var _mode_gap = 4;
        var _mode_button_h = min(
            40,
            max(
                24,
                floor((
                    _title_content_bottom - _mode_y
                        - ((array_length(_mode_keys) - 1) * _mode_gap)
                ) / array_length(_mode_keys))
            )
        );
        for (var _mode_index = 0;
             _mode_index < array_length(_mode_keys);
             _mode_index++) {
            var _mode_key = _mode_keys[_mode_index];
            _draw_action_button(
                _mode_labels[_mode_index],
                "title_select_" + _mode_key,
                _title_left_x,
                _mode_y + _mode_index * (_mode_button_h + _mode_gap),
                _title_left_w,
                _mode_button_h,
                _mode_key != "batch" && _mode_key != "regression"
                    ? true
                    : settings_debug_mode
            );
        }

        var _title_name_fields = [];
        var _right_y = _title_content_top;
        if (title_context_mode == "ai") {
            array_push(_title_name_fields, {
                label: "PLAYER NAME", kind: "title_name_p1",
                value: net_player_name, y: _right_y
            });
            _draw_action_button(
                "PLAYER DECK: "
                    + title_leader_button_names[title_leader_p1_index],
                "title_cycle_leader_p1", _title_right_x, _right_y + 76,
                _title_right_w, 46, true
            );
            _draw_action_button(
                "AI DECK: "
                    + title_leader_button_names[title_leader_p2_index],
                "title_cycle_leader_p2", _title_right_x, _right_y + 134,
                _title_right_w, 46, true
            );
        } else if (title_context_mode == "hotseat") {
            array_push(_title_name_fields, {
                label: "PLAYER 1 NAME", kind: "title_name_p1",
                value: net_player_name, y: _right_y
            });
            _draw_action_button(
                "PLAYER 1 DECK: "
                    + title_leader_button_names[title_leader_p1_index],
                "title_cycle_leader_p1", _title_right_x, _right_y + 70,
                _title_right_w, 42, true
            );
            array_push(_title_name_fields, {
                label: "PLAYER 2 NAME", kind: "title_name_p2",
                value: title_player_two_name, y: _right_y + 124
            });
            _draw_action_button(
                "PLAYER 2 DECK: "
                    + title_leader_button_names[title_leader_p2_index],
                "title_cycle_leader_p2", _title_right_x, _right_y + 194,
                _title_right_w, 42, true
            );
        } else if (title_context_mode == "network") {
            array_push(_title_name_fields, {
                label: "PLAYER NAME", kind: "title_name_p1",
                value: net_player_name, y: _right_y
            });
            _draw_action_button(
                "PLAYER DECK: "
                    + title_leader_button_names[title_leader_p1_index],
                "title_cycle_leader_p1", _title_right_x, _right_y + 76,
                _title_right_w, 46, true
            );
            _draw_action_button(
                "HOST GAME", "title_network_host",
                _title_right_x, _right_y + 144, _title_right_w, 46, true
            );
            array_push(_title_name_fields, {
                label: "HOST ADDRESS", kind: "title_network_address",
                value: net_ip_input, y: _right_y + 212
            });
            _draw_action_button(
                "JOIN GAME", "title_network_join",
                _title_right_x, _right_y + 282, _title_right_w, 46, true
            );
        } else if (title_context_mode == "ai_watch") {
            _draw_action_button(
                "PLAYER 1 DECK: "
                    + title_leader_button_names[title_leader_p1_index],
                "title_cycle_leader_p1", _title_right_x, _right_y,
                _title_right_w, 48, true
            );
            _draw_action_button(
                "PLAYER 2 DECK: "
                    + title_leader_button_names[title_leader_p2_index],
                "title_cycle_leader_p2", _title_right_x, _right_y + 62,
                _title_right_w, 48, true
            );
        } else if (title_context_mode == "settings") {
            _draw_action_button(
                settings_default_center_far
                    ? "DEFAULT VIEW: FAR" : "DEFAULT VIEW: CLOSE",
                "settings_view", _title_right_x, _right_y,
                _title_right_w, 44, true
            );
            _draw_action_button(
                settings_default_camera_locked
                    ? "DEFAULT CAMERA: LOCKED" : "DEFAULT CAMERA: FREE",
                "settings_lock", _title_right_x, _right_y + 54,
                _title_right_w, 44, true
            );
            _draw_action_button(
                "PLAYER 1 UI: "
                    + settings_ui_color_names[settings_ui_color_index],
                "settings_color", _title_right_x, _right_y + 108,
                _title_right_w, 44, true
            );
            _draw_action_button(
                "PLAYER 2 UI: "
                    + settings_ui_color_names[settings_opponent_ui_color_index],
                "settings_opponent_color", _title_right_x, _right_y + 162,
                _title_right_w, 44, true
            );
            _draw_action_button(
                settings_debug_mode
                    ? "DEBUG TOOLS: SHOWN" : "DEBUG TOOLS: HIDDEN",
                "settings_debug", _title_right_x, _right_y + 216,
                _title_right_w, 44, true
            );
            _draw_action_button(
                settings_context_help
                    ? "CONTEXT HELP: SHOWN" : "CONTEXT HELP: HIDDEN",
                "settings_context_help", _title_right_x, _right_y + 270,
                _title_right_w, 44, true
            );
            _draw_action_button(
                settings_first_game_guidance
                    ? "FIRST-GAME GUIDANCE: ON"
                    : "FIRST-GAME GUIDANCE: OFF",
                "settings_guidance", _title_right_x, _right_y + 324,
                _title_right_w, 44, true
            );
            _draw_action_button(
                "RESTORE FIRST-TIME HINTS",
                "settings_restore_guidance",
                _title_right_x, _right_y + 378,
                _title_right_w, 44, true
            );
        }
        for (var _title_field_index = 0;
             _title_field_index < array_length(_title_name_fields);
             _title_field_index++) {
            var _title_field = _title_name_fields[_title_field_index];
            draw_set_halign(fa_left);
            draw_set_valign(fa_top);
            draw_set_color(ui_color_muted);
            draw_text(_title_right_x, _title_field.y, _title_field.label);
            var _title_field_y = _title_field.y + 22;
            draw_set_color(ui_color_panel_alt);
            draw_rectangle(
                _title_right_x,
                _title_field_y,
                _title_right_x + _title_right_w,
                _title_field_y + 42,
                false
            );
            var _title_field_editing =
                (title_name_editing == 1
                    && _title_field.kind == "title_name_p1")
                || (title_name_editing == 2
                    && _title_field.kind == "title_name_p2")
                || (title_name_editing == 3
                    && _title_field.kind == "title_network_address");
            draw_set_color(_title_field_editing
                ? ui_color_selected : ui_color_line);
            draw_rectangle(
                _title_right_x,
                _title_field_y,
                _title_right_x + _title_right_w,
                _title_field_y + 42,
                true
            );
            draw_set_halign(fa_center);
            draw_set_valign(fa_middle);
            draw_set_color(ui_color_text);
            draw_text(
                _title_right_x + _title_right_w * 0.5,
                _title_field_y + 21,
                _title_field.value
            );
            _add_hit_region(
                _title_field.kind,
                0,
                undefined,
                _title_right_x,
                _title_field_y,
                _title_right_w,
                42
            );
        }
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        if (title_context_mode == "ai"
        || title_context_mode == "hotseat"
        || title_context_mode == "ai_watch") {
            _draw_action_button(
                "PLAY",
                "title_play_context",
                _title_right_x,
                _title_content_bottom - 52,
                _title_right_w,
                48,
                true
            );
        }
        draw_set_halign(fa_center);
        draw_set_color(ui_color_muted);
        draw_text(
            _screen_width * 0.5,
            _title_panel_y + _title_panel_h - 24,
            variable_global_exists("loc_regression_last")
                ? "Regression: "
                    + string(global.loc_regression_last.passed) + " passed, "
                    + string(global.loc_regression_last.failed) + " failed"
                : (variable_global_exists("loc_batch_last_summary")
                    ? "Last batch complete; report path printed to output"
                    : "Press R at any time to restart")
        );
        draw_set_halign(fa_left);

        if (settings_menu_active) {
            draw_set_alpha(0.96);
            draw_set_color(ui_color_background);
            draw_rectangle(0, 0, _screen_width, _screen_height, false);
            draw_set_alpha(1);
            _add_hit_region("settings_background", 0, undefined,
                0, 0, _screen_width, _screen_height);
            var _settings_w = min(600, _screen_width - 80);
            var _settings_h = 550;
            var _settings_x = floor((_screen_width - _settings_w) * 0.5);
            var _settings_y = floor((_screen_height - _settings_h) * 0.5);
            _draw_modal_panel(_settings_x, _settings_y,
                _settings_x + _settings_w, _settings_y + _settings_h,
                "SETTINGS");
            var _settings_button_x = _settings_x + 70;
            var _settings_button_w = _settings_w - 140;
            _draw_action_button(
                settings_default_center_far
                    ? "DEFAULT VIEW: FAR" : "DEFAULT VIEW: CLOSE",
                "settings_view", _settings_button_x, _settings_y + 72,
                _settings_button_w, 48, true);
            _draw_action_button(
                settings_default_camera_locked
                    ? "DEFAULT CAMERA: LOCKED" : "DEFAULT CAMERA: FREE",
                "settings_lock", _settings_button_x, _settings_y + 132,
                _settings_button_w, 48, true);
            _draw_action_button(
                "PLAYER 1 UI: " + settings_ui_color_names[settings_ui_color_index],
                "settings_color", _settings_button_x, _settings_y + 192,
                _settings_button_w, 48, true);
            _draw_action_button(
                "PLAYER 2 UI: "
                    + settings_ui_color_names[settings_opponent_ui_color_index],
                "settings_opponent_color", _settings_button_x,
                _settings_y + 252, _settings_button_w, 48, true);
            _draw_action_button(
                settings_debug_mode
                    ? "DEBUG TOOLS: SHOWN" : "DEBUG TOOLS: HIDDEN",
                "settings_debug", _settings_button_x, _settings_y + 312,
                _settings_button_w, 48, true);
            _draw_action_button(
                settings_context_help
                    ? "CONTEXT HELP: SHOWN" : "CONTEXT HELP: HIDDEN",
                "settings_context_help", _settings_button_x,
                _settings_y + 372, _settings_button_w, 48, true);
            _draw_action_button("BACK", "settings_back",
                _settings_button_x, _settings_y + 450,
                _settings_button_w, 48, true);
        }

        if (batch_menu_active) {
            draw_set_alpha(0.98);
            draw_set_color(ui_color_background);
            draw_rectangle(0, 0, _screen_width, _screen_height, false);
            draw_set_alpha(1);
            _add_hit_region(
                "batch_background",
                0,
                undefined,
                0,
                0,
                _screen_width,
                _screen_height
            );
            var _batch_panel_w = min(860, _screen_width - 120);
            var _batch_panel_h = min(650, _screen_height - 100);
            var _batch_panel_x = floor(
                (_screen_width - _batch_panel_w) * 0.5
            );
            var _batch_panel_y = floor(
                (_screen_height - _batch_panel_h) * 0.5
            );
            _draw_modal_panel(
                _batch_panel_x,
                _batch_panel_y,
                _batch_panel_x + _batch_panel_w,
                _batch_panel_y + _batch_panel_h,
                "AI BATCH TESTS"
            );
            draw_set_halign(fa_center);
            draw_set_color(ui_color_text);
            draw_text(
                _screen_width * 0.5,
                _batch_panel_y + 58,
                "Choose a favored faction for each AI."
            );
            draw_set_color(ui_color_muted);
            draw_text(
                _screen_width * 0.5,
                _batch_panel_y + 84,
                "NONE uses the normal adaptable synergy model."
            );
            var _batch_control_w = floor(
                (_batch_panel_w - 90) * 0.5
            );
            var _batch_left_x = _batch_panel_x + 30;
            var _batch_right_x = _batch_panel_x
                + _batch_panel_w - 30 - _batch_control_w;
            draw_set_halign(fa_left);
            _draw_action_button(
                "P1 FAVOR: " + batch_profile_label(
                    batch_profile_options[batch_profile_p1_index]
                ),
                "batch_cycle_p1",
                _batch_left_x,
                _batch_panel_y + 125,
                _batch_control_w,
                52,
                true
            );
            _draw_action_button(
                "P2 FAVOR: " + batch_profile_label(
                    batch_profile_options[batch_profile_p2_index]
                ),
                "batch_cycle_p2",
                _batch_right_x,
                _batch_panel_y + 125,
                _batch_control_w,
                52,
                true
            );
            _draw_action_button(
                "PAIRED SEEDS: " + string(
                    batch_game_options[batch_game_option_index]
                ),
                "batch_cycle_games",
                _batch_left_x,
                _batch_panel_y + 197,
                _batch_control_w,
                52,
                true
            );
            _draw_action_button(
                batch_detailed_logs
                    ? "DETAILED JOURNALS: ON"
                    : "DETAILED JOURNALS: OFF",
                "batch_toggle_logs",
                _batch_right_x,
                _batch_panel_y + 197,
                _batch_control_w,
                52,
                true
            );
            _add_hit_region(
                "batch_seed_field",
                0,
                undefined,
                _batch_left_x,
                _batch_panel_y + 259,
                _batch_left_x + _batch_control_w,
                _batch_panel_y + 305
            );
            draw_set_color(ui_color_panel);
            draw_rectangle(
                _batch_left_x,
                _batch_panel_y + 259,
                _batch_left_x + _batch_control_w,
                _batch_panel_y + 305,
                false
            );
            draw_set_color(batch_seed_editing
                ? ui_color_selected : ui_color_line);
            draw_rectangle(
                _batch_left_x,
                _batch_panel_y + 259,
                _batch_left_x + _batch_control_w,
                _batch_panel_y + 305,
                true
            );
            draw_set_color(ui_color_text);
            draw_set_halign(fa_center);
            draw_text(
                _batch_left_x + _batch_control_w * 0.5,
                _batch_panel_y + 282,
                "SEED: " + (batch_seed_text == ""
                    ? "RANDOM" : batch_seed_text)
            );
            draw_set_halign(fa_center);
            draw_set_color(ui_color_muted);
            draw_text_ext(
                _screen_width * 0.5,
                _batch_panel_y + 320,
                batch_detailed_logs
                    ? "Detailed mode preserves per-match rules and AI traces, "
                        + "but is substantially slower."
                    : "Fast mode writes aggregate checkpoints after every match.",
                18,
                _batch_panel_w - 90
            );
            draw_set_halign(fa_left);
            _draw_action_button(
                "RUN SELECTED MATCHUP",
                "batch_run_single",
                _batch_left_x,
                _batch_panel_y + 380,
                _batch_control_w,
                62,
                true
            );
            _draw_action_button(
                "RUN FULL PAIRED MATRIX",
                "batch_run_matrix",
                _batch_right_x,
                _batch_panel_y + 380,
                _batch_control_w,
                62,
                true
            );
            draw_set_halign(fa_center);
            draw_set_color(ui_color_text);
            draw_text(
                _screen_width * 0.5,
                _batch_panel_y + 466,
                "Selected run: "
                + string(batch_game_options[batch_game_option_index]) + " pairs / "
                + string(
                    batch_game_options[batch_game_option_index]
                    * (batch_profile_options[batch_profile_p1_index]
                        == batch_profile_options[batch_profile_p2_index]
                        ? 1 : 2)
                ) + " games   |   Matrix: "
                + string(
                    batch_game_options[batch_game_option_index]
                    * ((array_length(batch_profile_options)
                        * (array_length(batch_profile_options) + 1)) / 2)
                ) + " pairs / "
                + string(
                    batch_game_options[batch_game_option_index]
                    * array_length(batch_profile_options)
                    * array_length(batch_profile_options)
                ) + " games"
            );
            draw_set_halign(fa_left);
            _draw_action_button(
                "BACK",
                "batch_back",
                _screen_width * 0.5 - 130,
                _batch_panel_y + _batch_panel_h - 74,
                260,
                46,
                true
            );
            if (variable_global_exists("loc_batch_show_results")
            && global.loc_batch_show_results
            && variable_global_exists("loc_batch_state")) {
                var _report = global.loc_batch_state;
                ui_hit_regions = [];
                _draw_modal_panel(
                    _batch_panel_x,
                    _batch_panel_y,
                    _batch_panel_x + _batch_panel_w,
                    _batch_panel_y + _batch_panel_h,
                    "BATCH RESULTS"
                );
                draw_set_halign(fa_center);
                draw_set_color(ui_color_text);
                draw_text(
                    _screen_width * 0.5,
                    _batch_panel_y + 55,
                    string(_report.completed) + " games processed ("
                    + string(_report.paired_seeds_per_matchup)
                    + " per seat matchup) | faction starters "
                    + (_report.faction_starters_enabled ? "ON" : "OFF")
                );
                var _matrix_profiles = ["", "GF", "SP", "CZ"];
                var _matrix_profile_count = array_length(_matrix_profiles);
                batch_report_page = clamp(
                    batch_report_page,
                    0,
                    _matrix_profile_count
                );
                var _matrix_profile_color = function(_profile) {
                    switch (_profile) {
                        case "GF": return LOC_COLOR_GF;
                        case "SP": return LOC_COLOR_SP;
                        case "CZ": return LOC_COLOR_CZ;
                        case "BH": return LOC_COLOR_BH;
                        case "PZ": return LOC_COLOR_PZ;
                        default: return LOC_COLOR_NEUTRAL;
                    }
                };
                if (batch_report_page == 0) {
                var _matrix_left = _batch_panel_x + 82;
                var _matrix_top = _batch_panel_y + 105;
                var _matrix_cell_w = floor(
                    (_batch_panel_w - 112) / _matrix_profile_count
                );
                var _matrix_cell_h = 65;
                draw_set_color(ui_color_muted);
                draw_text(_batch_panel_x + 42, _matrix_top - 31, "P2");
                draw_text(_matrix_left - 37, _matrix_top - 54, "P1");
                for (var _matrix_col = 0;
                     _matrix_col < _matrix_profile_count;
                     _matrix_col++) {
                    draw_set_halign(fa_center);
                    draw_set_color(_matrix_profile_color(
                        _matrix_profiles[_matrix_col]
                    ));
                    draw_text(
                        _matrix_left + _matrix_col * _matrix_cell_w
                            + _matrix_cell_w * 0.5,
                        _matrix_top - 25,
                        batch_profile_label(_matrix_profiles[_matrix_col])
                    );
                }
                for (var _matrix_row = 0;
                     _matrix_row < _matrix_profile_count;
                     _matrix_row++) {
                    draw_set_halign(fa_center);
                    draw_set_color(_matrix_profile_color(
                        _matrix_profiles[_matrix_row]
                    ));
                    draw_text(
                        _batch_panel_x + 42,
                        _matrix_top + _matrix_row * _matrix_cell_h
                            + _matrix_cell_h * 0.5,
                        batch_profile_label(_matrix_profiles[_matrix_row])
                    );
                    for (var _matrix_col = 0;
                         _matrix_col < _matrix_profile_count;
                         _matrix_col++) {
                        var _cell_valid = 0;
                        var _cell_invalid = 0;
                        var _cell_p1_wins = 0;
                        var _cell_draws = 0;
                        for (var _cell_result_index = 0;
                             _cell_result_index < array_length(_report.results);
                             _cell_result_index++) {
                            var _cell_result =
                                _report.results[_cell_result_index];
                            if (_cell_result.p1_profile
                                == _matrix_profiles[_matrix_col]
                            && _cell_result.p2_profile
                                == _matrix_profiles[_matrix_row]) {
                                if (_cell_result.valid) {
                                    _cell_valid += 1;
                                    _cell_p1_wins +=
                                        _cell_result.winner == 1 ? 1 : 0;
                                    _cell_draws +=
                                        _cell_result.winner == 0 ? 1 : 0;
                                } else {
                                    _cell_invalid += 1;
                                }
                            }
                        }
                        var _cell_x = _matrix_left
                            + _matrix_col * _matrix_cell_w;
                        var _cell_y = _matrix_top
                            + _matrix_row * _matrix_cell_h;
                        draw_set_color(_cell_invalid > 0
                            ? make_color_rgb(105, 31, 38)
                            : ui_color_panel_alt);
                        draw_rectangle(
                            _cell_x + 2,
                            _cell_y + 2,
                            _cell_x + _matrix_cell_w - 2,
                            _cell_y + _matrix_cell_h - 2,
                            false
                        );
                        draw_set_color(_cell_invalid > 0
                            ? ui_color_error : ui_color_line);
                        draw_rectangle(
                            _cell_x + 2,
                            _cell_y + 2,
                            _cell_x + _matrix_cell_w - 2,
                            _cell_y + _matrix_cell_h - 2,
                            true
                        );
                        var _cell_win_rate = _cell_valid > 0
                            ? 100 * _cell_p1_wins / _cell_valid : 0;
                        draw_set_color(_cell_valid > 0
                            ? merge_color(
                                c_white,
                                make_color_rgb(65, 255, 115),
                                _cell_win_rate / 100
                            )
                            : ui_color_muted);
                        draw_set_font(FNT_METROID);
                        draw_set_valign(fa_middle);
                        var _cell_text_scale = batch_report_show_counts
                            ? 0.85 : 1.5;
                        draw_text_transformed(
                            _cell_x + _matrix_cell_w * 0.5,
                            _cell_y + _matrix_cell_h * 0.5,
                            _cell_valid > 0
                                ? (batch_report_show_counts
                                    ? string(_cell_p1_wins) + "/"
                                        + string(
                                            _cell_valid
                                            - _cell_p1_wins
                                            - _cell_draws
                                        )
                                        + " - " + string(_cell_draws)
                                    : string(floor(_cell_win_rate)) + "%")
                                : "--",
                            _cell_text_scale,
                            _cell_text_scale,
                            0
                        );
                        draw_set_valign(fa_top);
                        draw_set_font(-1);
                    }
                }
                _draw_action_button(
                    batch_report_show_counts
                        ? "SHOW PERCENTAGES"
                        : "SHOW W/L - D",
                    "batch_toggle_report_value",
                    _screen_width * 0.5 - 130,
                    _batch_panel_y + _batch_panel_h - 108,
                    260,
                    42,
                    true
                );
                } else {
                    var _detail_profile =
                        _matrix_profiles[batch_report_page - 1];
                    var _detail = batch_build_profile_report(
                        _report,
                        _detail_profile
                    );
                    var _detail_games = max(1, _detail.games);
                    var _detail_color = _matrix_profile_color(
                        _detail_profile
                    );
                    draw_set_halign(fa_center);
                    draw_set_font(FNT_METROID);
                    draw_set_color(_detail_color);
                    draw_text_transformed(
                        _screen_width * 0.5,
                        _batch_panel_y + 96,
                        batch_profile_label(_detail_profile),
                        2,
                        2,
                        0
                    );
                    draw_set_font(-1);
                    draw_set_color(ui_color_text);
                    draw_text(
                        _screen_width * 0.5,
                        _batch_panel_y + 145,
                        string(_detail.games) + " games  |  "
                        + string(_detail.wins) + "-"
                        + string(_detail.losses) + "-"
                        + string(_detail.draws) + "  |  Point rate "
                        + string_format(
                            100 * (_detail.wins + _detail.draws * 0.5)
                                / _detail_games,
                            0,
                            1
                        ) + "%"
                    );
                    var _detail_left = _batch_panel_x + 70;
                    var _detail_mid = _screen_width * 0.5;
                    var _detail_right = _batch_panel_x + _batch_panel_w - 70;
                    var _detail_top = _batch_panel_y + 190;
                    draw_set_halign(fa_left);
                    draw_set_color(ui_color_title);
                    draw_text(_detail_left, _detail_top, "BEHAVIOR PER GAME");
                    draw_set_color(ui_color_text);
                    draw_text(
                        _detail_left,
                        _detail_top + 34,
                        "Research: " + string_format(
                            _detail.research / _detail_games, 0, 2
                        )
                        + "\nMetroids scored: " + string_format(
                            _detail.metroids / _detail_games, 0, 2
                        )
                        + "\nCaptures: " + string_format(
                            _detail.captures / _detail_games, 0, 2
                        )
                        + "\nRaids initiated: " + string_format(
                            _detail.raids / _detail_games, 0, 2
                        )
                        + "\nRaid wins: " + string_format(
                            _detail.raid_wins / _detail_games, 0, 2
                        )
                        + "\nBreaches suffered: " + string_format(
                            _detail.breaches / _detail_games, 0, 2
                        )
                        + "\nPeak CP: " + string_format(
                            _detail.max_cp / _detail_games, 0, 2
                        )
                    );
                    draw_set_color(ui_color_title);
                    draw_text(_detail_mid - 70, _detail_top, "RESEARCH BY METROID");
                    var _detail_stage_names = [
                        "Larva", "Alpha", "Gamma", "Zeta", "Omega", "Hunter"
                    ];
                    draw_set_color(ui_color_text);
                    var _detail_stage_text = "";
                    for (var _detail_stage = 0;
                         _detail_stage < 6;
                         _detail_stage++) {
                        _detail_stage_text += _detail_stage_names[_detail_stage]
                            + ": "
                            + string(_detail.metroid_research[_detail_stage])
                            + (_detail_stage < 5 ? "\n" : "");
                    }
                    draw_text(
                        _detail_mid - 70,
                        _detail_top + 34,
                        _detail_stage_text
                    );
                    draw_set_color(ui_color_title);
                    draw_text(_detail_right - 235, _detail_top, "MATCHUPS");
                    draw_set_color(ui_color_text);
                    var _detail_matchup_text = "";
                    for (var _detail_opponent = 0;
                         _detail_opponent < _matrix_profile_count;
                         _detail_opponent++) {
                        var _opponent_games =
                            _detail.opponent_games[_detail_opponent];
                        _detail_matchup_text += batch_profile_label(
                            _matrix_profiles[_detail_opponent]
                        ) + ": " + (_opponent_games > 0
                            ? string_format(
                                100 * _detail.opponent_points[_detail_opponent]
                                    / _opponent_games,
                                0,
                                1
                            ) + "%"
                            : "--")
                            + (_detail_opponent < _matrix_profile_count - 1
                                ? "\n"
                                : "");
                    }
                    draw_text(
                        _detail_right - 235,
                        _detail_top + 34,
                        _detail_matchup_text
                    );
                    var _top_definition = get_card_definition(
                        _detail.top_card_id
                    );
                    draw_set_halign(fa_center);
                    draw_set_color(ui_color_muted);
                    draw_text(
                        _screen_width * 0.5,
                        _batch_panel_y + _batch_panel_h - 118,
                        "Most taken: " + (is_undefined(_top_definition)
                            ? "None"
                            : _top_definition.name + " ("
                                + string(_detail.top_card_count) + ")")
                        + "  |  Won " + string_format(
                            100 * _detail.raid_wins / max(1, _detail.raids),
                            0,
                            1
                        ) + "% of initiated raids"
                        + "  |  One breach every " + string_format(
                            _detail.games / max(1, _detail.breaches),
                            0,
                            1
                        ) + " games"
                    );
                }
                _draw_action_button(
                    "< PREVIOUS",
                    "batch_report_previous",
                    _screen_width * 0.5 - 300,
                    _batch_panel_y + _batch_panel_h - 62,
                    180,
                    42,
                    true
                );
                _draw_action_button(
                    "NEXT >",
                    "batch_report_next",
                    _screen_width * 0.5 - 90,
                    _batch_panel_y + _batch_panel_h - 62,
                    180,
                    42,
                    true
                );
                _draw_action_button(
                    "BACK",
                    "batch_back",
                    _screen_width * 0.5 + 120,
                    _batch_panel_y + _batch_panel_h - 62,
                    180,
                    42,
                    true
                );
            }
        }
    }

    if (network_lobby_active) {
        draw_set_alpha(1);
        draw_set_color(ui_color_menu_background);
        draw_rectangle(0, 0, _screen_width, _screen_height, false);
        var _lobby_w = min(760, _screen_width - 96);
        var _lobby_h = 520;
        var _lobby_x = floor((_screen_width - _lobby_w) * 0.5);
        var _lobby_y = floor((_screen_height - _lobby_h) * 0.5);
        draw_set_color(ui_color_menu_panel);
        draw_rectangle(
            _lobby_x,
            _lobby_y,
            _lobby_x + _lobby_w,
            _lobby_y + _lobby_h,
            false
        );
        draw_set_color(ui_color_menu_line);
        draw_rectangle(
            _lobby_x,
            _lobby_y,
            _lobby_x + _lobby_w,
            _lobby_y + _lobby_h,
            true
        );
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_font(FNT_METROID);
        draw_set_color(ui_color_title);
        draw_text_transformed(
            _screen_width * 0.5,
            _lobby_y + 70,
            net_role == "host" ? "HOST NETWORK GAME" : "JOIN NETWORK GAME",
            2,
            2,
            0
        );
        draw_set_font(-1);
        draw_set_color(ui_color_text);
        draw_text(
            _screen_width * 0.5,
            _lobby_y + 132,
            net_status
        );
        if (net_role == "client") {
            draw_set_color(ui_color_muted);
            draw_text(_screen_width * 0.5, _lobby_y + 160, "PLAYER NAME");
            draw_set_color(ui_color_panel_alt);
            draw_rectangle(
                _lobby_x + 110,
                _lobby_y + 180,
                _lobby_x + _lobby_w - 110,
                _lobby_y + 228,
                false
            );
            draw_set_color(net_join_field == "name"
                ? ui_color_selected
                : ui_color_line);
            draw_rectangle(
                _lobby_x + 110,
                _lobby_y + 180,
                _lobby_x + _lobby_w - 110,
                _lobby_y + 228,
                true
            );
            draw_set_color(ui_color_text);
            draw_text(
                _screen_width * 0.5,
                _lobby_y + 204,
                net_player_name
            );
            _add_hit_region(
                "network_name_field",
                0,
                undefined,
                _lobby_x + 110,
                _lobby_y + 180,
                _lobby_w - 220,
                48
            );
            draw_set_color(ui_color_muted);
            draw_text(
                _screen_width * 0.5,
                _lobby_y + 258,
                "HOST ADDRESS"
            );
            draw_set_color(ui_color_panel_alt);
            draw_rectangle(
                _lobby_x + 110,
                _lobby_y + 278,
                _lobby_x + _lobby_w - 110,
                _lobby_y + 326,
                false
            );
            draw_set_color(net_join_field == "address"
                ? ui_color_selected
                : ui_color_line);
            draw_rectangle(
                _lobby_x + 110,
                _lobby_y + 278,
                _lobby_x + _lobby_w - 110,
                _lobby_y + 326,
                true
            );
            draw_set_color(ui_color_text);
            draw_text(
                _screen_width * 0.5,
                _lobby_y + 302,
                net_ip_input
            );
            _add_hit_region(
                "network_address_field",
                0,
                undefined,
                _lobby_x + 110,
                _lobby_y + 278,
                _lobby_w - 220,
                48
            );
            draw_set_color(ui_color_muted);
            draw_text(
                _screen_width * 0.5,
                _lobby_y + 346,
                "TCP port " + string(net_port)
            );
            draw_set_halign(fa_left);
            draw_set_valign(fa_top);
            _draw_action_button(
                "CONNECT",
                "network_connect",
                _screen_width * 0.5 - 130,
                _lobby_y + 382,
                260,
                50,
                net_join_field != ""
            );
        } else {
            draw_set_color(ui_color_muted);
            draw_text(
                _screen_width * 0.5,
                _lobby_y + 208,
                "Hosting as " + net_player_name
            );
            draw_text(
                _screen_width * 0.5,
                _lobby_y + 248,
                "Give Player 2 your LAN or public IPv4 address."
            );
            draw_text(
                _screen_width * 0.5,
                _lobby_y + 280,
                "TCP port " + string(net_port)
            );
        }
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        _draw_action_button(
            "BACK",
            "network_back",
            _lobby_x + 24,
            _lobby_y + _lobby_h - 62,
            120,
            38,
            true
        );
    }

    // Target help reports only the legality of the target under the pointer. It
    // does not move target-specific failures onto the initiating action button.
    if (settings_context_help
    && ui_hover_kind == "metroid"
    && !is_undefined(pending_choice)
    && pending_choice.kind == "capture_metroid") {
        var _target_help_metroid = get_sr388_metroid_for_choice(ui_hover_index);
        var _target_help_player = game_state.players[game_state.active_player];
        var _target_help_ship = pending_choice.ship_index >= 0
            && pending_choice.ship_index
                < array_length(_target_help_player.board.ships)
            ? _target_help_player.board.ships[pending_choice.ship_index]
            : undefined;
        if (!is_undefined(_target_help_metroid)
        && !is_undefined(_target_help_ship)) {
            var _target_help_security = get_card_stat(_target_help_ship);
            var _target_help_hazard = _target_help_metroid.definition.hazard;
            var _target_help_title = "CAPTURE "
                + string_upper(_target_help_metroid.definition.name);
            var _target_help_text = _target_help_ship.definition.name
                + " has " + string(_target_help_security) + " Security. "
                + _target_help_metroid.definition.name + " has "
                + string(_target_help_hazard) + " Hazard.";
            var _target_help_unavailable = "";
            if (_target_help_security < _target_help_hazard) {
                _target_help_unavailable = "not enough Security";
                _target_help_text += "\n(" + _target_help_unavailable + ")";
            }
            var _target_help_width = 460;
            var _target_help_x1 = _main_left + 10;
            var _target_help_x2 = _target_help_x1 + _target_help_width;
            var _target_help_y1 = _content_top + 8;
            var _target_help_body_width = _target_help_width - 20;
            var _target_help_line_spacing = 22;
            draw_set_font(FNT_METROID);
            var _target_help_body_height = string_height_ext(
                _target_help_text,
                _target_help_line_spacing,
                _target_help_body_width
            );
            var _target_help_y2 = _target_help_y1
                + max(92, 34 + _target_help_body_height + 12);
            draw_set_alpha(0.68);
            draw_set_color(c_black);
            draw_rectangle(
                _target_help_x1,
                _target_help_y1,
                _target_help_x2,
                _target_help_y2,
                false
            );
            draw_set_alpha(0.72);
            draw_set_color(ui_color_title);
            draw_rectangle(
                _target_help_x1,
                _target_help_y1,
                _target_help_x2,
                _target_help_y2,
                true
            );
            draw_set_alpha(1);
            draw_set_color(ui_color_title);
            draw_text(
                _target_help_x1 + 10,
                _target_help_y1 + 7,
                _target_help_title
            );
            draw_set_color(
                _target_help_unavailable == ""
                    ? ui_color_text
                    : ui_color_muted
            );
            draw_text_ext(
                _target_help_x1 + 10,
                _target_help_y1 + 34,
                _target_help_text,
                _target_help_line_spacing,
                _target_help_body_width
            );
            draw_set_font(-1);
        }
    }

    // Hover help uses the board's upper-left corner formerly occupied by
    // transmissions. Mandatory action prompts remain centered above the board.
    if (settings_context_help
    && ui_hover_kind == "action" && ui_hover_index != "") {
        var _tooltip_region = undefined;
        for (var _tooltip_region_index = array_length(ui_hit_regions) - 1;
             _tooltip_region_index >= 0;
             _tooltip_region_index--) {
            var _tooltip_region_candidate = ui_hit_regions[_tooltip_region_index];
            if (_tooltip_region_candidate.kind == "action"
            && _tooltip_region_candidate.index == ui_hover_index) {
                _tooltip_region = _tooltip_region_candidate;
                break;
            }
        }

        if (!is_undefined(_tooltip_region)) {
            var _tooltip_action = string(_tooltip_region.action);
            var _tooltip_title = "";
            var _tooltip_body = "";
            var _tooltip_unavailable = "";
            var _tooltip_player = game_state.players[game_state.active_player];
            var _tooltip_context_kind = variable_struct_exists(
                _tooltip_region,
                "context_kind"
            ) ? _tooltip_region.context_kind : "";
            var _tooltip_context_index = variable_struct_exists(
                _tooltip_region,
                "context_index"
            ) ? _tooltip_region.context_index : -1;
            var _tooltip_source = undefined;
            if (_tooltip_context_kind != "") {
                if (_tooltip_context_kind == "shop"
                && _tooltip_context_index >= 0
                && _tooltip_context_index < array_length(game_state.shop_row)) {
                    _tooltip_source = game_state.shop_row[_tooltip_context_index];
                } else if (_tooltip_context_kind == "hand"
                && _tooltip_context_index >= 0
                && _tooltip_context_index < array_length(_tooltip_player.hand)) {
                    _tooltip_source = _tooltip_player.hand[_tooltip_context_index];
                } else {
                    _tooltip_source = get_ability_source(
                        _tooltip_context_kind,
                        _tooltip_context_index
                    );
                }
            }

            switch (_tooltip_action) {
                case "capture":
                    var _tooltip_capture_cost = get_capture_cost(_tooltip_player);
                    _tooltip_title = "CAPTURE";
                    _tooltip_body = "Pay " + string(_tooltip_capture_cost)
                        + " CP and exhaust this Ship to move a Metroid from SR388 onto it. "
                        + "Its Security must equal or exceed the Metroid's Hazard.";
                    if (_tooltip_player.command_points < _tooltip_capture_cost) {
                        _tooltip_unavailable = "not enough CP";
                    } else if (is_undefined(_tooltip_source)) {
                        _tooltip_unavailable = "no Ship selected";
                    } else if (!_tooltip_source.ready) {
                        _tooltip_unavailable = "Ship exhausted";
                    } else if (array_length(_tooltip_source.cargo) >= 1) {
                        _tooltip_unavailable = "cargo full";
                    } else {
                        var _tooltip_capture_target = false;
                        for (var _tooltip_capture_index = 0;
                             _tooltip_capture_index < 5;
                             _tooltip_capture_index++) {
                            if (can_capture_metroid(
                                _tooltip_context_index,
                                _tooltip_capture_index
                            )) {
                                _tooltip_capture_target = true;
                                break;
                            }
                        }
                        if (!_tooltip_capture_target) {
                            _tooltip_unavailable = "no valid targets";
                        }
                    }
                    break;

                case "raid":
                    var _tooltip_raid_cost = get_raid_cost(_tooltip_player);
                    _tooltip_title = "RAID";
                    _tooltip_body = "Pay " + string(_tooltip_raid_cost)
                        + " CP and exhaust this Ship to attack an opposing Ship. "
                        + "Both players may contribute ready Characters. Win to capture its Metroid if you have room.";
                    if (_tooltip_player.command_points < _tooltip_raid_cost) {
                        _tooltip_unavailable = "not enough CP";
                    } else if (is_undefined(_tooltip_source)) {
                        _tooltip_unavailable = "no Ship selected";
                    } else if (!_tooltip_source.ready) {
                        _tooltip_unavailable = "Ship exhausted";
                    } else if (array_length(
                        game_state.players[1 - game_state.active_player].board.ships
                    ) <= 0) {
                        _tooltip_unavailable = "no valid targets";
                    }
                    break;

                case "deploy":
                    _tooltip_title = "DEPLOY";
                    _tooltip_body = "Pay this card's Deploy cost to put it into play immediately.";
                    if (!is_undefined(_tooltip_source)) {
                        var _tooltip_deploy_cost = get_modified_deploy_cost(
                            _tooltip_player,
                            _tooltip_source
                        );
                        if (_tooltip_source.definition.type == "event"
                        || !is_real(_tooltip_deploy_cost)) {
                            _tooltip_unavailable = "cannot be deployed";
                        } else if (_tooltip_player.command_points
                            < _tooltip_deploy_cost) {
                            _tooltip_unavailable = "not enough CP";
                        }
                    }
                    break;

                case "reserve":
                    _tooltip_title = "RESERVE";
                    _tooltip_body = "Pay this card's Reserve cost to put it into your discard pile for later use.";
                    if (!is_undefined(_tooltip_source)) {
                        var _tooltip_reserve_cost = get_modified_reserve_cost(
                            _tooltip_player,
                            _tooltip_source
                        );
                        if (!is_real(_tooltip_reserve_cost)) {
                            _tooltip_unavailable = "cannot be reserved";
                        } else if (_tooltip_player.command_points
                            < _tooltip_reserve_cost) {
                            _tooltip_unavailable = "not enough CP";
                        }
                    }
                    break;

                case "play":
                    _tooltip_title = "PLAY";
                    if (!is_undefined(_tooltip_source)
                    && _tooltip_source.definition.type == "event") {
                        _tooltip_body = "Play this Event, resolve its effect, then discard it.";
                        if (_tooltip_player.event_played_this_turn) {
                            _tooltip_unavailable = "Event already played this turn";
                        }
                    } else {
                        _tooltip_body = "Pay this card's Reserve cost to put it into play from your hand.";
                        if (!is_undefined(_tooltip_source)) {
                            var _tooltip_play_cost = _tooltip_source.definition.costs.reserve;
                            if (!is_real(_tooltip_play_cost)) {
                                _tooltip_unavailable = "cannot be played";
                            } else {
                                _tooltip_play_cost = max(
                                    0,
                                    _tooltip_play_cost
                                        - get_zebes_discount(
                                            _tooltip_player,
                                            _tooltip_source
                                        )
                                );
                                if (_tooltip_player.command_points
                                    < _tooltip_play_cost) {
                                    _tooltip_unavailable = "not enough CP";
                                }
                            }
                        }
                    }
                    break;

                case "salvage":
                    _tooltip_title = "SALVAGE";
                    _tooltip_body = "Discard this ready permanent to gain half its Reserve cost, rounded down.";
                    if (!is_undefined(_tooltip_source) && !_tooltip_source.ready) {
                        _tooltip_unavailable = "card exhausted";
                    }
                    break;

                case "refresh_hand":
                    _tooltip_title = "REFRESH HAND";
                    _tooltip_body = "Pay 1 CP, choose cards to discard, then draw until you have five cards.";
                    if (_tooltip_player.command_points < 1) {
                        _tooltip_unavailable = "not enough CP";
                    }
                    break;

                case "refresh_shop":
                    _tooltip_title = "REFRESH SHOP";
                    _tooltip_body = "Pay 1 CP to discard every card in the Shop and deal five replacements.";
                    if (_tooltip_player.command_points < 1) {
                        _tooltip_unavailable = "not enough CP";
                    }
                    break;

                case "end_turn":
                    _tooltip_title = "END TURN";
                    _tooltip_body = "End your Action phase, advance the Mutation Track, then pass the turn.";
                    break;

                default:
                    if (string_pos("activate_", _tooltip_action) == 1
                    && !is_undefined(_tooltip_source)) {
                        var _tooltip_ability_index = real(
                            string_delete(_tooltip_action, 1, 9)
                        );
                        var _tooltip_abilities = get_activated_abilities(
                            _tooltip_source
                        );
                        if (_tooltip_ability_index >= 0
                        && _tooltip_ability_index
                            < array_length(_tooltip_abilities)) {
                            var _tooltip_ability = _tooltip_abilities[
                                _tooltip_ability_index
                            ];
                            _tooltip_title = _tooltip_ability.label;
                            _tooltip_body = _tooltip_ability.prompt != ""
                                ? _tooltip_ability.prompt
                                : "Resolve this card's activated effect.";
                            switch (_tooltip_ability.effect_kind) {
                                case "gain_cp": _tooltip_body = "Gain 1 CP."; break;
                                case "raid_defense_1": _tooltip_body = "Gain +1 defense during this raid."; break;
                                case "corrupt_all": _tooltip_body = "Put a Phazon token on every other permanent in play."; break;
                                case "prepare_bh_refund": _tooltip_body = "The next Bounty Hunter you play this turn refunds 1 CP."; break;
                                case "prepare_gf_double": _tooltip_body = "Double the next Galactic Federation activated effect you use this turn."; break;
                                case "ped_strength": _tooltip_body = "Remove a Phazon token from this Character to gain Strength this turn."; break;
                            }
                            if (_tooltip_player.command_points
                                < _tooltip_ability.cost_cp) {
                                _tooltip_unavailable = "not enough CP";
                            } else if (_tooltip_ability.cost_exhaust
                            && !_tooltip_source.ready) {
                                _tooltip_unavailable = "card exhausted";
                            } else if (!_tooltip_region.enabled) {
                                var _tooltip_shared_bsl =
                                    _tooltip_ability.effect_kind
                                        == "reserve_shop_event_free";
                                if (_tooltip_source.controller
                                    != game_state.priority_player
                                && !_tooltip_shared_bsl) {
                                    _tooltip_unavailable =
                                        "opponent has priority";
                                } else if (_tooltip_ability.effect_kind
                                    == "raid_defense_1") {
                                    _tooltip_unavailable =
                                        "only while defending a raid";
                                } else if (_tooltip_ability.target_kind != "") {
                                    _tooltip_unavailable = "no valid targets";
                                }
                            }
                        }
                    }
                    break;
            }

            if (_tooltip_title != "") {
                var _tooltip_width = 460;
                var _tooltip_x1 = _main_left + 10;
                var _tooltip_x2 = _tooltip_x1 + _tooltip_width;
                var _tooltip_y1 = _content_top + 8;
                var _tooltip_text = _tooltip_body;
                if (_tooltip_unavailable != "") {
                    _tooltip_text += "\n(" + _tooltip_unavailable + ")";
                }
                var _tooltip_body_width = _tooltip_width - 20;
                var _tooltip_line_spacing = 22;
                draw_set_font(FNT_METROID);
                var _tooltip_body_height = string_height_ext(
                    _tooltip_text,
                    _tooltip_line_spacing,
                    _tooltip_body_width
                );
                var _tooltip_y2 = _tooltip_y1
                    + max(92, 34 + _tooltip_body_height + 12);
                draw_set_alpha(0.68);
                draw_set_color(c_black);
                draw_rectangle(
                    _tooltip_x1,
                    _tooltip_y1,
                    _tooltip_x2,
                    _tooltip_y2,
                    false
                );
                draw_set_alpha(0.72);
                draw_set_color(ui_color_title);
                draw_rectangle(
                    _tooltip_x1,
                    _tooltip_y1,
                    _tooltip_x2,
                    _tooltip_y2,
                    true
                );
                draw_set_alpha(1);
                draw_set_color(ui_color_title);
                draw_text(_tooltip_x1 + 10, _tooltip_y1 + 7, _tooltip_title);
                draw_set_color(
                    _tooltip_unavailable == ""
                        ? ui_color_text
                        : ui_color_muted
                );
                draw_text_ext(
                    _tooltip_x1 + 10,
                    _tooltip_y1 + 34,
                    _tooltip_text,
                    _tooltip_line_spacing,
                    _tooltip_body_width
                );
                draw_set_font(-1);
            }
        }
    }

    // Pause is deliberately the final overlay so it remains legible above card
    // zoom, drawers, and every other presentation layer.
    if (pause_screen_open) {
        ui_hit_regions = [];
        draw_set_alpha(0.72);
        draw_set_color(c_black);
        draw_rectangle(0, 0, _screen_width, _screen_height, false);
        draw_set_alpha(1);

        var _pause_w = pause_options_open
            ? min(600, _screen_width - 80)
            : 440;
        var _pause_h = pause_options_open ? 680 : 420;
        var _pause_x = floor((_screen_width - _pause_w) * 0.5);
        var _pause_y = floor((_screen_height - _pause_h) * 0.5);
        _draw_modal_panel(
            _pause_x,
            _pause_y,
            _pause_x + _pause_w,
            _pause_y + _pause_h,
            pause_options_open ? "OPTIONS" : "PAUSED"
        );

        if (pause_options_open) {
            var _pause_settings_x = _pause_x + 70;
            var _pause_settings_w = _pause_w - 140;
            _draw_action_button(
                settings_default_center_far
                    ? "DEFAULT VIEW: FAR" : "DEFAULT VIEW: CLOSE",
                "settings_view", _pause_settings_x, _pause_y + 72,
                _pause_settings_w, 48, true);
            _draw_action_button(
                settings_default_camera_locked
                    ? "DEFAULT CAMERA: LOCKED" : "DEFAULT CAMERA: FREE",
                "settings_lock", _pause_settings_x, _pause_y + 132,
                _pause_settings_w, 48, true);
            _draw_action_button(
                "PLAYER 1 UI: "
                    + settings_ui_color_names[settings_ui_color_index],
                "settings_color", _pause_settings_x, _pause_y + 192,
                _pause_settings_w, 48, true);
            _draw_action_button(
                "PLAYER 2 UI: "
                    + settings_ui_color_names[settings_opponent_ui_color_index],
                "settings_opponent_color", _pause_settings_x, _pause_y + 252,
                _pause_settings_w, 48, true);
            _draw_action_button(
                settings_debug_mode
                    ? "DEBUG TOOLS: SHOWN" : "DEBUG TOOLS: HIDDEN",
                "settings_debug", _pause_settings_x, _pause_y + 312,
                _pause_settings_w, 48, true);
            _draw_action_button(
                settings_context_help
                    ? "CONTEXT HELP: SHOWN" : "CONTEXT HELP: HIDDEN",
                "settings_context_help", _pause_settings_x, _pause_y + 372,
                _pause_settings_w, 48, true);
            _draw_action_button(
                settings_first_game_guidance
                    ? "FIRST-GAME GUIDANCE: ON"
                    : "FIRST-GAME GUIDANCE: OFF",
                "settings_guidance", _pause_settings_x, _pause_y + 432,
                _pause_settings_w, 48, true);
            _draw_action_button(
                "RESTORE FIRST-TIME HINTS", "settings_restore_guidance",
                _pause_settings_x, _pause_y + 492,
                _pause_settings_w, 48, true);
            _draw_action_button(
                "BACK", "settings_back", _pause_settings_x, _pause_y + 570,
                _pause_settings_w, 48, true);
        } else {
            var _pause_button_x = _pause_x + 28;
            var _pause_button_w = _pause_w - 56;
            var _pause_button_h = 48;
            _draw_action_button("RESUME", "pause_resume",
                _pause_button_x, _pause_y + 60,
                _pause_button_w, _pause_button_h, true);
            _draw_action_button("OPTIONS", "pause_options",
                _pause_button_x, _pause_y + 120,
                _pause_button_w, _pause_button_h, true);
            _draw_action_button("HELP / RULES", "pause_help",
                _pause_button_x, _pause_y + 180,
                _pause_button_w, _pause_button_h, true);
            _draw_action_button("BACK TO MENU", "pause_menu",
                _pause_button_x, _pause_y + 240,
                _pause_button_w, _pause_button_h, true);
            _draw_action_button("QUIT", "pause_quit",
                _pause_button_x, _pause_y + 300,
                _pause_button_w, _pause_button_h, true);
        }
    }

    if (!is_undefined(guidance_active)) {
        ui_hit_regions = [];
        draw_set_alpha(0.68);
        draw_set_color(c_black);
        draw_rectangle(0, 0, _screen_width, _screen_height, false);
        draw_set_alpha(1);

        var _guidance_w = min(680, _screen_width - 48);
        draw_set_font(FNT_METROID);
        var _guidance_body_w = _guidance_w - 56;
        var _guidance_body_h = string_height_ext(
            guidance_active.body,
            28,
            _guidance_body_w
        );
        var _guidance_h = min(
            _screen_height - 48,
            max(270, _guidance_body_h + 158)
        );
        var _guidance_x = floor((_screen_width - _guidance_w) * 0.5);
        var _guidance_y = floor((_screen_height - _guidance_h) * 0.5);
        _draw_modal_panel(
            _guidance_x,
            _guidance_y,
            _guidance_x + _guidance_w,
            _guidance_y + _guidance_h,
            "FIELD GUIDANCE / " + guidance_active.title
        );
        draw_set_font(FNT_METROID);
        draw_set_color(ui_color_text);
        draw_text_ext(
            _guidance_x + 28,
            _guidance_y + 68,
            guidance_active.body,
            28,
            _guidance_body_w
        );
        draw_set_font(-1);
        var _guidance_button_gap = 14;
        var _guidance_allow_disable = !variable_struct_exists(
            guidance_active,
            "allow_disable"
        ) || guidance_active.allow_disable;
        var _guidance_button_w = _guidance_allow_disable
            ? floor((_guidance_w - 56 - _guidance_button_gap) * 0.5)
            : min(260, _guidance_w - 56);
        var _guidance_button_y = _guidance_y + _guidance_h - 66;
        var _guidance_button_x = _guidance_allow_disable
            ? _guidance_x + 28
            : floor(_guidance_x + (_guidance_w - _guidance_button_w) * 0.5);
        _draw_action_button(
            "GOT IT",
            "guidance_ack",
            _guidance_button_x,
            _guidance_button_y,
            _guidance_button_w,
            42,
            true
        );
        if (_guidance_allow_disable) {
            _draw_action_button(
                "DISABLE GUIDANCE",
                "guidance_disable",
                _guidance_x + 28 + _guidance_button_w + _guidance_button_gap,
                _guidance_button_y,
                _guidance_button_w,
                42,
                true
            );
        }
    }

    if (help_page_open) {
        _draw_help_page(
            _screen_width,
            _screen_height,
            _draw_modal_panel,
            _draw_action_button,
            _add_hit_region
        );
    }

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_set_alpha(1);
}

