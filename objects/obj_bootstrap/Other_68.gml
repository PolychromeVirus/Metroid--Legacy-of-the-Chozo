/// @description Direct-IP TCP lobby and network packet handling.

var _event_type = async_load[? "type"];

switch (_event_type) {
    case network_type_connect:
        if (net_role == "host" && network_lobby_active) {
            net_peer_socket = async_load[? "socket"];
            net_status = "Player 2 connected. Exchanging names...";
        }
        break;

    case network_type_non_blocking_connect:
        if (net_role == "client") {
            if (async_load[? "succeeded"]) {
                net_status = "Connected. Waiting for the host...";
                network_send_message(
                    net_socket,
                    {
                        type: "join_hello",
                        protocol: 1,
                        player_name: net_player_name,
                        leader_id: net_leader_id
                    }
                );
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
        var _packet_text = buffer_read(_packet_buffer, buffer_string);
        var _packet = json_parse(_packet_text);
        if (variable_struct_exists(_packet, "type")) {
            switch (_packet.type) {
                case "join_hello":
                    if (net_role == "host" && _packet.protocol == 1) {
                        randomize();
                        var _match_seed = irandom(2147483646);
                        var _guest_name = string(_packet.player_name);
                        if (_guest_name == "") {
                            _guest_name = "Player 2";
                        }
                        global.loc_network_host_name = net_player_name;
                        global.loc_network_guest_name = _guest_name;
                        global.loc_network_host_leader = net_leader_id;
                        global.loc_network_guest_leader =
                            variable_struct_exists(_packet, "leader_id")
                                ? _packet.leader_id
                                : "bsl_researcher";
                        net_status = _guest_name
                            + " connected. Starting match...";
                        show_debug_message(
                            "[NET] " + _guest_name
                            + " joined; starting seed "
                            + string(_match_seed) + "."
                        );
                        network_send_message(
                            net_peer_socket,
                            {
                                type: "start_match",
                                protocol: 1,
                                seed: _match_seed,
                                host_name: net_player_name,
                                guest_name: _guest_name,
                                host_leader: global.loc_network_host_leader,
                                guest_leader: global.loc_network_guest_leader
                            }
                        );
                        network_prepare_match_restart(
                            "host",
                            net_peer_socket,
                            net_server,
                            _match_seed
                        );
                    }
                    break;

                case "start_match":
                    if (net_role == "client") {
                        if (_packet.protocol != 1) {
                            net_status = "Network protocol mismatch.";
                            break;
                        }
                        show_debug_message(
                            "[NET] Host selected seed "
                            + string(_packet.seed) + "."
                        );
                        global.loc_network_host_name = _packet.host_name;
                        global.loc_network_guest_name = _packet.guest_name;
                        global.loc_network_host_leader = _packet.host_leader;
                        global.loc_network_guest_leader = _packet.guest_leader;
                        network_prepare_match_restart(
                            "client",
                            net_socket,
                            -1,
                            _packet.seed
                        );
                    }
                    break;

                case "command_request":
                    if (net_role == "host"
                    && network_expected_player() == 1) {
                        net_command_sequence += 1;
                        _packet.type = "command_commit";
                        _packet.sequence = net_command_sequence;
                        network_send_message(net_peer_socket, _packet);
                        network_execute_input(_packet);
                        show_debug_message(
                            "[NET] Committed guest command "
                            + string(net_command_sequence) + "."
                        );
                    } else if (net_role == "host") {
                        show_debug_message(
                            "[NET] Rejected guest command outside guest priority."
                        );
                    }
                    break;

                case "command_commit":
                    if (net_role == "client"
                    && _packet.sequence == net_last_applied_sequence + 1) {
                        net_last_applied_sequence = _packet.sequence;
                        network_execute_input(_packet);
                        show_debug_message(
                            "[NET] Applied command "
                            + string(_packet.sequence) + "."
                        );
                    }
                    break;

                case "chat_message":
                    if (!network_lobby_active
                    && game_state.game_mode == "network"
                    && variable_struct_exists(_packet, "message")) {
                        append_chat_message(
                            1 - network_local_player,
                            _packet.message
                        );
                    }
                    break;
            }
        }
        break;

    case network_type_disconnect:
        net_status = "The other player disconnected.";
        show_debug_message("[NET] Peer disconnected.");
        break;
}
