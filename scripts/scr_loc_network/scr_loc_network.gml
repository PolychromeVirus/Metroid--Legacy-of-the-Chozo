function loc_network() {
    get_player_chat_color = function(_player_index) {
        if (_player_index < 0
        || _player_index >= array_length(game_state.players)) {
            return LOC_COLOR_NEUTRAL;
        }
        switch (game_state.players[_player_index].favored_faction) {
            case "GF": return LOC_COLOR_GF;
            case "SP": return LOC_COLOR_SP;
            case "CZ": return LOC_COLOR_CZ;
            case "BH": return LOC_COLOR_BH;
            case "PZ": return LOC_COLOR_PZ;
        }
        return LOC_COLOR_NEUTRAL;
    };

    append_chat_message = function(_player_index, _message) {
        if (_player_index < 0
        || _player_index >= array_length(game_state.players)) {
            return false;
        }
        var _clean_message = string_copy(string_trim(string(_message)), 1, 200);
        if (_clean_message == "") {
            return false;
        }
        var _player_name = string(game_state.players[_player_index].name);
        array_push(game_state.event_log, {
            kind: "chat",
            text: _player_name + ": " + _clean_message,
            name_text: _player_name + ":",
            name_color: get_player_chat_color(_player_index)
        });
        event_log_scroll = 0;
        return true;
    };

    append_network_chat_message = function(_participant_id, _message) {
        var _index = network_find_participant(_participant_id);
        if (_index < 0) return false;
        var _participant = net_lobby_participants[_index];
        var _clean_message = string_copy(string_trim(string(_message)), 1, 200);
        if (_clean_message == "") return false;
        var _name = string(_participant.name);
        var _color = _participant.seat >= 0
            ? get_player_chat_color(_participant.seat)
            : LOC_COLOR_NEUTRAL;
        array_push(game_state.event_log, {
            kind: "chat",
            text: _name + ": " + _clean_message,
            name_text: _name + ":",
            name_color: _color
        });
        event_log_scroll = 0;
        return true;
    };

    append_spectator_chat_message = function(_name, _message) {
        var _clean_message = string_copy(string_trim(string(_message)), 1, 200);
        if (_clean_message == "") return false;
        var _spectator_name = string_trim(string(_name));
        if (_spectator_name == "") _spectator_name = "Spectator";
        array_push(game_state.event_log, {
            kind: "chat",
            text: _spectator_name + ": " + _clean_message,
            name_text: _spectator_name + ":",
            name_color: LOC_COLOR_NEUTRAL
        });
        event_log_scroll = 0;
        return true;
    };

    submit_chat_message = function(_message) {
        var _sender = game_state.game_mode == "network"
            ? network_local_player
            : (game_state.game_mode == "hotseat"
                ? game_state.active_player
                : game_state.view_player);
        var _clean_message = string_copy(string_trim(string(_message)), 1, 200);
        var _chat_appended;
        if (game_state.game_mode == "network") {
            _chat_appended = append_network_chat_message(
                net_local_participant_id, _clean_message
            );
        } else if (game_state.game_mode == "ai_watch") {
            _chat_appended = append_spectator_chat_message(
                net_player_name, _clean_message
            );
        } else {
            _chat_appended = append_chat_message(_sender, _clean_message);
        }
        if (!_chat_appended) {
            return false;
        }
        if (game_state.game_mode == "network") {
            var _chat_packet = {
                type: "chat_message",
                sender_id: net_local_participant_id,
                message: _clean_message
            };
            if (net_role == "host") {
                network_broadcast(_chat_packet);
            } else {
                network_send_message(net_socket, _chat_packet);
            }
        }
        return true;
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

    network_broadcast = function(_message, _except_socket) {
        var _sent_any = false;
        for (var _socket_index = 0;
             _socket_index < array_length(net_client_sockets);
             _socket_index++) {
            var _client_socket = net_client_sockets[_socket_index];
            if (_client_socket >= 0
            && (is_undefined(_except_socket)
                || _client_socket != _except_socket)) {
                _sent_any = network_send_message(_client_socket, _message)
                    || _sent_any;
            }
        }
        return _sent_any;
    };

    network_lobby_public_state = function() {
        var _result = [];
        for (var _index = 0;
             _index < array_length(net_lobby_participants);
             _index++) {
            var _participant = net_lobby_participants[_index];
            array_push(_result, {
                id: _participant.id,
                name: _participant.name,
                seat: _participant.seat,
                leader_id: _participant.leader_id,
                ready: _participant.ready,
                host: _participant.host
            });
        }
        return _result;
    };

    network_broadcast_lobby = function() {
        var _state = network_lobby_public_state();
        network_broadcast({type: "lobby_state", participants: _state});
        return _state;
    };

    network_find_participant = function(_participant_id) {
        for (var _index = 0;
             _index < array_length(net_lobby_participants);
             _index++) {
            if (net_lobby_participants[_index].id == _participant_id) {
                return _index;
            }
        }
        return -1;
    };

    network_find_participant_by_socket = function(_socket) {
        for (var _index = 0;
             _index < array_length(net_lobby_participants);
             _index++) {
            var _participant = net_lobby_participants[_index];
            if (variable_struct_exists(_participant, "socket")
            && _participant.socket == _socket) return _index;
        }
        return -1;
    };

    network_lobby_apply_action = function(_participant_id, _action, _value) {
        if (net_role != "host") return false;
        var _index = network_find_participant(_participant_id);
        if (_index < 0) return false;
        var _participant = net_lobby_participants[_index];
        switch (_action) {
            case "claim_seat":
                var _seat = floor(real(_value));
                if (_seat < 0 || _seat >= net_lobby_seat_count) return false;
                for (var _seat_check = 0;
                     _seat_check < array_length(net_lobby_participants);
                     _seat_check++) {
                    if (_seat_check != _index
                    && net_lobby_participants[_seat_check].seat == _seat) {
                        return false;
                    }
                }
                _participant.seat = _seat;
                _participant.ready = false;
                break;
            case "spectate":
                _participant.seat = -1;
                _participant.ready = false;
                break;
            case "toggle_ready":
                if (_participant.seat < 0) return false;
                _participant.ready = !_participant.ready;
                break;
            case "set_leader":
                _participant.leader_id = resolve_leader_identity_id(
                    string(_value)
                );
                _participant.ready = false;
                break;
            default: return false;
        }
        net_lobby_participants[_index] = _participant;
        network_broadcast_lobby();
        return true;
    };

    network_lobby_submit_action = function(_action, _value) {
        if (net_role == "host") {
            return network_lobby_apply_action(
                net_local_participant_id, _action, _value
            );
        }
        return network_send_message(net_socket, {
            type: "lobby_action", action: _action, value: _value
        });
    };

    network_begin_host = function() {
        global.loc_player_name = net_player_name;
        net_leader_id = resolve_leader_identity_id(
            title_leader_keys[title_leader_p1_index]
        );
        net_role = "host";
        net_status = "Opening host on port " + string(net_port) + "...";
        net_server = network_create_server(network_socket_tcp, net_port, 7);
        if (net_server < 0) {
            net_status = "Could not open port " + string(net_port) + ".";
            return false;
        }
        title_menu_active = false;
        network_lobby_active = true;
        net_client_sockets = [];
        net_local_participant_id = 0;
        net_next_participant_id = 1;
        net_lobby_participants = [{
            id: 0,
            name: net_player_name,
            seat: 0,
            leader_id: net_leader_id,
            ready: false,
            host: true,
            socket: -1
        }];
        net_status = "Lobby open on port " + string(net_port) + ".";
        show_debug_message("[NET] " + net_status);
        return true;
    };

    network_open_join = function() {
        global.loc_player_name = net_player_name;
        net_leader_id = resolve_leader_identity_id(
            title_leader_keys[title_leader_p1_index]
        );
        net_role = "client";
        net_status = "Enter the host address.";
        title_menu_active = false;
        network_lobby_active = true;
        net_local_participant_id = -1;
        net_lobby_participants = [];
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

    network_prepare_match_restart = function(
        _role, _socket, _server, _seed, _breaching_mutation,
        _loaded_ships_exhausted
    ) {
        global.loc_test_seed = _seed;
        global.loc_network_resume = true;
        global.loc_network_role = _role;
        global.loc_network_socket = _socket;
        global.loc_network_server = _server;
        global.loc_network_client_sockets = net_client_sockets;
        global.loc_network_participant_id = net_local_participant_id;
        global.loc_network_breaching_mutation = _breaching_mutation;
        global.loc_network_loaded_ships_exhausted = _loaded_ships_exhausted;
        global.loc_network_lobby_snapshot = net_role == "host"
            ? net_lobby_participants
            : network_lobby_public_state();
        room_restart();
    };

    network_start_lobby_match = function() {
        if (net_role != "host") return false;
        var _occupied = [false, false];
        var _ready = [false, false];
        for (var _index = 0;
             _index < array_length(net_lobby_participants);
             _index++) {
            var _participant = net_lobby_participants[_index];
            if (_participant.seat >= 0 && _participant.seat < 2) {
                _occupied[_participant.seat] = true;
                _ready[_participant.seat] = _participant.ready;
            }
        }
        if (!_occupied[0] || !_occupied[1] || !_ready[0] || !_ready[1]) {
            net_status = "Both player seats must be occupied and ready.";
            return false;
        }
        randomize();
        var _seed = irandom(2147483646);
        network_broadcast({
            type: "start_match",
            protocol: 3,
            seed: _seed,
            breaching_mutation: settings_experimental_breaching_mutation,
            loaded_ships_exhausted:
                settings_experimental_loaded_ships_exhausted,
            participants: network_lobby_public_state()
        });
        network_prepare_match_restart(
            "host", -1, net_server, _seed,
            settings_experimental_breaching_mutation,
            settings_experimental_loaded_ships_exhausted
        );
        return true;
    };

    network_expected_player = function() {
        // Rules code transfers priority whenever a choice changes hands. Treat
        // that as the single authority; fields such as owner_index describe the
        // source card and are not necessarily the player making the choice.
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
                    if (pending_choice.stage == "attacker_ship") {
                        if (_kind != "ship") return false;
                        return select_raid_attacker(_index);
                    } else if (pending_choice.stage == "target") {
                        return select_raid_target(_index);
                    }
                    return select_raid_ability_source(_kind, _index);
                case "ability_target":
                    return resolve_ability_target_choice(_kind, _index);
                case "quiet_robe_metroids":
                    if (_kind != "metroid") return false;
                    return resolve_quiet_robe_metroid_choice(_index);
                case "torizo_metroid":
                    if (_kind != "lab") return false;
                    return resolve_torizo_metroid_choice(_index);
                case "hyper_mode_character":
                    if (_kind != "character"
                    && _kind != "opponent_character") return false;
                    return resolve_hyper_mode_character(_index);
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
                case "chozo_ghosts_source":
                    return resolve_chozo_ghosts_source(
                        get_ability_source(_kind, _index)
                    );
                case "chozo_ghosts_target":
                    return resolve_chozo_ghosts_target(
                        get_ability_source(_kind, _index)
                    );
            }
            return false;
        }

        if (string_pos("back_in_day_pick_", _input.action) == 1) {
            var _back_pick_text = string_delete(
                _input.action,
                1,
                string_length("back_in_day_pick_")
            );
            return resolve_back_in_the_day_choice(real(_back_pick_text));
        }
        if (string_pos("raid_target_", _input.action) == 1) {
            var _raid_target_text = string_delete(
                _input.action,
                1,
                string_length("raid_target_")
            );
            return begin_raid_target_choice(real(_raid_target_text));
        }
        switch (_input.action) {
            case "back_in_day_prev":
                pending_choice.page = max(0, pending_choice.page - 1);
                return true;
            case "back_in_day_next":
                pending_choice.page += 1;
                return true;
            case "advance_phase": return advance_game_phase();
            case "containment_no_ship": return resolve_turn_containment(-1);
            case "containment_use_ship":
                return resolve_turn_containment(_input.selected_index);
            case "end_turn": return end_turn_action();
            case "reserve": return reserve_shop_card(_input.selected_index);
            case "deploy": return deploy_shop_card(_input.selected_index);
            case "play": return play_hand_card(_input.selected_index);
            case "salvage":
                return salvage_permanent(
                    _input.selected_kind,
                    _input.selected_index
                );
            case "capture": return begin_capture_choice(_input.selected_index);
            case "raid": return begin_raid_choice(_input.selected_index);
            case "lock_raid_attackers": return lock_raid_attackers();
            case "resolve_raid": return resolve_raid();
            case "raid_cargo_0": return finish_attacker_raid_win(0);
            case "raid_cargo_1": return finish_attacker_raid_win(1);
            case "raid_cargo_2": return finish_attacker_raid_win(2);
            case "raid_cargo_3": return finish_attacker_raid_win(3);
            case "raid_toggle_mode": return toggle_raid_ability_mode();
            case "raid_contribute": return raid_contribute_selected(
                _input.selected_kind, _input.selected_index
            );
            case "raid_activate": return activate_raid_selected_ability();
            case "raid_use_0": return activate_raid_ability_index(
                0, _input.selected_kind, _input.selected_index
            );
            case "raid_use_1": return activate_raid_ability_index(
                1, _input.selected_kind, _input.selected_index
            );
            case "raid_use_2": return activate_raid_ability_index(
                2, _input.selected_kind, _input.selected_index
            );
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
            case "confirm_dark_samus_discard":
                return confirm_dark_samus_discard();
            case "refresh_shop": return refresh_shop_action();
            case "cancel": return cancel_pending_choice();
        }
        return false;
    };

    network_submit_input = function(_input) {
        if (network_local_player < 0) {
            show_debug_message("[NET] Spectators cannot submit game input.");
            return false;
        }
        if (network_local_player != network_expected_player()) {
            show_debug_message("[NET] Ignored out-of-priority local input.");
            return false;
        }
        if (net_role == "host") {
            net_command_sequence += 1;
            _input.type = "command_commit";
            _input.sequence = net_command_sequence;
            network_broadcast(_input);
            return network_execute_input(_input);
        }
        _input.type = "command_request";
        return network_send_message(net_socket, _input);
    };

}

