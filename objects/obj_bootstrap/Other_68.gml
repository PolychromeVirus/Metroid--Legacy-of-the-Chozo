/// @description Direct-IP TCP lobby and network packet handling.

var _event_type = async_load[? "type"];
var _event_socket = ds_map_exists(async_load, "id")
    ? async_load[? "id"] : -1;

switch (_event_type) {
    case network_type_connect:
        if (net_role == "host") {
            var _connected_socket = async_load[? "socket"];
            array_push(net_client_sockets, _connected_socket);
            net_peer_socket = net_client_sockets[0];
            if (network_lobby_active) {
                net_status = "A participant connected. Exchanging lobby data...";
            }
        }
        break;

    case network_type_non_blocking_connect:
        if (net_role == "client") {
            if (async_load[? "succeeded"]) {
                net_status = "Connected. Joining lobby...";
                network_send_message(net_socket, {
                    type: "join_hello",
                    protocol: 2,
                    player_name: net_player_name,
                    leader_id: net_leader_id
                });
                show_debug_message("[NET] Connected to host.");
            } else {
                net_status = "Connection failed.";
                net_join_field = "address";
                keyboard_string = net_ip_input;
                show_debug_message("[NET] Connection failed.");
            }
        }
        break;

    case network_type_data:
        var _packet_buffer = async_load[? "buffer"];
        buffer_seek(_packet_buffer, buffer_seek_start, 0);
        var _packet = json_parse(buffer_read(_packet_buffer, buffer_string));
        if (!variable_struct_exists(_packet, "type")) break;
        switch (_packet.type) {
            case "join_hello":
                if (net_role != "host") break;
                if (!network_lobby_active) {
                    network_send_message(_event_socket, {
                        type: "join_rejected",
                        reason: "This match is already in progress."
                    });
                    break;
                }
                if (_packet.protocol != 2) {
                    network_send_message(_event_socket, {
                        type: "join_rejected",
                        reason: "Network protocol mismatch."
                    });
                    break;
                }
                var _guest_name = string_copy(
                    string_trim(string(_packet.player_name)), 1, 24
                );
                if (_guest_name == "") _guest_name = "Spectator";
                var _open_seat = -1;
                for (var _seat = 0; _seat < net_lobby_seat_count; _seat++) {
                    var _seat_taken = false;
                    for (var _seat_user = 0;
                         _seat_user < array_length(net_lobby_participants);
                         _seat_user++) {
                        if (net_lobby_participants[_seat_user].seat == _seat) {
                            _seat_taken = true;
                            break;
                        }
                    }
                    if (!_seat_taken) {
                        _open_seat = _seat;
                        break;
                    }
                }
                var _new_participant_id = net_next_participant_id;
                net_next_participant_id += 1;
                array_push(net_lobby_participants, {
                    id: _new_participant_id,
                    name: _guest_name,
                    seat: _open_seat,
                    leader_id: variable_struct_exists(_packet, "leader_id")
                        ? resolve_leader_identity_id(_packet.leader_id)
                        : "bsl_researcher",
                    ready: false,
                    host: false,
                    socket: _event_socket
                });
                var _joined_state = network_lobby_public_state();
                network_send_message(_event_socket, {
                    type: "lobby_welcome",
                    participant_id: _new_participant_id,
                    participants: _joined_state
                });
                network_broadcast_lobby();
                net_status = _guest_name + " joined the lobby.";
                break;

            case "lobby_welcome":
                if (net_role == "client") {
                    net_local_participant_id = _packet.participant_id;
                    net_lobby_participants = _packet.participants;
                    net_status = "Joined lobby.";
                }
                break;

            case "lobby_state":
                if (net_role == "client") {
                    net_lobby_participants = _packet.participants;
                }
                break;

            case "lobby_action":
                if (net_role == "host") {
                    var _action_user = network_find_participant_by_socket(
                        _event_socket
                    );
                    if (_action_user >= 0) {
                        network_lobby_apply_action(
                            net_lobby_participants[_action_user].id,
                            _packet.action,
                            variable_struct_exists(_packet, "value")
                                ? _packet.value : 0
                        );
                    }
                }
                break;

            case "start_match":
                if (net_role == "client") {
                    if (_packet.protocol != 3) {
                        net_status = "Network protocol mismatch.";
                        break;
                    }
                    net_lobby_participants = _packet.participants;
                    network_prepare_match_restart(
                        "client", net_socket, -1, _packet.seed,
                        _packet.breaching_mutation,
                        variable_struct_exists(
                            _packet, "loaded_ships_exhausted"
                        ) && _packet.loaded_ships_exhausted
                    );
                }
                break;

            case "command_request":
                if (net_role == "host") {
                    var _request_user = network_find_participant_by_socket(
                        _event_socket
                    );
                    var _request_seat = _request_user >= 0
                        ? net_lobby_participants[_request_user].seat : -1;
                    if (_request_seat == network_expected_player()) {
                        net_command_sequence += 1;
                        _packet.type = "command_commit";
                        _packet.sequence = net_command_sequence;
                        network_broadcast(_packet);
                        network_execute_input(_packet);
                    } else {
                        show_debug_message(
                            "[NET] Rejected input outside participant priority."
                        );
                    }
                }
                break;

            case "command_commit":
                if (net_role == "client"
                && _packet.sequence == net_last_applied_sequence + 1) {
                    net_last_applied_sequence = _packet.sequence;
                    network_execute_input(_packet);
                }
                break;

            case "chat_message":
                if (!network_lobby_active
                && game_state.game_mode == "network"
                && variable_struct_exists(_packet, "message")) {
                    if (net_role == "host") {
                        var _chat_sender_index =
                            network_find_participant_by_socket(_event_socket);
                        if (_chat_sender_index >= 0) {
                            var _chat_sender_id = net_lobby_participants[
                                _chat_sender_index
                            ].id;
                            append_network_chat_message(
                                _chat_sender_id, _packet.message
                            );
                            network_broadcast({
                                type: "chat_message",
                                sender_id: _chat_sender_id,
                                message: _packet.message
                            }, _event_socket);
                        }
                    } else if (variable_struct_exists(
                        _packet, "sender_id"
                    )) {
                        append_network_chat_message(
                            _packet.sender_id, _packet.message
                        );
                    }
                }
                break;

            case "join_rejected":
                net_status = string(_packet.reason);
                break;

            case "participant_disconnected":
                net_status = _packet.seat >= 0
                    ? string(_packet.name) + " disconnected from Player "
                        + string(_packet.seat + 1) + "."
                    : string(_packet.name) + " stopped spectating.";
                if (!network_lobby_active) {
                    array_push(game_state.event_log, net_status);
                }
                var _remove_participant = network_find_participant(
                    _packet.participant_id
                );
                if (_remove_participant >= 0) {
                    array_delete(
                        net_lobby_participants, _remove_participant, 1
                    );
                }
                break;
        }
        break;

    case network_type_disconnect:
        if (net_role == "host") {
            var _departed = network_find_participant_by_socket(_event_socket);
            var _departed_seat = -1;
            var _departed_name = "A participant";
            if (_departed >= 0) {
                _departed_seat = net_lobby_participants[_departed].seat;
                _departed_name = net_lobby_participants[_departed].name;
                network_broadcast({
                    type: "participant_disconnected",
                    participant_id: net_lobby_participants[_departed].id,
                    name: _departed_name,
                    seat: _departed_seat
                }, _event_socket);
                array_delete(net_lobby_participants, _departed, 1);
            }
            for (var _socket_index = array_length(net_client_sockets) - 1;
                 _socket_index >= 0;
                 _socket_index--) {
                if (net_client_sockets[_socket_index] == _event_socket) {
                    array_delete(net_client_sockets, _socket_index, 1);
                }
            }
            net_peer_socket = array_length(net_client_sockets) > 0
                ? net_client_sockets[0] : -1;
            if (network_lobby_active) {
                network_broadcast_lobby();
                net_status = "A participant left the lobby.";
            } else if (_departed_seat >= 0) {
                net_status = "A player disconnected.";
            } else {
                net_status = "A spectator disconnected.";
            }
        } else {
            net_status = "Disconnected from host.";
        }
        show_debug_message("[NET] " + net_status);
        break;
}
