function loc_step() {
    /// @description Mouse interaction and optional rules-engine debug shortcuts.

    // Activated abilities may temporarily replace the Raid choice with their own
    // target or follow-up choice. Return to the same Raid window once that entire
    // ability sequence has finished.
    if (is_undefined(pending_choice)
    && !is_undefined(raid_suspended_choice)) {
        pending_choice = raid_suspended_choice;
        raid_suspended_choice = undefined;
        raid_validate_participants(pending_choice);
    }

    // Keep the application surface at one GUI pixel per window client pixel.
    // Resizing the window therefore reveals more or less of the camera viewport
    // instead of stretching the fixed board world.
    var _window_width = max(640, window_get_width());
    var _window_height = max(480, window_get_height());
    var _old_ui_height = ui_screen_height;
    var _old_board_viewport_right = board_viewport_right;
    var _window_resized = _window_width != ui_screen_width
        || _window_height != ui_screen_height;
    if (_window_resized) {
        ui_screen_width = _window_width;
        ui_screen_height = _window_height;
    }
    // GameMaker may recreate the application surface one frame after a native
    // maximize/restore. Verify its dimensions every frame rather than only on the
    // window-size transition.
    if (surface_exists(application_surface)
    && (surface_get_width(application_surface) != ui_screen_width
        || surface_get_height(application_surface) != ui_screen_height)) {
        surface_resize(
            application_surface,
            ui_screen_width,
            ui_screen_height
        );
    }
    display_set_gui_size(ui_screen_width, ui_screen_height);
    // The room itself is authored at 1920x1080, but the presentation is a dynamic
    // pixel-space viewport. Keep the active view and its port exactly matched to
    // the client/application surface so drawing and window mouse coordinates share
    // one coordinate system after every resize.
    if (ui_resize_camera < 0) {
        ui_resize_camera = camera_create_view(
            0,
            0,
            ui_screen_width,
            ui_screen_height,
            0,
            noone,
            -1,
            -1,
            -1,
            -1
        );
    }
    view_enabled = true;
    view_visible[0] = true;
    view_camera[0] = ui_resize_camera;
    view_xport[0] = 0;
    view_yport[0] = 0;
    view_wport[0] = ui_screen_width;
    view_hport[0] = ui_screen_height;
    camera_set_view_pos(ui_resize_camera, 0, 0);
    camera_set_view_size(
        ui_resize_camera,
        ui_screen_width,
        ui_screen_height
    );
    ui_hud_width = min(360, max(300, floor(ui_screen_width * 0.32)));
    board_viewport_right = max(
        320,
        ui_screen_width - ui_hud_width - 26
    );
    if (_window_resized) {
        // Preserve the same world-space point at the center of a free camera while
        // the viewport grows or shrinks. Locked framing recomputes its own preset.
        var _resize_zoom = max(0.01, board_camera_zoom);
        var _old_viewport_h = max(
            1,
            _old_ui_height - board_viewport_top
        );
        var _new_viewport_h = max(
            1,
            ui_screen_height - board_viewport_top
        );
        var _resize_dx = (
            _old_board_viewport_right - board_viewport_right
        ) / (_resize_zoom * 2);
        var _resize_dy = (
            _old_viewport_h - _new_viewport_h
        ) / (_resize_zoom * 2);
        board_camera_x += _resize_dx;
        board_camera_y += _resize_dy;
        board_camera_target_x += _resize_dx;
        board_camera_target_y += _resize_dy;
        board_camera_last_auto_focus = "";
        if (board_camera_locked) {
            board_camera_recenter_requested = true;
        }
    }
    var _ui_pointer_x = window_mouse_get_x();
    var _ui_pointer_y = window_mouse_get_y();
    var _log_margin = 19;
    var _log_content_top = 56;
    var _log_content_bottom = ui_screen_height - _log_margin;
    var _log_details_bottom = min(
        _log_content_top + max(110, floor(ui_screen_height * 0.44)),
        _log_content_bottom - 310
    );
    var _log_panel_top = _log_details_bottom + 54 + 106;
    var _pointer_over_event_log = !title_menu_active
        && !network_lobby_active
        && !test_tools_open
        && !pause_screen_open
        && game_state.game_mode != "batch"
        && _ui_pointer_x >= ui_screen_width - _log_margin - ui_hud_width
        && _ui_pointer_x <= ui_screen_width - _log_margin
        && _ui_pointer_y >= _log_panel_top
        && _ui_pointer_y <= _log_content_bottom - 52;
    if (_pointer_over_event_log) {
        var _event_scroll_delta = mouse_wheel_up() - mouse_wheel_down();
        if (_event_scroll_delta != 0) {
            event_log_scroll = clamp(
                event_log_scroll + (_event_scroll_delta * 3),
                0,
                max(0, array_length(game_state.event_log) - 1)
            );
        }
    }
    var _camera_input_allowed = !title_menu_active
        && !network_lobby_active
        && !test_tools_open
        && !pause_screen_open
        && game_state.game_mode != "batch"
        && !chat_input_active;
    var _pointer_over_board = _ui_pointer_x >= 0
        && _ui_pointer_x < board_viewport_right
        && _ui_pointer_y >= board_viewport_top
        && _ui_pointer_y < ui_screen_height;

    // Close framing preserves the authored 1080p composition as the window grows.
    // Use the smaller viewport scale so the complete local board still fits while
    // larger windows render it at a genuinely larger scale instead of exposing
    // proportionally more of the table world.
    var _get_close_camera_zoom = function() {
        var _close_base_w = max(1, board_layout_width);
        var _close_base_h = max(1, board_layout_height - board_viewport_top);
        return clamp(
            max(
                1,
                min(
                    board_viewport_right / _close_base_w,
                    (ui_screen_height - board_viewport_top) / _close_base_h
                )
            ),
            board_camera_min_zoom,
            board_camera_max_zoom
        );
    };

    if (_camera_input_allowed && !board_camera_locked && _pointer_over_board) {
        var _zoom_direction = mouse_wheel_up() - mouse_wheel_down();
        if (_zoom_direction != 0) {
            var _old_target_zoom = board_camera_target_zoom;
            var _world_under_pointer_x = board_camera_target_x
                + (_ui_pointer_x / max(0.01, _old_target_zoom));
            var _world_under_pointer_y = board_camera_target_y
                + ((_ui_pointer_y - board_viewport_top)
                    / max(0.01, _old_target_zoom));
            board_camera_target_zoom = clamp(
                board_camera_target_zoom * power(1.12, _zoom_direction),
                board_camera_min_zoom,
                board_camera_max_zoom
            );
            board_camera_target_x = _world_under_pointer_x
                - (_ui_pointer_x / board_camera_target_zoom);
            board_camera_target_y = _world_under_pointer_y
                - ((_ui_pointer_y - board_viewport_top)
                    / board_camera_target_zoom);
        }
        if (mouse_check_button_pressed(mb_right)) {
            board_camera_dragging = true;
            board_camera_drag_last_x = _ui_pointer_x;
            board_camera_drag_last_y = _ui_pointer_y;
        }
    }
    if (board_camera_locked) {
        board_camera_dragging = false;
    }
    if (!mouse_check_button(mb_right)) {
        board_camera_dragging = false;
    }
    if (board_camera_dragging) {
        var _camera_drag_dx = _ui_pointer_x - board_camera_drag_last_x;
        var _camera_drag_dy = _ui_pointer_y - board_camera_drag_last_y;
        board_camera_target_x -= _camera_drag_dx
            / max(0.01, board_camera_target_zoom);
        board_camera_target_y -= _camera_drag_dy
            / max(0.01, board_camera_target_zoom);
        board_camera_drag_last_x = _ui_pointer_x;
        board_camera_drag_last_y = _ui_pointer_y;
    }

    // Close framing follows the zone currently asking for input. Cross-table
    // interactions no longer default to Far when their legal targets occupy one
    // known board row.
    var _camera_cross_player_interaction = false;
    var _camera_focus_player = -1;
    var _camera_focus_zone = "";
    if (!is_undefined(pending_choice)) {
        _camera_cross_player_interaction = _camera_cross_player_interaction
            || pending_choice.kind == "raid"
            || pending_choice.kind == "raid_cargo";
        if (pending_choice.kind == "raid"
        && pending_choice.stage == "attacker_ship") {
            _camera_focus_player = game_state.active_player;
            _camera_focus_zone = "ship";
        } else if (pending_choice.kind == "chozo_ghosts_source") {
            _camera_focus_player = pending_choice.player_index;
            _camera_focus_zone = "all";
        } else if (pending_choice.kind == "chozo_ghosts_target") {
            _camera_focus_player = pending_choice.target_player_index;
            _camera_focus_zone = "character";
        } else if (pending_choice.kind == "ability_target"
        && variable_struct_exists(pending_choice, "target_kind")) {
            var _camera_target_kind = pending_choice.target_kind;
            if (_camera_target_kind == "ship"
            || _camera_target_kind == "ready_ship"
            || _camera_target_kind == "raided_other_ship") {
                _camera_focus_player = pending_choice.source.controller;
                _camera_focus_zone = "ship";
            } else if (_camera_target_kind == "opponent_character") {
                _camera_focus_player = 1 - pending_choice.source.controller;
                _camera_focus_zone = "character";
            } else if (_camera_target_kind == "opponent_permanent") {
                _camera_focus_player = 1 - pending_choice.source.controller;
                _camera_focus_zone = "all";
            } else {
                _camera_cross_player_interaction =
                    _camera_target_kind == "any_ship"
                || _camera_target_kind == "any_character"
                || _camera_target_kind == "dark_samus_character"
                || _camera_target_kind == "any_location"
                || _camera_target_kind == "another_character"
                || _camera_target_kind == "another_permanent"
                    || _camera_cross_player_interaction;
            }
        }
    }
    var _camera_target_side = _camera_focus_player < 0
        ? ""
        : (_camera_focus_player == game_state.view_player
            ? "local" : "opponent");
    var _camera_auto_focus = board_camera_center_far
        ? "far"
        : (_camera_focus_zone != ""
            ? "target_" + _camera_target_side + "_" + _camera_focus_zone
            : (_camera_cross_player_interaction
            ? "far_interaction"
            : (game_state.active_player == game_state.view_player
                ? "local"
                : "opponent")));
    if (_camera_input_allowed
    && board_camera_auto_center
    && (board_camera_locked || board_camera_recenter_requested)
    && board_camera_last_auto_focus != _camera_auto_focus) {
        board_camera_last_auto_focus = _camera_auto_focus;
        if (string_pos("target_", _camera_auto_focus) == 1) {
            var _focus_margin = 19;
            var _focus_header = 48;
            var _focus_gap = 10;
            var _focus_content_top = _focus_header + 8;
            var _focus_shared_h = floor(board_layout_height * 0.22);
            var _focus_shared_top = _focus_content_top
                + floor(board_layout_height * 0.17) + _focus_gap;
            var _focus_shared_bottom = _focus_shared_top + _focus_shared_h;
            var _focus_board_top = _focus_shared_bottom + _focus_gap;
            var _focus_board_bottom = board_layout_height - _focus_margin;
            var _focus_board_h = _focus_board_bottom - _focus_board_top;
            var _focus_opponent_bottom = _focus_shared_top - _focus_gap;
            var _focus_opponent_top = _focus_opponent_bottom - _focus_board_h;
            var _focus_local = _camera_target_side == "local";
            var _focus_play_top = (_focus_local
                ? _focus_board_top : _focus_opponent_top) + 54;
            var _focus_play_bottom = (_focus_local
                ? _focus_board_bottom : _focus_opponent_bottom) - 38;
            var _focus_card_w = _camera_focus_zone == "ship" ? 184 : 116;
            var _focus_card_h = _camera_focus_zone == "ship" ? 132 : 162;
            var _focus_cards = _camera_focus_player >= 0
                ? (_camera_focus_zone == "ship"
                    ? game_state.players[_camera_focus_player].board.ships
                    : game_state.players[_camera_focus_player].board.characters)
                : [];
            var _focus_count = array_length(_focus_cards);
            var _focus_zone_w;
            var _focus_zone_h;
            var _focus_center_x = board_camera_world_width * 0.5;
            var _focus_center_y;
            if (_camera_focus_zone == "all") {
                _focus_zone_w = board_camera_world_width - 70;
                _focus_zone_h = _focus_play_bottom - _focus_play_top;
                _focus_center_y = (_focus_play_top + _focus_play_bottom) * 0.5;
            } else {
                _focus_zone_w = _focus_card_w
                    + (max(0, _focus_count - 1) * (_focus_card_w + 10));
                _focus_zone_w = min(
                    board_camera_world_width - 70, _focus_zone_w
                );
                _focus_zone_h = _focus_card_h;
                if (_camera_focus_zone == "ship") {
                    _focus_center_y = _focus_local
                        ? _focus_play_top + 8 + (_focus_card_h * 0.5)
                        : _focus_play_bottom - 8 - (_focus_card_h * 0.5);
                } else {
                    _focus_center_y = _focus_local
                        ? _focus_play_bottom - 8 - (_focus_card_h * 0.5)
                        : _focus_play_top + 8 + (_focus_card_h * 0.5);
                }
            }
            var _focus_screen_h = ui_screen_height - board_viewport_top;
            board_camera_target_zoom = clamp(
                min(
                    1.45,
                    (board_viewport_right * 0.88)
                        / max(1, _focus_zone_w + 80),
                    (_focus_screen_h * 0.58)
                        / max(1, _focus_zone_h + 60)
                ),
                board_camera_min_zoom,
                board_camera_max_zoom
            );
            var _focus_visible_w = board_viewport_right
                / board_camera_target_zoom;
            board_camera_target_x = _focus_center_x - (_focus_visible_w * 0.5);
            var _focus_desired_screen_y = board_viewport_top
                + (_focus_screen_h * 0.63);
            board_camera_target_y = _focus_center_y
                - ((_focus_desired_screen_y - board_viewport_top)
                    / board_camera_target_zoom);
        } else if (_camera_auto_focus == "far"
        || _camera_auto_focus == "far_interaction") {
            board_camera_target_zoom = clamp(
                min(
                    1,
                    min(
                        board_viewport_right / board_camera_world_width,
                        (ui_screen_height - board_viewport_top)
                            / (board_camera_world_bottom - board_camera_world_top)
                    )
                ),
                board_camera_min_zoom,
                board_camera_max_zoom
            );
            var _auto_far_visible_w = board_viewport_right
                / board_camera_target_zoom;
            var _auto_far_visible_h = (
                ui_screen_height - board_viewport_top
            ) / board_camera_target_zoom;
            board_camera_target_x =
                (board_camera_world_width - _auto_far_visible_w) * 0.5;
            board_camera_target_y = board_camera_world_top
                + ((board_camera_world_bottom - board_camera_world_top
                    - _auto_far_visible_h) * 0.5);
        } else {
            board_camera_target_zoom = _get_close_camera_zoom();
            var _auto_close_visible_w = board_viewport_right
                / board_camera_target_zoom;
            var _auto_close_visible_h = (
                ui_screen_height - board_viewport_top
            ) / board_camera_target_zoom;
            var _auto_close_extra_h = max(
                0,
                _auto_close_visible_h
                    - (board_layout_height - board_viewport_top)
            );
            board_camera_target_x = (
                board_camera_world_width - _auto_close_visible_w
            ) * 0.5;
            board_camera_target_y =
                _camera_auto_focus == "local"
                    ? board_viewport_top - (_auto_close_extra_h * 0.5)
                    : board_camera_world_top - (_auto_close_extra_h * 0.5);
        }
        board_camera_recenter_requested = false;
    } else if (!board_camera_auto_center) {
        board_camera_last_auto_focus = "";
    }

    // Camera presets: 1 local board, 2 center systems, 3 opponent board,
    // and 0 a complete-table overview.
    if (_camera_input_allowed && keyboard_check_pressed(ord("0"))) {
        board_camera_target_zoom = clamp(
            min(
                1,
                min(
                    board_viewport_right / board_camera_world_width,
                    (ui_screen_height - board_viewport_top)
                        / (board_camera_world_bottom - board_camera_world_top)
                )
            ),
            board_camera_min_zoom,
            board_camera_max_zoom
        );
        var _fit_visible_w = board_viewport_right
            / board_camera_target_zoom;
        var _fit_visible_h = (
            ui_screen_height - board_viewport_top
        ) / board_camera_target_zoom;
        board_camera_target_x =
            (board_camera_world_width - _fit_visible_w) * 0.5;
        board_camera_target_y = board_camera_world_top
            + ((board_camera_world_bottom - board_camera_world_top
                - _fit_visible_h) * 0.5);
    } else if (_camera_input_allowed
    && keyboard_check_pressed(ord("1"))) {
        board_camera_target_zoom = _get_close_camera_zoom();
        var _preset_local_visible_w = board_viewport_right
            / board_camera_target_zoom;
        board_camera_target_x = (
            board_camera_world_width - _preset_local_visible_w
        ) * 0.5;
        var _preset_local_visible_h = (
            ui_screen_height - board_viewport_top
        ) / board_camera_target_zoom;
        var _preset_local_extra_h = max(
            0,
            _preset_local_visible_h
                - (board_layout_height - board_viewport_top)
        );
        board_camera_target_y = board_viewport_top
            - (_preset_local_extra_h * 0.5);
    } else if (_camera_input_allowed
    && keyboard_check_pressed(ord("2"))) {
        var _center_visible_w = board_viewport_right
            / max(0.01, board_camera_target_zoom);
        var _center_visible_h = (
            ui_screen_height - board_viewport_top
        ) / board_camera_target_zoom;
        board_camera_target_x = (
            board_camera_world_width - _center_visible_w
        ) * 0.5;
        board_camera_target_y = 370 - (_center_visible_h * 0.5);
    } else if (_camera_input_allowed
    && keyboard_check_pressed(ord("3"))) {
        board_camera_target_zoom = _get_close_camera_zoom();
        var _preset_opponent_visible_w = board_viewport_right
            / board_camera_target_zoom;
        board_camera_target_x = (
            board_camera_world_width - _preset_opponent_visible_w
        ) * 0.5;
        var _preset_opponent_visible_h = (
            ui_screen_height - board_viewport_top
        ) / board_camera_target_zoom;
        var _preset_opponent_extra_h = max(
            0,
            _preset_opponent_visible_h
                - (board_layout_height - board_viewport_top)
        );
        board_camera_target_y = board_camera_world_top
            - (_preset_opponent_extra_h * 0.5);
    }

    var _target_visible_w = board_viewport_right
        / max(0.01, board_camera_target_zoom);
    var _target_visible_h = (
        ui_screen_height - board_viewport_top
    ) / max(0.01, board_camera_target_zoom);
    // Permit deliberate overscroll until roughly one fifth of the viewport still
    // contains the board. This remains navigable even when the whole table fits.
    var _camera_min_x = -(_target_visible_w * 0.8);
    var _camera_max_x = board_camera_world_width
        - (_target_visible_w * 0.2);
    var _camera_min_y = board_camera_world_top
        - (_target_visible_h * 0.8);
    var _camera_max_y = board_camera_world_bottom
        - (_target_visible_h * 0.2);
    board_camera_target_x = clamp(
        board_camera_target_x,
        _camera_min_x,
        _camera_max_x
    );
    board_camera_target_y = clamp(
        board_camera_target_y,
        _camera_min_y,
        _camera_max_y
    );
    board_camera_zoom = lerp(
        board_camera_zoom,
        board_camera_target_zoom,
        0.22
    );
    board_camera_x = lerp(board_camera_x, board_camera_target_x, 0.22);
    board_camera_y = lerp(board_camera_y, board_camera_target_y, 0.22);

    // Merge newly generated events into the ordered in-memory journal before a
    // controller branch can exit this Step. Completed matches flush it once.
    if (!title_menu_active
    && (game_state.game_mode != "batch"
        || global.loc_batch_state.detailed_logs
        || global.loc_batch_state.replay_active)) {
        try {
            sync_balance_live_log();
        } catch (_balance_sync_error) {
            show_debug_message(
                "[BALANCE] Live log sync failed: "
                + string(_balance_sync_error)
            );
        }
    }

    // Cavern Omegas read as detected underground activity. Ease the sensor display
    // in and out independently of gameplay so an evolution visibly brings it online.
    var _cavern_sensor_target = array_length(game_state.cavern) > 0 ? 1 : 0;
    cavern_sensor_alpha = lerp(
        cavern_sensor_alpha,
        _cavern_sensor_target,
        0.075
    );
    if (abs(cavern_sensor_alpha - _cavern_sensor_target) < 0.005) {
        cavern_sensor_alpha = _cavern_sensor_target;
    }

    // The opening presentation is visual only: Shop, SR388, then hands. It starts
    // when a real interactive match leaves the menu and never runs in batch mode.
    if (!presentation_opening_started
    && !title_menu_active
    && !network_lobby_active
    && game_state.game_mode != ""
    && game_state.game_mode != "batch") {
        presentation_opening_started = true;
        presentation_opening_active = true;
        presentation_opening_frame = 0;
    }
    if (presentation_opening_active) {
        presentation_opening_frame += 1;
        if (presentation_opening_frame >= 112) {
            presentation_opening_active = false;
        }
    }
    var _opening_blocks_gameplay = presentation_opening_active
        && game_state.game_mode != "network";
    var _evolution_blocks_gameplay = false;
    if (presentation_evolution_until_ms > 0) {
        if (current_time < presentation_evolution_until_ms) {
            _evolution_blocks_gameplay = true;
        }
        presentation_evolution_until_ms = 0;
        if (game_state.phase == "pass_turn") {
            advance_game_phase();
        }
    }
    var _capture_blocks_gameplay = presentation_capture_until_ms > current_time;
    if (presentation_capture_until_ms > 0
    && !_capture_blocks_gameplay) {
        presentation_capture_until_ms = 0;
    }
    var _lab_intake_blocks_gameplay = false;
    if (presentation_lab_intake_until_ms > 0) {
        if (current_time < presentation_lab_intake_until_ms) {
            _lab_intake_blocks_gameplay = true;
            var _lab_intake_pull_target =
                current_time < presentation_lab_intake_close_at_ms ? 1 : 0;
            if (presentation_lab_intake_player == game_state.view_player) {
                lab_pull_amount = lerp(
                    lab_pull_amount,
                    _lab_intake_pull_target,
                    0.18
                );
            } else if (presentation_lab_intake_player
            == 1 - game_state.view_player) {
                opponent_lab_pull_amount = lerp(
                    opponent_lab_pull_amount,
                    _lab_intake_pull_target,
                    0.18
                );
            }
        } else {
            presentation_lab_intake_until_ms = 0;
            presentation_lab_intake_close_at_ms = 0;
            presentation_lab_intake_player = -1;
        }
    }
    var _target_effect_blocks_gameplay = false;
    if (!is_undefined(presentation_target_effect)) {
        _target_effect_blocks_gameplay = true;
        if (current_time >= presentation_target_effect.resolve_at_ms) {
            if (variable_struct_exists(presentation_target_effect, "audit_only")
            && presentation_target_effect.audit_only) {
                presentation_target_effect = undefined;
            } else {
            var _target_effect_kind =
                presentation_target_effect.target_kind;
            var _target_effect_index =
                presentation_target_effect.target_index;
            presentation_target_effect_committing = true;
            resolve_ability_target_choice(
                _target_effect_kind,
                _target_effect_index
            );
            presentation_target_effect_committing = false;
            presentation_target_effect = undefined;
            }
        }
    }

    if (!is_undefined(pending_choice)
    && variable_struct_exists(pending_choice, "audit_only")
    && pending_choice.audit_only
    && current_time >= pending_choice.audit_expires_ms) {
        pending_choice = undefined;
    }
    for (var _transit_cleanup_index = array_length(
             presentation_card_transits
         ) - 1;
         _transit_cleanup_index >= 0;
         _transit_cleanup_index--) {
        var _transit_cleanup = presentation_card_transits[
            _transit_cleanup_index
        ];
        if (current_time >= _transit_cleanup.started_at_ms
            + _transit_cleanup.duration_ms) {
            array_delete(
                presentation_card_transits,
                _transit_cleanup_index,
                1
            );
        }
    }
    for (var _destruction_cleanup_index = array_length(
             presentation_card_destructions
         ) - 1;
         _destruction_cleanup_index >= 0;
         _destruction_cleanup_index--) {
        var _destruction_cleanup = presentation_card_destructions[
            _destruction_cleanup_index
        ];
        if (current_time >= _destruction_cleanup.started_at_ms
            + _destruction_cleanup.duration_ms) {
            array_delete(
                presentation_card_destructions,
                _destruction_cleanup_index,
                1
            );
        }
    }
    for (var _breach_cleanup_index = array_length(presentation_breaches) - 1;
         _breach_cleanup_index >= 0;
         _breach_cleanup_index--) {
        var _breach_cleanup = presentation_breaches[_breach_cleanup_index];
        if (_breach_cleanup.return_started_at_ms >= 0
        && current_time >= _breach_cleanup.return_started_at_ms
            + _breach_cleanup.return_duration_ms) {
            array_delete(presentation_breaches, _breach_cleanup_index, 1);
        }
    }

    // Hit regions are rebuilt by Draw each frame. Resolve hover from the latest set.
    ui_hover_kind = "";
    ui_hover_index = -1;
    ui_hover_instance = undefined;
    var _hover_region = undefined;
    for (var _hit_index = array_length(ui_hit_regions) - 1;
         _hit_index >= 0;
         _hit_index--) {
        var _region = ui_hit_regions[_hit_index];
        var _region_pointer_allowed =
            !variable_struct_exists(_region, "world_space")
            || !_region.world_space
            || _pointer_over_board;
        if (_region_pointer_allowed
        && point_in_rectangle(
            _ui_pointer_x,
            _ui_pointer_y,
            _region.x1,
            _region.y1,
            _region.x2,
            _region.y2
        )) {
            _hover_region = _region;
            ui_hover_kind = _region.kind;
            ui_hover_index = _region.index;
            if (variable_struct_exists(_region, "instance")) {
                ui_hover_instance = _region.instance;
            }
            break;
        }
    }
    ui_hover_action_has_context = !is_undefined(_hover_region)
        && (_hover_region.kind == "action"
            || _hover_region.kind == "context_bridge")
        && variable_struct_exists(_hover_region, "context_kind")
        && _hover_region.context_kind != "";

    // Chat owns text input while focused. Consume focus-changing clicks so they
    // cannot activate another control on the same frame.
    var _chat_consumed_click = false;
    var _chat_consumed_escape = false;
    if (!title_menu_active
    && !network_lobby_active
    && !test_tools_open
    && !pause_screen_open
    && game_state.game_mode != "batch") {
        if (mouse_check_button_pressed(mb_left)) {
            if (!is_undefined(_hover_region)
            && _hover_region.kind == "chat_input") {
                chat_input_active = true;
                keyboard_string = chat_input_text;
                _chat_consumed_click = true;
            } else if (chat_input_active) {
                chat_input_active = false;
                keyboard_string = "";
                _chat_consumed_click = true;
            }
        }
        if (chat_input_active) {
            chat_input_text = string_copy(keyboard_string, 1, 200);
            if (keyboard_check_pressed(vk_enter)) {
                submit_chat_message(chat_input_text);
                chat_input_text = "";
                keyboard_string = "";
            } else if (keyboard_check_pressed(vk_escape)) {
                chat_input_active = false;
                chat_input_text = "";
                keyboard_string = "";
                _chat_consumed_escape = true;
            }
        }
    }
    if (_chat_consumed_click || chat_input_active) {
        _hover_region = undefined;
        ui_hover_kind = "";
        ui_hover_index = -1;
        ui_hover_instance = undefined;
    }

    var _hand_checkpoint_clear = !title_menu_active
        && game_state.game_mode != ""
        && game_state.game_mode != "batch"
        && game_state.phase != "game_over"
        && is_undefined(pending_choice)
        && !_opening_blocks_gameplay
        && !_evolution_blocks_gameplay
        && !_capture_blocks_gameplay
        && !_lab_intake_blocks_gameplay
        && !_target_effect_blocks_gameplay;
    if (_hand_checkpoint_clear) {
        for (var _hand_checkpoint_player = 0;
             _hand_checkpoint_player < array_length(game_state.players);
             _hand_checkpoint_player++) {
            restore_hand_to_five(
                game_state.players[_hand_checkpoint_player]
            );
        }
    }

    var _guidance_player_index = game_state.game_mode == "network"
        ? network_local_player
        : (game_state.game_mode == "hotseat"
            ? game_state.active_player
            : game_state.view_player);
    var _guidance_player_can_act = _guidance_player_index >= 0
        && _guidance_player_index < array_length(game_state.players)
        && !game_state.players[_guidance_player_index].is_ai;
    if (_guidance_player_can_act) {
        queue_first_game_guidance(
            "camera_controls",
            "CAMERA CONTROLS",
            "In UNLOCKED mode, hold the right mouse button and drag to move the camera. Use the scroll wheel to zoom. In LOCKED mode, the camera follows play automatically; you can also zoom out to show the entire board. Hold ALT while hovering over a card to inspect it at full size."
        );
    }
    if (_guidance_player_can_act
    && game_state.phase == "action"
    && game_state.active_player == _guidance_player_index) {
        queue_first_game_guidance(
            "action_phase",
            "ACTION PHASE",
            "Play cards from your hand and take actions in any order. End Turn when you are ready to proceed to Containment."
        );
    }
    if (_guidance_player_can_act
    && (ui_selected_kind == "hand" || ui_hover_kind == "hand")) {
        queue_first_game_guidance(
            "hand_card",
            "PLAYING CARDS",
            "Playing Characters, Vehicles, and Locations adds them to your board. Events resolve immediately and are then discarded."
        );
    }
    if (_guidance_player_can_act && ui_selected_kind == "shop") {
        queue_first_game_guidance(
            "shop_card",
            "THE SHOP",
            "RESERVE adds this card to your discard pile for later. DEPLOY costs more CP but puts it directly onto your board."
        );
    }
    if (_guidance_player_can_act
    && !is_undefined(ui_selected_instance_id)
    && ui_selected_instance_id >= 0
    && !is_undefined(ui_selected_kind)
    && (ui_selected_kind == "character"
        || ui_selected_kind == "ship"
        || ui_selected_kind == "location"
        || ui_selected_kind == "relic")) {
        var _guidance_ability_source = get_ability_source(
            ui_selected_kind,
            ui_selected_index
        );
        if (!is_undefined(_guidance_ability_source)
        && array_length(get_activated_abilities(_guidance_ability_source)) > 0) {
            queue_first_game_guidance(
                "activated_ability",
                "ACTIVATED ABILITIES",
                "Ready cards may use their listed abilities. Costs such as EXHAUST are paid before the effect resolves."
            );
        }
    }
    if (_guidance_player_can_act
    && game_state.phase == "containment"
    && game_state.active_player == _guidance_player_index
    && is_undefined(pending_choice)) {
        queue_first_game_guidance(
            "containment_choice",
            "CONTAINMENT",
            "Choose a ready Ship to contribute its Security, or choose NO SHIP. A contributing Ship exhausts."
        );
    }
    for (var _guidance_lab_player = 0;
         _guidance_lab_player < array_length(game_state.players);
         _guidance_lab_player++) {
        var _guidance_lab_count = array_length(
            game_state.players[_guidance_lab_player].lab
        );
        if (_guidance_lab_player == _guidance_player_index
        && _guidance_lab_count > guidance_last_lab_count[_guidance_lab_player]) {
            queue_first_game_guidance(
                "metroid_entered_lab",
                "METROID SECURED",
                "Metroids in your Lab provide Research at game end, but their Hazard must be contained every turn."
            );
        }
        guidance_last_lab_count[_guidance_lab_player] = _guidance_lab_count;
    }
    if (game_state.final_round_active && !guidance_final_round_observed) {
        guidance_final_round_observed = true;
        queue_first_game_guidance(
            "final_round",
            "FINAL ROUND",
            "The current turn will finish and the opponent receives one final turn before Research is scored. Mutation reaching 8 can still end the game immediately."
        );
    }

    var _guidance_presentation_clear = !_opening_blocks_gameplay
        && !_evolution_blocks_gameplay
        && !_capture_blocks_gameplay
        && !_lab_intake_blocks_gameplay
        && !_target_effect_blocks_gameplay;
    if (is_undefined(guidance_active)
    && array_length(guidance_queue) > 0
    && _guidance_presentation_clear) {
        guidance_active = guidance_queue[0];
        array_delete(guidance_queue, 0, 1);
    }
    if (!is_undefined(guidance_active)) {
        if (mouse_check_button_pressed(mb_left)
        && !is_undefined(_hover_region)
        && _hover_region.kind == "action") {
            if (_hover_region.action == "guidance_ack") {
                dismiss_first_game_guidance(false);
            } else if (_hover_region.action == "guidance_disable") {
                dismiss_first_game_guidance(true);
            }
        } else if (keyboard_check_pressed(vk_escape)
        || keyboard_check_pressed(vk_enter)) {
            dismiss_first_game_guidance(false);
        }
        exit;
    }

    // Help is a modal knowledge layer shared by the title and pause screens.
    // It owns pointer and wheel input while open so the underlying menu cannot act.
    if (help_page_open) {
        if (!is_undefined(_hover_region)
        && _hover_region.kind == "help_scroll") {
            var _help_wheel_delta = mouse_wheel_down() - mouse_wheel_up();
            if (_help_wheel_delta != 0) {
                help_scroll = clamp(
                    help_scroll + (_help_wheel_delta * 42),
                    0,
                    help_scroll_max
                );
            }
        }
        if (mouse_check_button_pressed(mb_left)
        && !is_undefined(_hover_region)
        && _hover_region.kind == "action") {
            if (string_pos("help_topic_", _hover_region.action) == 1) {
                help_selected_index = clamp(
                    real(string_delete(
                        _hover_region.action,
                        1,
                        string_length("help_topic_")
                    )),
                    0,
                    array_length(help_topics) - 1
                );
                help_scroll = 0;
            } else if (_hover_region.action == "help_back") {
                help_page_open = false;
                help_scroll = 0;
            }
        }
        if (keyboard_check_pressed(vk_escape)) {
            help_page_open = false;
            help_scroll = 0;
        }
        exit;
    }

    // Escape owns the lightweight playtest pause menu. It is unavailable during
    // unattended batches and from screens that already function as menus.
    if (!chat_input_active
    && !_chat_consumed_escape
    && keyboard_check_pressed(vk_escape)
    && !title_menu_active
    && !network_lobby_active
    && game_state.game_mode != "batch") {
        if (test_tools_open) {
            test_tools_open = false;
        } else if (pause_screen_open && pause_options_open) {
            pause_options_open = false;
        } else {
            pause_screen_open = !pause_screen_open;
            if (!pause_screen_open) pause_options_open = false;
        }
    }

    if (pause_screen_open) {
        if (mouse_check_button_pressed(mb_left)
        && !is_undefined(_hover_region)
        && _hover_region.kind == "action") {
            switch (_hover_region.action) {
                case "pause_resume":
                    pause_screen_open = false;
                    pause_options_open = false;
                    break;

                case "pause_options":
                    pause_options_open = true;
                    break;

                case "pause_help":
                    help_page_open = true;
                    help_return_context = "pause";
                    help_scroll = 0;
                    break;

                case "settings_view":
                    settings_default_center_far = !settings_default_center_far;
                    board_camera_center_far = settings_default_center_far;
                    board_camera_last_auto_focus = "";
                    board_camera_recenter_requested = true;
                    save_persistent_settings();
                    break;

                case "settings_lock":
                    settings_default_camera_locked =
                        !settings_default_camera_locked;
                    board_camera_locked = settings_default_camera_locked;
                    board_camera_dragging = false;
                    if (board_camera_locked) {
                        board_camera_last_auto_focus = "";
                        board_camera_recenter_requested = true;
                    } else {
                        board_camera_target_x = board_camera_x;
                        board_camera_target_y = board_camera_y;
                        board_camera_target_zoom = board_camera_zoom;
                    }
                    save_persistent_settings();
                    break;

                case "settings_color":
                    settings_ui_color_index = (settings_ui_color_index + 1)
                        mod array_length(settings_ui_color_names);
                    save_persistent_settings();
                    break;

                case "settings_opponent_color":
                    settings_opponent_ui_color_index =
                        (settings_opponent_ui_color_index + 1)
                        mod array_length(settings_ui_color_names);
                    save_persistent_settings();
                    break;

                case "settings_debug":
                    settings_debug_mode = !settings_debug_mode;
                    test_tools_open = false;
                    save_persistent_settings();
                    break;

                case "settings_context_help":
                    settings_context_help = !settings_context_help;
                    save_persistent_settings();
                    break;

                case "settings_guidance":
                    settings_first_game_guidance =
                        !settings_first_game_guidance;
                    if (settings_first_game_guidance) guidance_queued = {};
                    save_persistent_settings();
                    break;

                case "settings_restore_guidance":
                    restore_first_game_guidance();
                    break;

                case "settings_back":
                    pause_options_open = false;
                    break;

                case "pause_menu":
                    if (net_socket >= 0) {
                        network_destroy(net_socket);
                    }
                    if (net_server >= 0) {
                        network_destroy(net_server);
                    }
                    for (var _pause_socket_index = 0;
                         _pause_socket_index < array_length(net_client_sockets);
                         _pause_socket_index++) {
                        if (net_client_sockets[_pause_socket_index] >= 0) {
                            network_destroy(net_client_sockets[
                                _pause_socket_index
                            ]);
                        }
                    }
                    net_socket = -1;
                    net_server = -1;
                    net_client_sockets = [];
                    net_lobby_participants = [];
                    net_role = "";
                    net_status = "";
                    network_lobby_active = false;
                    test_tools_open = false;
                    pause_screen_open = false;
                    pause_options_open = false;
                    title_menu_active = true;
                    title_name_editing = false;
                    batch_menu_active = false;
                    keyboard_string = "";
                    break;

                case "pause_quit":
                    game_end();
                    break;
            }
        }
        exit;
    }

    if (network_lobby_active) {
        if (net_role == "client" && net_join_field == "address") {
            net_ip_input = string_copy(keyboard_string, 1, 64);
        } else if (net_role == "client" && net_join_field == "name") {
            var _network_edited_name = string_copy(keyboard_string, 1, 24);
            if (_network_edited_name != net_player_name) {
                net_player_name = _network_edited_name;
                global.loc_player_name = net_player_name;
                save_persistent_settings();
            }
        }
        if (mouse_check_button_pressed(mb_left)
        && !is_undefined(_hover_region)) {
            if (_hover_region.kind == "network_name_field") {
                net_join_field = "name";
                keyboard_string = net_player_name;
            } else if (_hover_region.kind == "network_address_field") {
                net_join_field = "address";
                keyboard_string = net_ip_input;
            } else if (_hover_region.kind == "action"
            && _hover_region.action == "network_connect") {
                if (net_player_name == "") {
                    net_player_name = "Player 2";
                }
                save_persistent_settings();
                network_connect_to_host();
            } else if (_hover_region.kind == "action"
            && string_pos("network_lobby_claim_", _hover_region.action) == 1) {
                var _claim_text = string_delete(
                    _hover_region.action, 1,
                    string_length("network_lobby_claim_")
                );
                network_lobby_submit_action("claim_seat", real(_claim_text));
            } else if (_hover_region.kind == "action"
            && _hover_region.action == "network_lobby_spectate") {
                network_lobby_submit_action("spectate", -1);
            } else if (_hover_region.kind == "action"
            && _hover_region.action == "network_lobby_ready") {
                network_lobby_submit_action("toggle_ready", 0);
            } else if (_hover_region.kind == "action"
            && _hover_region.action == "network_lobby_leader") {
                var _lobby_leaders = [
                    "bsl_researcher", "adam_malkovich", "mother_brain",
                    "quiet_robe", "raven_beak"
                ];
                var _lobby_local = network_find_participant(
                    net_local_participant_id
                );
                if (_lobby_local >= 0) {
                    var _current_leader = net_lobby_participants[
                        _lobby_local
                    ].leader_id;
                    var _next_leader_index = 0;
                    for (var _leader_scan = 0;
                         _leader_scan < array_length(_lobby_leaders);
                         _leader_scan++) {
                        if (_lobby_leaders[_leader_scan] == _current_leader) {
                            _next_leader_index = (_leader_scan + 1)
                                mod array_length(_lobby_leaders);
                            break;
                        }
                    }
                    network_lobby_submit_action(
                        "set_leader", _lobby_leaders[_next_leader_index]
                    );
                }
            } else if (_hover_region.kind == "action"
            && _hover_region.action == "network_lobby_start") {
                network_start_lobby_match();
            } else if (_hover_region.kind == "action"
            && _hover_region.action == "network_back") {
                if (net_socket >= 0) {
                    network_destroy(net_socket);
                }
                if (net_server >= 0) {
                    network_destroy(net_server);
                }
                for (var _lobby_socket_index = 0;
                     _lobby_socket_index < array_length(net_client_sockets);
                     _lobby_socket_index++) {
                    if (net_client_sockets[_lobby_socket_index] >= 0) {
                        network_destroy(net_client_sockets[
                            _lobby_socket_index
                        ]);
                    }
                }
                net_socket = -1;
                net_server = -1;
                net_client_sockets = [];
                net_lobby_participants = [];
                network_lobby_active = false;
                title_menu_active = true;
                title_name_editing = false;
                keyboard_string = "";
            }
        }
        exit;
    }

    if (title_menu_active) {
        if (title_context_mode == "settings") {
            var _settings_wheel_delta =
                mouse_wheel_down() - mouse_wheel_up();
            var _settings_panel_w = min(1240, ui_screen_width - 48);
            var _settings_panel_h = min(700, ui_screen_height - 96);
            var _settings_panel_x = floor(
                (ui_screen_width - _settings_panel_w) * 0.5
            );
            var _settings_panel_y = floor(
                (ui_screen_height - _settings_panel_h) * 0.5
            );
            var _settings_right_x = _settings_panel_x + 42 + 260 + 34;
            var _settings_available_w =
                _settings_panel_x + _settings_panel_w - 42
                - _settings_right_x;
            var _settings_control_w = min(
                430,
                max(260, floor((_settings_available_w - 34) * 0.58))
            );
            var _settings_right_edge = _settings_right_x
                + _settings_control_w + 14;
            var _settings_view_top = _settings_panel_y + 240;
            var _settings_view_bottom =
                _settings_panel_y + _settings_panel_h - 48;
            if (_settings_wheel_delta != 0
            && _ui_pointer_x >= _settings_right_x
            && _ui_pointer_x <= _settings_right_edge
            && _ui_pointer_y >= _settings_view_top
            && _ui_pointer_y <= _settings_view_bottom) {
                title_settings_scroll = clamp(
                    title_settings_scroll + (_settings_wheel_delta * 42),
                    0,
                    title_settings_scroll_max
                );
            }
        }
        if (title_name_editing == 1) {
            var _title_edited_name = string_copy(keyboard_string, 1, 24);
            if (_title_edited_name != net_player_name) {
                net_player_name = _title_edited_name;
                global.loc_player_name = net_player_name;
                save_persistent_settings();
            }
        } else if (title_name_editing == 2) {
            var _title_edited_name_two = string_copy(keyboard_string, 1, 24);
            if (_title_edited_name_two != title_player_two_name) {
                title_player_two_name = _title_edited_name_two;
                save_persistent_settings();
            }
        } else if (title_name_editing == 3) {
            net_ip_input = string_copy(keyboard_string, 1, 64);
        } else if (batch_seed_editing) {
            batch_seed_text = string_digits(keyboard_string);
        }
        if (mouse_check_button_pressed(mb_left)
        && !is_undefined(_hover_region)) {
            if (_hover_region.kind == "title_name_p1") {
                title_name_editing = 1;
                batch_seed_editing = false;
                keyboard_string = net_player_name;
            } else if (_hover_region.kind == "title_name_p2") {
                title_name_editing = 2;
                batch_seed_editing = false;
                keyboard_string = title_player_two_name;
            } else if (_hover_region.kind == "title_network_address") {
                title_name_editing = 3;
                batch_seed_editing = false;
                keyboard_string = net_ip_input;
            } else if (_hover_region.kind == "batch_seed_field") {
                batch_seed_editing = true;
                title_name_editing = false;
                keyboard_string = batch_seed_text;
            } else if (_hover_region.kind == "action") {
                if (net_player_name == "") {
                    net_player_name = "Player 1";
                }
                global.loc_player_name = net_player_name;
                save_persistent_settings();
                title_name_editing = 0;
                batch_seed_editing = false;
                if (string_pos("title_select_", _hover_region.action) == 1) {
                    var _selected_title_context = string_delete(
                        _hover_region.action,
                        1,
                        string_length("title_select_")
                    );
                    if (_selected_title_context == "batch") {
                        if (settings_debug_mode) batch_menu_active = true;
                    } else if (_selected_title_context == "regression") {
                        if (settings_debug_mode) run_regression_suite();
                    } else if (_selected_title_context == "help") {
                        help_page_open = true;
                        help_return_context = "title";
                        help_scroll = 0;
                    } else {
                        title_context_mode = _selected_title_context;
                    }
                } else if (_hover_region.action == "title_cycle_leader_p1") {
                    title_leader_p1_index = (title_leader_p1_index + 1)
                        mod array_length(title_leader_keys);
                    global.loc_leader_p1_index = title_leader_p1_index;
                } else if (_hover_region.action == "title_cycle_leader_p2") {
                    title_leader_p2_index = (title_leader_p2_index + 1)
                        mod array_length(title_leader_keys);
                    global.loc_leader_p2_index = title_leader_p2_index;
                } else if (_hover_region.action == "title_cycle_ai_difficulty") {
                    ai_difficulty_index = (ai_difficulty_index + 1)
                        mod array_length(ai_difficulty_keys);
                    global.loc_ai_difficulty_index = ai_difficulty_index;
                    save_persistent_settings();
                } else if (_hover_region.action == "title_play_context") {
                    if (net_player_name == "") net_player_name = "Player 1";
                    if (title_player_two_name == "") {
                        title_player_two_name = "Player 2";
                    }
                    save_persistent_settings();
                    start_game_mode(title_context_mode);
                } else if (_hover_region.action == "settings_view") {
                    settings_default_center_far = !settings_default_center_far;
                    save_persistent_settings();
                } else if (_hover_region.action == "settings_lock") {
                    settings_default_camera_locked =
                        !settings_default_camera_locked;
                    save_persistent_settings();
                } else if (_hover_region.action == "settings_color") {
                    settings_ui_color_index = (settings_ui_color_index + 1)
                        mod array_length(settings_ui_color_names);
                    save_persistent_settings();
                } else if (_hover_region.action == "settings_opponent_color") {
                    settings_opponent_ui_color_index =
                        (settings_opponent_ui_color_index + 1)
                        mod array_length(settings_ui_color_names);
                    save_persistent_settings();
                } else if (_hover_region.action == "settings_debug") {
                    settings_debug_mode = !settings_debug_mode;
                    test_tools_open = false;
                    save_persistent_settings();
                } else if (_hover_region.action == "settings_context_help") {
                    settings_context_help = !settings_context_help;
                    save_persistent_settings();
                } else if (_hover_region.action == "settings_guidance") {
                    settings_first_game_guidance =
                        !settings_first_game_guidance;
                    if (settings_first_game_guidance) guidance_queued = {};
                    save_persistent_settings();
                } else if (_hover_region.action
                == "settings_restore_guidance") {
                    restore_first_game_guidance();
                } else if (_hover_region.action
                == "settings_breaching_mutation") {
                    settings_experimental_breaching_mutation =
                        !settings_experimental_breaching_mutation;
                    save_persistent_settings();
                } else if (_hover_region.action
                == "settings_loaded_ships_exhausted") {
                    settings_experimental_loaded_ships_exhausted =
                        !settings_experimental_loaded_ships_exhausted;
                    save_persistent_settings();
                } else if (_hover_region.action == "settings_back") {
                    settings_menu_active = false;
                } else if (_hover_region.action == "title_hotseat") {
                start_game_mode("hotseat");
                } else if (_hover_region.action == "title_ai") {
                    start_game_mode("ai");
                } else if (_hover_region.action == "title_ai_watch") {
                    start_game_mode("ai_watch");
                } else if (_hover_region.action == "title_network_host") {
                    network_begin_host();
                } else if (_hover_region.action == "title_network_join") {
                    network_open_join();
                    network_connect_to_host();
                } else if (_hover_region.action == "title_batch"
                && settings_debug_mode) {
                    batch_menu_active = true;
                } else if (_hover_region.action == "title_regression"
                && settings_debug_mode) {
                    run_regression_suite();
                } else if (_hover_region.action == "batch_cycle_p1") {
                    batch_profile_p1_index = (
                        batch_profile_p1_index + 1
                    ) mod array_length(batch_profile_options);
                } else if (_hover_region.action == "batch_cycle_p2") {
                    batch_profile_p2_index = (
                        batch_profile_p2_index + 1
                    ) mod array_length(batch_profile_options);
                } else if (_hover_region.action == "batch_cycle_games") {
                    batch_game_option_index = (
                        batch_game_option_index + 1
                    ) mod array_length(batch_game_options);
                } else if (_hover_region.action == "batch_cycle_matrix_filter") {
                    batch_matrix_filter_index = (
                        batch_matrix_filter_index + 1
                    ) mod array_length(batch_matrix_filter_options);
                } else if (_hover_region.action == "batch_toggle_drafting") {
                    batch_focused_drafting = !batch_focused_drafting;
                } else if (_hover_region.action == "batch_toggle_deck_brains") {
                    batch_deck_brains = !batch_deck_brains;
                } else if (_hover_region.action == "batch_toggle_logs") {
                    batch_detailed_logs = !batch_detailed_logs;
                } else if (_hover_region.action == "batch_toggle_report_value") {
                    batch_report_raw_win_rate =
                        !batch_report_raw_win_rate;
                } else if (_hover_region.action == "batch_report_previous") {
                    batch_report_page = (
                        batch_report_page + array_length(batch_profile_options)
                    ) mod (array_length(batch_profile_options) + 1);
                } else if (_hover_region.action == "batch_report_next") {
                    batch_report_page = (batch_report_page + 1)
                        mod (array_length(batch_profile_options) + 1);
                } else if (_hover_region.action == "batch_run_single") {
                    start_batch_run(false);
                } else if (_hover_region.action == "batch_run_matrix") {
                    start_batch_run(true);
                } else if (_hover_region.action == "batch_resume_checkpoint") {
                    batch_resume_checkpoint();
                } else if (_hover_region.action == "batch_back") {
                    batch_menu_active = false;
                    if (variable_global_exists("loc_batch_show_results")) {
                        global.loc_batch_show_results = false;
                    }
                }
            }
        }
        exit;
    }

    if (debug_headless_to_game_over_active) {
        repeat (1000) {
            if (game_state.phase == "game_over") {
                break;
            }
            presentation_evolution_until_ms = 0;
            presentation_lab_intake_until_ms = 0;
            presentation_lab_intake_close_at_ms = 0;
            ai_next_step_time = 0;
            if (!run_ai_controller_step()) {
                break;
            }
            debug_headless_steps += 1;
            var _debug_pending_kind = "none";
            if (!is_undefined(pending_choice)) {
                _debug_pending_kind = variable_struct_exists(pending_choice, "kind")
                    ? string(pending_choice.kind) : "unknown";
            }
            var _debug_signature = string(game_state.turn_number)
                + "|" + game_state.phase
                + "|" + string(game_state.active_player)
                + "|" + string(game_state.priority_player)
                + "|" + _debug_pending_kind
                + "|" + string(array_length(game_state.event_log));
            if (_debug_signature == debug_headless_last_signature) {
                debug_headless_same_state_steps += 1;
            } else {
                debug_headless_last_signature = _debug_signature;
                debug_headless_same_state_steps = 0;
            }
            if (debug_headless_same_state_steps >= 250) {
                array_push(game_state.event_log,
                    "TEST: Headless simulation stopped after 250 repeated states: "
                    + _debug_signature + ".");
                resolve_game_over();
                break;
            }
            if (debug_headless_steps >= 200000) {
                array_push(
                    game_state.event_log,
                    "TEST: Headless game-over simulation reached its safety limit."
                );
                resolve_game_over();
                break;
            }
        }
        if (game_state.phase == "game_over") {
            game_state.game_mode = debug_headless_original_mode;
            game_state.players[0].is_ai = debug_headless_original_ai[0];
            game_state.players[1].is_ai = debug_headless_original_ai[1];
            debug_headless_to_game_over_active = false;
        }
        exit;
    }

    if (game_state.game_mode == "batch") {
        if (game_state.phase == "game_over") {
            finish_batch_match();
            exit;
        }
        repeat (500) {
            if (game_state.phase == "game_over") {
                break;
            }
            if (!run_ai_controller_step()) {
                break;
            }
            batch_match_steps += 1;
            // A replay exists to capture a useful trace, not to reproduce a
            // pathological loop for another 200,000 disk-logged decisions.
            var _batch_step_limit = global.loc_batch_state.replay_active
                ? 10000 : 200000;
            var _batch_turn_limit = 500;
            if (game_state.turn_number >= _batch_turn_limit
            || batch_match_steps >= _batch_step_limit) {
                batch_match_invalid_reason =
                    (game_state.turn_number >= _batch_turn_limit
                        ? "Turn safety limit reached at "
                            + string(game_state.turn_number) + " turns and "
                            + string(batch_match_steps) + " AI decisions"
                        : "AI decision safety limit reached at "
                            + string(batch_match_steps) + " steps")
                    + "; pending "
                    + (is_undefined(pending_choice)
                        ? "none" : pending_choice.kind)
                    + ", phase " + game_state.phase
                    + ", turn " + string(game_state.turn_number)
                    + ", mutation " + string(game_state.mutation)
                    + ", events " + string(array_length(game_state.event_log))
                    + ", last AI action "
                    + (ai_last_action == "" ? "none" : ai_last_action) + ".";
                array_push(
                    game_state.event_log,
                    "BATCH INVALID: " + batch_match_invalid_reason
                );
                resolve_game_over();
                break;
            }
        }
        exit;
    }

    if (game_state.phase == "game_over") {
        if (mouse_check_button_pressed(mb_left)
        && !is_undefined(_hover_region)
        && _hover_region.kind == "action") {
            if (_hover_region.action == "rematch") {
                begin_rematch();
            } else if (_hover_region.action == "test_random_win") {
                open_random_end_screen_preview();
            } else if (_hover_region.action == "end_report_result") {
                end_report_page = 0;
            } else if (_hover_region.action == "end_report_p1") {
                end_report_page = 1;
            } else if (_hover_region.action == "end_report_p2") {
                end_report_page = 2;
            } else if (_hover_region.action == "back_to_menu") {
                room_restart();
            }
        }
        exit;
    }

    // Drawer interpolation is presentation state, so update it before any AI or
    // spectator input gate exits this Step event.
    if (!_lab_intake_blocks_gameplay) {
        var _early_lab_pull_target = (array_length(
            game_state.players[game_state.view_player].lab
        ) > 0
        && (ui_selected_kind == "lab_tab"
            || ui_selected_kind == "lab"
            || (!is_undefined(pending_choice)
                && pending_choice.kind == "torizo_metroid"
                && pending_choice.player_index
                    == game_state.view_player))) ? 1 : 0;
        lab_pull_amount = lerp(
            lab_pull_amount,
            _early_lab_pull_target,
            0.18
        );
        if (abs(lab_pull_amount - _early_lab_pull_target) < 0.005) {
            lab_pull_amount = _early_lab_pull_target;
        }
        var _early_opponent_lab_pull_target = (array_length(
            game_state.players[1 - game_state.view_player].lab
        ) > 0
        && (ui_selected_kind == "opponent_lab_tab"
            || ui_selected_kind == "opponent_lab")) ? 1 : 0;
        opponent_lab_pull_amount = lerp(
            opponent_lab_pull_amount,
            _early_opponent_lab_pull_target,
            0.18
        );
        if (abs(
            opponent_lab_pull_amount - _early_opponent_lab_pull_target
        ) < 0.005) {
            opponent_lab_pull_amount = _early_opponent_lab_pull_target;
        }
    }

    var _spectator_hand_peek_target = (
        game_state.game_mode == "ai_watch"
        || (game_state.game_mode == "network" && network_local_player < 0)
    )
        && spectator_hands_visible ? 1 : 0;
    spectator_hand_peek_amount = lerp(
        spectator_hand_peek_amount,
        _spectator_hand_peek_target,
        0.16
    );
    if (abs(spectator_hand_peek_amount - _spectator_hand_peek_target) < 0.005) {
        spectator_hand_peek_amount = _spectator_hand_peek_target;
    }

    // Camera, Lab, and test controls remain local presentation controls even while
    // an AI owns every gameplay decision.
    if (mouse_check_button_pressed(mb_left)
    && !is_undefined(_hover_region)
    && ((_hover_region.kind == "action"
             && (_hover_region.action == "camera_center_toggle"
                 || _hover_region.action == "camera_lock_toggle"
                 || _hover_region.action == "spectator_view_toggle"
                 || _hover_region.action == "spectator_hands_toggle"
                || (game_state.game_mode != "network"
                    && string_pos("test_", _hover_region.action) == 1)))
        || _hover_region.kind == "lab_tab"
        || _hover_region.kind == "opponent_lab_tab")) {
        if (_hover_region.kind == "lab_tab") {
            ui_selected_kind = ui_selected_kind == "lab_tab"
                ? ""
                : "lab_tab";
            ui_selected_index = ui_selected_kind == "" ? -1 : 0;
            ui_selected_instance_id = -1;
        } else if (_hover_region.kind == "opponent_lab_tab") {
            ui_selected_kind = ui_selected_kind == "opponent_lab_tab"
                ? ""
                : "opponent_lab_tab";
            ui_selected_index = ui_selected_kind == "" ? -1 : 0;
            ui_selected_instance_id = -1;
        } else if (string_pos("test_", _hover_region.action) == 1) {
            handle_test_tool_action(_hover_region.action);
        } else if (_hover_region.action == "spectator_view_toggle") {
            game_state.view_player = 1 - game_state.view_player;
            ui_selected_kind = "";
            ui_selected_index = -1;
            ui_selected_instance_id = -1;
            board_camera_last_auto_focus = "";
            board_camera_recenter_requested = true;
        } else if (_hover_region.action == "spectator_hands_toggle") {
            spectator_hands_visible = !spectator_hands_visible;
        } else if (_hover_region.action == "camera_center_toggle") {
            board_camera_center_far = !board_camera_center_far;
            board_camera_last_auto_focus = "";
            board_camera_recenter_requested = true;
        } else {
            board_camera_locked = !board_camera_locked;
            board_camera_dragging = false;
            if (board_camera_locked) {
                board_camera_last_auto_focus = "";
            } else {
                board_camera_target_x = board_camera_x;
                board_camera_target_y = board_camera_y;
                board_camera_target_zoom = board_camera_zoom;
            }
        }
        exit;
    }

    if (handoff_active) {
        if (mouse_check_button_pressed(mb_left)
        && !is_undefined(_hover_region)
        && _hover_region.kind == "action"
        && _hover_region.action == "handoff_continue") {
            confirm_turn_handoff();
        }
        exit;
    }

    if (_opening_blocks_gameplay
    || _evolution_blocks_gameplay
    || _capture_blocks_gameplay
    || _lab_intake_blocks_gameplay
    || _target_effect_blocks_gameplay) {
        exit;
    }

    if ((game_state.game_mode == "ai"
        || game_state.game_mode == "ai_watch")
    && game_state.players[game_state.priority_player].is_ai) {
        // The AI controller owns the current priority window, including raid
        // defense during the human player's active turn.
        run_ai_controller_step();
        exit;
    }

    // A fixed spectator/opponent view must never leak ordinary game controls.
    // Human responses to an explicit pending choice remain legal; otherwise only
    // the two camera buttons consume clicks.
    var _gameplay_input_locked = game_state.game_mode == "ai_watch"
        || (game_state.game_mode == "network" && network_local_player < 0)
        || game_state.players[game_state.view_player].is_ai
        || (
            game_state.active_player != game_state.view_player
            && (is_undefined(pending_choice)
                || game_state.priority_player != game_state.view_player)
        );
    if (_gameplay_input_locked) {
        exit;
    }

    if (game_state.game_mode == "network"
    && mouse_check_button_pressed(mb_left)
    && !is_undefined(_hover_region)) {
        if (_hover_region.kind == "action"
        && (string_pos("test_", _hover_region.action) == 1
            || _hover_region.action == "restart")) {
            show_debug_message(
                "[NET] Test and local restart controls are disabled in network games."
            );
            exit;
        }
        var _net_is_action = _hover_region.kind == "action"
            && _hover_region.enabled
            && string_pos("test_", _hover_region.action) != 1;
        _net_is_action = _net_is_action
            && _hover_region.action != "camera_center_toggle"
            && _hover_region.action != "camera_lock_toggle";
        var _net_is_choice = !is_undefined(pending_choice)
            && _hover_region.kind != "action"
            && _hover_region.kind != "lab_tab"
            && _hover_region.kind != "opponent_lab_tab";
        if (_net_is_action || _net_is_choice) {
            var _net_input_kind = _hover_region.kind;
            var _net_selected_kind = ui_selected_kind;
            var _net_selected_index = ui_selected_index;
            if (_net_is_action
            && variable_struct_exists(_hover_region, "context_kind")
            && _hover_region.context_kind != "") {
                _net_selected_kind = _hover_region.context_kind;
                _net_selected_index = _hover_region.context_index;
            }
            if (_net_is_choice
            && pending_choice.kind == "raid"
            && !is_undefined(_hover_region.instance)) {
                _net_input_kind = get_raid_source_kind(
                    _hover_region.kind,
                    _hover_region.instance
                );
            } else if (_net_is_choice
            && (pending_choice.kind == "chozo_ghosts_source"
                || pending_choice.kind == "chozo_ghosts_target")
            && !is_undefined(_hover_region.instance)) {
                _net_input_kind = get_raid_source_kind(
                    _hover_region.kind,
                    _hover_region.instance
                );
            }
            network_submit_input({
                input_type: _net_is_action ? "action" : "click",
                action: _net_is_action ? _hover_region.action : "",
                kind: _net_input_kind,
                index: _hover_region.index,
                selected_kind: _net_selected_kind,
                selected_index: _net_selected_index
            });
            if (_net_is_action) {
                ui_selected_kind = "";
                ui_selected_index = -1;
                ui_selected_instance_id = -1;
                ui_context_preview_kind = "";
                ui_context_preview_index = -1;
                ui_context_preview_until_ms = 0;
            }
            exit;
        }
    }

    // Right-drag is a camera control and must never double as choice cancellation.
    // Explicit Cancel controls and Escape remain the cancellation paths.
    if (keyboard_check_pressed(vk_escape)
    && game_state.game_mode != "network") {
        cancel_pending_choice();
    }

    if (mouse_check_button_pressed(mb_left)) {
        if (is_undefined(_hover_region)) {
            if (is_undefined(pending_choice)) {
                ui_selected_kind = "";
                ui_selected_index = -1;
            }
        } else if (_hover_region.kind == "action") {
            if (_hover_region.enabled) {
                if (variable_struct_exists(_hover_region, "context_kind")
                && _hover_region.context_kind != "") {
                    ui_selected_kind = _hover_region.context_kind;
                    ui_selected_index = _hover_region.context_index;
                }
                if (string_pos("back_in_day_pick_", _hover_region.action) == 1) {
                    var _back_pick_text = string_delete(
                        _hover_region.action,
                        1,
                        string_length("back_in_day_pick_")
                    );
                    resolve_back_in_the_day_choice(real(_back_pick_text));
                } else if (string_pos("raid_target_", _hover_region.action) == 1) {
                    var _raid_target_text = string_delete(
                        _hover_region.action,
                        1,
                        string_length("raid_target_")
                    );
                    begin_raid_target_choice(real(_raid_target_text));
                } else switch (_hover_region.action) {
                    case "advance_phase":
                        advance_game_phase();
                        break;

                    case "containment_no_ship":
                        resolve_turn_containment(-1);
                        break;

                    case "containment_use_ship":
                        resolve_turn_containment(ui_selected_index);
                        break;

                    case "end_turn":
                        end_turn_action();
                        break;

                    case "camera_center_toggle":
                        board_camera_center_far = !board_camera_center_far;
                        board_camera_last_auto_focus = "";
                        board_camera_recenter_requested = true;
                        break;

                    case "camera_lock_toggle":
                        board_camera_locked = !board_camera_locked;
                        board_camera_dragging = false;
                        if (board_camera_locked) {
                            board_camera_last_auto_focus = "";
                        } else {
                            board_camera_target_x = board_camera_x;
                            board_camera_target_y = board_camera_y;
                            board_camera_target_zoom = board_camera_zoom;
                        }
                        break;

                    case "reserve":
                        reserve_shop_card(ui_selected_index);
                        break;

                    case "deploy":
                        deploy_shop_card(ui_selected_index);
                        break;

                    case "play":
                        play_hand_card(ui_selected_index);
                        break;

                    case "capture":
                        begin_capture_choice(ui_selected_index);
                        break;

                    case "raid":
                        begin_raid_choice(ui_selected_index);
                        break;

                    case "back_in_day_prev":
                        pending_choice.page = max(0, pending_choice.page - 1);
                        break;

                    case "back_in_day_next":
                        pending_choice.page += 1;
                        break;

                    case "salvage":
                        salvage_permanent(ui_selected_kind, ui_selected_index);
                        break;

                    case "lock_raid_attackers":
                        lock_raid_attackers();
                        break;

                    case "resolve_raid":
                        resolve_raid();
                        break;

                    case "raid_cargo_0":
                        finish_attacker_raid_win(0);
                        break;

                    case "raid_cargo_1":
                        finish_attacker_raid_win(1);
                        break;

                    case "raid_cargo_2":
                        finish_attacker_raid_win(2);
                        break;

                    case "raid_cargo_3":
                        finish_attacker_raid_win(3);
                        break;

                    case "raid_toggle_mode":
                        toggle_raid_ability_mode();
                        break;

                    case "raid_contribute":
                        var _raid_contribute_source = get_ability_source(
                            ui_selected_kind, ui_selected_index
                        );
                        raid_contribute_selected(
                            get_raid_source_kind(
                                ui_selected_kind,
                                _raid_contribute_source
                            ),
                            ui_selected_index
                        );
                        break;

                    case "raid_activate":
                        activate_raid_selected_ability();
                        break;

                    case "raid_use_0":
                        var _raid_use_0_kind = variable_struct_exists(
                            _hover_region, "context_kind"
                        ) ? _hover_region.context_kind : ui_selected_kind;
                        var _raid_use_0_index = variable_struct_exists(
                            _hover_region, "context_index"
                        ) ? _hover_region.context_index : ui_selected_index;
                        var _raid_use_0_source = variable_struct_exists(
                            _hover_region, "context_instance"
                        ) && !is_undefined(_hover_region.context_instance)
                            ? _hover_region.context_instance
                            : get_ability_source(
                                _raid_use_0_kind, _raid_use_0_index
                            );
                        activate_raid_ability_index(
                            0,
                            get_raid_source_kind(
                                _raid_use_0_kind,
                                _raid_use_0_source
                            ),
                            _raid_use_0_index
                        );
                        break;

                    case "raid_use_1":
                        var _raid_use_1_kind = variable_struct_exists(
                            _hover_region, "context_kind"
                        ) ? _hover_region.context_kind : ui_selected_kind;
                        var _raid_use_1_index = variable_struct_exists(
                            _hover_region, "context_index"
                        ) ? _hover_region.context_index : ui_selected_index;
                        var _raid_use_1_source = variable_struct_exists(
                            _hover_region, "context_instance"
                        ) && !is_undefined(_hover_region.context_instance)
                            ? _hover_region.context_instance
                            : get_ability_source(
                                _raid_use_1_kind, _raid_use_1_index
                            );
                        activate_raid_ability_index(
                            1,
                            get_raid_source_kind(
                                _raid_use_1_kind,
                                _raid_use_1_source
                            ),
                            _raid_use_1_index
                        );
                        break;

                    case "raid_use_2":
                        var _raid_use_2_kind = variable_struct_exists(
                            _hover_region, "context_kind"
                        ) ? _hover_region.context_kind : ui_selected_kind;
                        var _raid_use_2_index = variable_struct_exists(
                            _hover_region, "context_index"
                        ) ? _hover_region.context_index : ui_selected_index;
                        var _raid_use_2_source = variable_struct_exists(
                            _hover_region, "context_instance"
                        ) && !is_undefined(_hover_region.context_instance)
                            ? _hover_region.context_instance
                            : get_ability_source(
                                _raid_use_2_kind, _raid_use_2_index
                            );
                        activate_raid_ability_index(
                            2,
                            get_raid_source_kind(
                                _raid_use_2_kind,
                                _raid_use_2_source
                            ),
                            _raid_use_2_index
                        );
                        break;

                    case "resolve_queen":
                        resolve_queen_shop_event();
                        break;

                    case "finish_queen":
                        finish_queen_shop_event();
                        break;

                    case "special_containment_no_ship":
                        choose_special_containment_ship(-1);
                        break;

                    case "special_containment_use_ship":
                        choose_special_containment_ship(ui_selected_index);
                        break;

                    case "adam_prevent_breach":
                        resolve_adam_breach_choice(true);
                        break;

                    case "adam_allow_breach":
                        resolve_adam_breach_choice(false);
                        break;

                    case "space_pirate_pay":
                        resolve_space_pirate_payment(true);
                        break;

                    case "space_pirate_decline":
                        resolve_space_pirate_payment(false);
                        break;

                    case "faction_gf":
                        resolve_faction_choice("GF");
                        break;

                    case "faction_sp":
                        resolve_faction_choice("SP");
                        break;

                    case "faction_cz":
                        resolve_faction_choice("CZ");
                        break;

                    case "faction_bh":
                        resolve_faction_choice("BH");
                        break;

                    case "faction_pz":
                        resolve_faction_choice("PZ");
                        break;

                    case "test_open":
                    case "test_close":
                    case "test_tab_game":
                    case "test_tab_animation":
                    case "test_anim_deploy":
                    case "test_anim_event":
                    case "test_anim_reserve":
                    case "test_anim_refresh_hand":
                    case "test_anim_refresh_shop":
                    case "test_anim_shuffle":
                    case "test_anim_evolve":
                    case "test_anim_phazon":
                    case "test_anim_lab":
                    case "test_anim_page":
                    case "test_anim_capture":
                    case "test_anim_attachment":
                    case "test_anim_target_friendly":
                    case "test_anim_target_enemy":
                    case "test_anim_discard":
                    case "test_anim_destroy":
                    case "test_anim_raid":
                    case "test_anim_breaches":
                    case "test_anim_queen":
                    case "test_cp":
                    case "test_ready":
                    case "test_deploy":
                    case "test_larva":
                    case "test_omega":
                    case "test_queen":
                    case "test_game_over":
                    case "test_random_win":
                    case "test_fixed_seed":
                    case "test_random_seed":
                        handle_test_tool_action(_hover_region.action);
                        break;

                    case "activate_0":
                        activate_selected_ability(
                            ui_selected_kind,
                            ui_selected_index,
                            0
                        );
                        break;

                    case "activate_1":
                        activate_selected_ability(
                            ui_selected_kind,
                            ui_selected_index,
                            1
                        );
                        break;

                    case "activate_2":
                        activate_selected_ability(
                            ui_selected_kind,
                            ui_selected_index,
                            2
                        );
                        break;

                    case "refresh_hand":
                        begin_hand_refresh_choice();
                        break;

                    case "confirm_hand_refresh":
                        confirm_hand_refresh_choice();
                        break;

                    case "confirm_dark_samus_discard":
                        confirm_dark_samus_discard();
                        break;

                    case "refresh_shop":
                        refresh_shop_action();
                        break;

                    case "cancel":
                        cancel_pending_choice();
                        break;

                    case "restart":
                        room_restart();
                        break;

                    case "handoff_continue":
                        confirm_turn_handoff();
                        break;

                    case "title_hotseat":
                        start_game_mode("hotseat");
                        break;

                    case "title_ai":
                        start_game_mode("ai");
                        break;

                    case "title_ai_watch":
                        start_game_mode("ai_watch");
                        break;
                }
                // Buttons consume the selection they acted on. Any follow-up
                // choice carries its own source data in pending_choice.
                ui_selected_kind = "";
                ui_selected_index = -1;
                ui_selected_instance_id = -1;
                ui_context_preview_kind = "";
                ui_context_preview_index = -1;
                ui_context_preview_until_ms = 0;
            }
        } else if (!is_undefined(pending_choice)
        && pending_choice.kind == "raid"
        && pending_choice.stage == "attacker_ship"
        && _hover_region.kind == "ship") {
            select_raid_attacker(_hover_region.index);
        } else if (!is_undefined(pending_choice)
        && pending_choice.kind == "hand_refresh"
        && _hover_region.kind == "hand") {
            toggle_hand_refresh_card(_hover_region.index);
        } else if (!is_undefined(pending_choice)
        && pending_choice.kind == "torizo_metroid"
        && _hover_region.kind == "lab") {
            resolve_torizo_metroid_choice(_hover_region.index);
        } else if (_hover_region.kind == "lab_tab") {
            if (ui_selected_kind == "lab_tab") {
                ui_selected_kind = "";
                ui_selected_index = -1;
            } else {
                ui_selected_kind = "lab_tab";
                ui_selected_index = 0;
                ui_selected_instance_id = -1;
            }
        } else if (_hover_region.kind == "opponent_lab_tab") {
            if (ui_selected_kind == "opponent_lab_tab") {
                ui_selected_kind = "";
                ui_selected_index = -1;
            } else {
                ui_selected_kind = "opponent_lab_tab";
                ui_selected_index = 0;
                ui_selected_instance_id = -1;
            }
        } else if (!is_undefined(pending_choice)
        && pending_choice.kind == "chozo_ghosts_source"
        && !is_undefined(_hover_region.instance)) {
            resolve_chozo_ghosts_source(_hover_region.instance);
        } else if (!is_undefined(pending_choice)
        && pending_choice.kind == "chozo_ghosts_target"
        && !is_undefined(_hover_region.instance)) {
            resolve_chozo_ghosts_target(_hover_region.instance);
        } else if (!is_undefined(pending_choice)
        && pending_choice.kind == "breach_character"
        && ((_hover_region.kind == "character"
            && pending_choice.player_index == game_state.active_player)
            || (_hover_region.kind == "opponent_character"
            && pending_choice.player_index != game_state.active_player))) {
            resolve_breach_character_choice(_hover_region.index);
        } else if (!is_undefined(pending_choice)
        && pending_choice.kind == "olympus_ready"
        && ((_hover_region.kind == "character"
            && pending_choice.player_index == game_state.active_player)
            || (_hover_region.kind == "opponent_character"
            && pending_choice.player_index != game_state.active_player))) {
            resolve_olympus_ready_choice(_hover_region.index);
        } else if (!is_undefined(pending_choice)
        && pending_choice.kind == "hyper_mode_character"
        && ((_hover_region.kind == "character"
            && pending_choice.player_index == game_state.active_player)
            || (_hover_region.kind == "opponent_character"
            && pending_choice.player_index != game_state.active_player))) {
            resolve_hyper_mode_character(_hover_region.index);
        } else if (!is_undefined(pending_choice)
        && pending_choice.kind == "researcher_discard"
        && _hover_region.kind == "hand") {
            resolve_researcher_discard(_hover_region.index);
        } else if (!is_undefined(pending_choice)
        && pending_choice.kind == "special_containment_ship"
        && ((_hover_region.kind == "ship"
            && pending_choice.player_index == game_state.active_player)
            || (_hover_region.kind == "opponent_ship"
            && pending_choice.player_index != game_state.active_player))) {
            ui_selected_kind = _hover_region.kind;
            ui_selected_index = _hover_region.index;
            ui_selected_instance_id = is_undefined(_hover_region.instance)
                ? -1
                : _hover_region.instance.instance_id;
        } else if (!is_undefined(pending_choice)
        && pending_choice.kind == "raid"
        && pending_choice.stage == "target"
        && (_hover_region.kind == "opponent_ship"
        || _hover_region.kind == "opponent_cargo")) {
            select_raid_target(_hover_region.index);
        } else if (!is_undefined(pending_choice)
        && pending_choice.kind == "raid"
        && !is_undefined(_hover_region.instance)
        && _hover_region.instance.controller == game_state.priority_player
        && (_hover_region.kind == "character"
            || _hover_region.kind == "ship"
            || _hover_region.kind == "location"
            || _hover_region.kind == "relic"
            || _hover_region.kind == "opponent_character"
            || _hover_region.kind == "opponent_ship"
            || _hover_region.kind == "opponent_location"
            || _hover_region.kind == "opponent_relic")) {
            var _clicked_raid_source_kind = get_raid_source_kind(
                _hover_region.kind,
                _hover_region.instance
            );
            select_raid_ability_source(
                _clicked_raid_source_kind,
                _hover_region.index
            );
            if (_hover_region.instance.definition.type == "character") {
                raid_contribute_selected(
                    _clicked_raid_source_kind,
                    _hover_region.index
                );
            }
        } else if (!is_undefined(pending_choice)
        && pending_choice.kind == "ability_target") {
            var _ability_target_kind = _hover_region.kind;
            if (!is_undefined(_hover_region.instance)
            && (_hover_region.kind == "character"
                || _hover_region.kind == "ship"
                || _hover_region.kind == "location"
                || _hover_region.kind == "relic"
                || _hover_region.kind == "opponent_character"
                || _hover_region.kind == "opponent_ship"
                || _hover_region.kind == "opponent_location"
                || _hover_region.kind == "opponent_relic")) {
                _ability_target_kind = get_raid_source_kind(
                    _hover_region.kind, _hover_region.instance
                );
            }
            if (resolve_ability_target_choice(
                _ability_target_kind,
                _hover_region.index
            )) {
                ui_selected_kind = "";
                ui_selected_index = -1;
            }
        } else if (!is_undefined(pending_choice)
        && pending_choice.kind == "teleport_destination"
        && (_hover_region.kind == "ship"
            || _hover_region.kind == "opponent_ship")) {
            resolve_teleport_destination_choice(
                _hover_region.kind,
                _hover_region.index
            );
        } else if (!is_undefined(pending_choice)
        && pending_choice.kind == "quiet_robe_metroids"
        && _hover_region.kind == "metroid") {
            resolve_quiet_robe_metroid_choice(_hover_region.index);
        } else if (!is_undefined(pending_choice)
        && pending_choice.kind == "space_pirate_ready") {
            resolve_space_pirate_ready(
                _hover_region.kind,
                _hover_region.index
            );
        } else if (!is_undefined(pending_choice)
        && pending_choice.kind == "capture_metroid"
        && _hover_region.kind == "metroid") {
            selected_metroid_source = _hover_region.index;
            if (capture_metroid_action(
                pending_choice.ship_index,
                selected_metroid_source
            )) {
                pending_choice = undefined;
                ui_selected_kind = "";
                ui_selected_index = -1;
            }
        } else if (is_undefined(pending_choice)) {
            ui_selected_kind = _hover_region.kind;
            ui_selected_index = _hover_region.index;
            ui_selected_instance_id = is_undefined(_hover_region.instance)
                ? -1
                : _hover_region.instance.instance_id;

            switch (_hover_region.kind) {
                case "shop":
                    selected_shop_index = _hover_region.index;
                    break;
                case "hand":
                    selected_hand_index = _hover_region.index;
                    var _clicked_hand_id = _hover_region.instance.instance_id;
                    if (last_hand_click_instance_id == _clicked_hand_id
                    && current_time - last_hand_click_time <= 350
                    && can_play_hand_card(_hover_region.index)
                    && game_state.game_mode != "network") {
                        play_hand_card(_hover_region.index);
                        last_hand_click_instance_id = -1;
                        last_hand_click_time = -1000;
                    } else {
                        last_hand_click_instance_id = _clicked_hand_id;
                        last_hand_click_time = current_time;
                    }
                    break;
                case "ship":
                    selected_ship_index = _hover_region.index;
                    break;
                case "metroid":
                    selected_metroid_source = _hover_region.index;
                    break;
            }
        }
    }

    // An array index identifies a position, not a card. If the selected card
    // leaves its zone, do not let selection silently transfer to its replacement.
    if (ui_selected_instance_id >= 0 && ui_selected_kind != "") {
        var _selected_current = undefined;
        var _selected_player = game_state.players[game_state.active_player];
        var _selected_opponent = game_state.players[1 - game_state.active_player];
        switch (ui_selected_kind) {
            case "shop":
                if (ui_selected_index < array_length(game_state.shop_row)) {
                    _selected_current = game_state.shop_row[ui_selected_index];
                }
                break;
            case "hand":
                if (ui_selected_index < array_length(_selected_player.hand)) {
                    _selected_current = _selected_player.hand[ui_selected_index];
                }
                break;
            case "discard":
                if (ui_selected_index < array_length(_selected_player.discard)) {
                    _selected_current = _selected_player.discard[ui_selected_index];
                }
                break;
            case "ship":
                if (ui_selected_index < array_length(_selected_player.board.ships)) {
                    _selected_current = _selected_player.board.ships[ui_selected_index];
                }
                break;
            case "character":
                if (ui_selected_index < array_length(
                    _selected_player.board.characters
                )) {
                    _selected_current =
                        _selected_player.board.characters[ui_selected_index];
                }
                break;
            case "location":
                if (ui_selected_index < array_length(
                    _selected_player.board.locations
                )) {
                    _selected_current =
                        _selected_player.board.locations[ui_selected_index];
                }
                break;
            case "relic":
                if (ui_selected_index < array_length(
                    _selected_player.board.relics
                )) {
                    _selected_current =
                        _selected_player.board.relics[ui_selected_index];
                }
                break;
            case "lab":
                if (ui_selected_index < array_length(_selected_player.lab)) {
                    _selected_current = _selected_player.lab[ui_selected_index];
                }
                break;
            case "opponent_ship":
                if (ui_selected_index < array_length(_selected_opponent.board.ships)) {
                    _selected_current =
                        _selected_opponent.board.ships[ui_selected_index];
                }
                break;
            case "opponent_character":
                if (ui_selected_index < array_length(
                    _selected_opponent.board.characters
                )) {
                    _selected_current =
                        _selected_opponent.board.characters[ui_selected_index];
                }
                break;
            case "opponent_location":
                if (ui_selected_index < array_length(
                    _selected_opponent.board.locations
                )) {
                    _selected_current =
                        _selected_opponent.board.locations[ui_selected_index];
                }
                break;
            case "opponent_relic":
                if (ui_selected_index < array_length(
                    _selected_opponent.board.relics
                )) {
                    _selected_current =
                        _selected_opponent.board.relics[ui_selected_index];
                }
                break;
            case "opponent_lab":
                if (ui_selected_index < array_length(_selected_opponent.lab)) {
                    _selected_current = _selected_opponent.lab[ui_selected_index];
                }
                break;
            case "opponent_discard":
                if (ui_selected_index < array_length(_selected_opponent.discard)) {
                    _selected_current =
                        _selected_opponent.discard[ui_selected_index];
                }
                break;
            case "cargo":
                if (ui_selected_index < array_length(_selected_player.board.ships)
                && array_length(
                    _selected_player.board.ships[ui_selected_index].cargo
                ) > 0) {
                    _selected_current =
                        _selected_player.board.ships[ui_selected_index].cargo[0];
                }
                break;
            case "opponent_cargo":
                if (ui_selected_index < array_length(_selected_opponent.board.ships)
                && array_length(
                    _selected_opponent.board.ships[ui_selected_index].cargo
                ) > 0) {
                    _selected_current =
                        _selected_opponent.board.ships[ui_selected_index].cargo[0];
                }
                break;
            case "metroid":
                if (ui_selected_index == 4) {
                    if (array_length(game_state.cavern) > 0) {
                        _selected_current = game_state.cavern[
                            array_length(game_state.cavern) - 1
                        ];
                    }
                } else if (ui_selected_index >= 0
                && ui_selected_index < array_length(game_state.sr388)) {
                    _selected_current = game_state.sr388[ui_selected_index];
                }
                break;
        }
        if (is_undefined(_selected_current)
        || _selected_current.instance_id != ui_selected_instance_id) {
            ui_selected_kind = "";
            ui_selected_index = -1;
            ui_selected_instance_id = -1;
        }
    }

    // Optional debug shortcuts. Mouse controls are the primary interface.
    if (!chat_input_active
    && keyboard_check_pressed(ord("E"))
    && game_state.phase == "action"
    && game_state.game_mode != "network") {
        end_turn_action();
    }

    if (!chat_input_active
    && keyboard_check_pressed(vk_space)
    && game_state.phase != "action"
    && is_undefined(pending_choice)
    && game_state.game_mode != "network") {
        if (game_state.phase == "containment") {
            resolve_turn_containment(-1);
        } else {
            advance_game_phase();
        }
    }
}

