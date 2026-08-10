function loc_developer_ui() {
    settings_ui_color_names = [
        "CYAN", "GREEN", "PURPLE", "AMBER", "WHITE", "RED", "BLUE", "AUTO"
    ];
    settings_default_center_far = false;
    settings_default_camera_locked = false;
    settings_ui_color_index = 0;
    settings_opponent_ui_color_index = 5;
    settings_saved_player_name = "Player 1";
    settings_saved_player_two_name = "Player 2";
    settings_debug_mode = false;
    settings_context_help = true;
    settings_first_game_guidance = true;
    settings_menu_active = false;

    save_persistent_settings = function() {
        settings_saved_player_name = net_player_name;
        ini_open("loc_settings.ini");
        ini_write_real("camera", "center_far", settings_default_center_far);
        ini_write_real("camera", "locked", settings_default_camera_locked);
        ini_write_real("ui", "color_index", settings_ui_color_index);
        ini_write_real("ui", "opponent_color_index",
            settings_opponent_ui_color_index);
        ini_write_real("debug", "enabled", settings_debug_mode);
        ini_write_real("help", "contextual", settings_context_help);
        ini_write_real("help", "first_game", settings_first_game_guidance);
        ini_write_string("player", "name", net_player_name);
        ini_write_string("player", "name_two", title_player_two_name);
        ini_close();
    };

    load_persistent_settings = function() {
        ini_open("loc_settings.ini");
        settings_default_center_far = ini_read_real(
            "camera", "center_far", 0
        ) >= 1;
        settings_default_camera_locked = ini_read_real(
            "camera", "locked", 0
        ) >= 1;
        settings_ui_color_index = clamp(floor(ini_read_real(
            "ui", "color_index", 0
        )), 0, array_length(settings_ui_color_names) - 1);
        settings_opponent_ui_color_index = clamp(floor(ini_read_real(
            "ui", "opponent_color_index", 5
        )), 0, array_length(settings_ui_color_names) - 1);
        settings_debug_mode = ini_read_real("debug", "enabled", 0) >= 1;
        settings_context_help = ini_read_real("help", "contextual", 1) >= 1;
        settings_first_game_guidance = ini_read_real(
            "help", "first_game", 1
        ) >= 1;
        settings_saved_player_name = ini_read_string(
            "player", "name", "Player 1"
        );
        settings_saved_player_two_name = ini_read_string(
            "player", "name_two", "Player 2"
        );
        ini_close();
    };
    load_persistent_settings();
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
    board_camera_center_far = settings_default_center_far;
    board_camera_locked = settings_default_camera_locked;
    board_camera_last_auto_focus = "";
    board_camera_recenter_requested = false;
    last_hand_click_instance_id = -1;
    last_hand_click_time = -1000;
    pending_choice = undefined;
    raid_suspended_choice = undefined;
    containment_resolution = undefined;
    special_containment_sequence = undefined;
    pending_ability_source_kind = "";
    pending_ability_source_index = -1;
    test_tools_open = false;
    test_tools_tab = "game";
    test_animation_page = 0;
    pause_screen_open = false;
    pause_options_open = false;
    help_page_open = false;
    help_return_context = "title";
    help_selected_index = 0;
    help_scroll = 0;
    help_scroll_max = 0;
    help_topics = [
        {
            title: "OVERVIEW",
            summary: "Build your forces, contain Metroids, and finish with more Research than your opponent. Cards in your hand create Characters, Ships, Locations, Attachments, and Events. Your board generates the Security, Strength, and effects needed to control the match.\n\nThe central Shop is shared. SR388 and the Cavern hold uncontrolled Metroids. Captured Metroids ride on Ships; at the start of their controller's turn they move into that player's Lab. Metroids in a Lab provide Research but also make containment more dangerous.\n\nWatch the phase and active-player readouts at the top of the screen. When the game needs a specific decision, the ACTION REQUIRED prompt replaces ordinary free-form play until that choice is complete."
        },
        {
            title: "TURN STRUCTURE",
            summary: "A turn moves through automatic opening steps, the Action phase, Containment, and any resulting Breaches before passing to the opponent.\n\nAt turn start, captured Metroids move from your Ships into your Lab and your resources are prepared. During the Action phase you may play cards and take actions in any order while you can pay their costs. End Turn moves play into Containment.\n\nContainment compares your available Security with the Hazard in your Lab. If containment fails, Metroids breach one at a time and resolve their consequences. Once every required choice and breach is resolved, the next player begins. The top-center prompt tells you whenever progression is waiting on you rather than happening automatically."
        },
        {
            title: "CARDS / ZONES",
            summary: "Your hand contains cards available to play. Characters, Ships, Locations, and Attachments normally remain on your board after deployment; Events resolve once and leave play. Your deck supplies new cards, and your discard pile is shuffled into a new deck when needed.\n\nThe shared Shop offers five cards. Reserve places a Shop card into your discard pile for later use. Deploy pays the card's CP cost and puts a permanent directly into play. Refreshing the Shop discards all five offers and replaces them.\n\nReady cards can act or pay exhaustion costs. Exhausted cards are unavailable until readied. Discard sends a card to its owner's discard pile; destroy and salvage also remove permanents from the board, but may trigger different rules."
        },
        {
            title: "CP / ACTIONS",
            summary: "Command Points, or CP, pay for most actions. Your current CP is shown in the HUD. Costs are paid immediately, and an action cannot begin if you cannot afford it.\n\nReserve acquires a Shop card for its Reserve cost. Deploy pays a Shop card's Deploy cost and puts it directly onto your board. Capture costs 1 CP and exhausts a Ship. Raid costs 2 CP and uses one of your ready Ships to attack. Refresh Hand costs 1 CP and replaces selected cards; Refresh Shop costs 1 CP and replaces the market.\n\nSalvage discards one of your ready permanents and grants half its printed Reserve cost, rounded down. Activated card abilities state their own costs. Hover an action for its exact effect; unavailable actions include a short reason such as not enough CP or no valid targets."
        },
        {
            title: "CAPTURE",
            summary: "Capture pays 1 CP and exhausts one of your ready Ships. Choose an uncontrolled Metroid on SR388 or in the Cavern whose Hazard is lower than that Ship's Security. The Metroid moves onto the Ship as cargo.\n\nA Ship normally carries one Metroid unless an effect increases its capacity. Capture eligibility is checked per target, so a Capture button may be available even when a particular Metroid is too hazardous for the selected Ship. Hovering that target reports not enough Security.\n\nCaptured Metroids are not Research yet. At the start of the Ship controller's next turn, they move into that player's Lab. Protect loaded Ships: an opponent who wins a Raid may steal their cargo."
        },
        {
            title: "CONTAINMENT",
            summary: "Containment happens after the Action phase. Add the Security supplied by your eligible board and the ready Ship you choose to contribute, then compare it with the total Hazard of Metroids in your Lab. A contributing Ship exhausts.\n\nIf Security meets or exceeds Hazard, containment succeeds. If it does not, Metroids breach sequentially. Each breach can discard cards, advance Mutation, or create another choice before the next breach begins.\n\nThe ACTION REQUIRED prompt identifies the Ship contribution or breach decision currently needed. Security and Hazard values shown during targeting are the exact comparison being made; effects that change either value can change which choice is safest."
        },
        {
            title: "RAIDS",
            summary: "Raid pays 2 CP and selects one of your ready Ships to attack an opposing Ship. The attacker and defender begin with their Ships' Strength, then may contribute eligible Characters. The attacker commits first; the defender responds afterward. Contributing cards exhaust.\n\nBoth sides may use eligible Raid abilities before resolution. The raid display shows the currently known Attack and Defense totals. The higher total wins; a tie destroys both Ships.\n\nWhen the attacker wins, it may capture a Metroid carried by the defending Ship if capacity permits. If cargo cannot be taken, follow the prompted overflow choice. Raiding can therefore steal Research in transit, force valuable defenders to exhaust, or remove an important Ship even when no cargo is present."
        },
        {
            title: "METROIDS",
            summary: "Metroids progress through Larva, Alpha, Gamma, Zeta, and Omega. Evolution replaces the current stage with the next stage, increasing its Hazard and usually its Research value. Hunter Metroids and special events may follow additional rules shown by their prompts.\n\nThe Mutation track records how dangerous the ecosystem has become. Creating a Zeta advances Mutation once. Creating an Omega advances it once at low Mutation and twice once Mutation is already 4 or higher. Mutation cannot exceed 8.\n\nReaching Mutation 8 ends the game immediately. This threat is shared: either player's evolutions can push the track toward the ending, so check the track before accepting a risky containment failure."
        },
        {
            title: "RESEARCH",
            summary: "Metroids in your Lab contribute their printed Research values. Research is scored at the end of the game, not when a Metroid first enters the Lab. Effects and breaches can still change the final contents of each Lab.\n\nMutation reaching 8 ends the game immediately. A player reaching 10 Metroids in their Lab or the match reaching turn 50 starts a final round instead: the current player finishes, the opponent receives one final turn, and then Research is compared.\n\nThe player with more Research wins. The end report summarizes captures, raids, breaches, evolutions, and the Research contribution of each Metroid stage so you can see how the result was produced."
        },
        {
            title: "FACTIONS",
            summary: "GF is Galactic Federation, SP is Space Pirate, CZ is Chozo, BH is Bounty Hunter, PZ is Phazon, and NA is Neutral. Factions do not restrict which cards you may acquire; matching factions mainly create synergies between effects.\n\nREADY means a permanent can act. EXHAUST turns it sideways or marks it unavailable as a cost. ATTACH places one card beneath a host and gives that host the attachment's effects. HAZARD is the containment or capture difficulty of a Metroid. SECURITY opposes Hazard. STRENGTH is used in Raids.\n\nPhazon tokens represent corruption. When most cards exhaust with at least three Phazon, they are discarded after paying the cost, although the paid effect still resolves. Card-specific exceptions and exact targeting requirements appear in contextual hover help."
        }
    ];
    guidance_active = undefined;
    guidance_queue = [];
    guidance_queued = {};
    guidance_last_lab_count = [0, 0];
    guidance_final_round_observed = false;

    guidance_is_local_player = function(_player_index) {
        if (game_state.game_mode == "regression") return false;
        if (_player_index < 0 || _player_index >= array_length(game_state.players)) {
            return false;
        }
        if (game_state.game_mode == "network") {
            return _player_index == network_local_player;
        }
        if (game_state.game_mode == "hotseat") {
            return true;
        }
        return _player_index == game_state.view_player
            && !game_state.players[_player_index].is_ai;
    };

    guidance_has_seen = function(_id) {
        ini_open("loc_settings.ini");
        var _seen = ini_read_real("guidance_seen", _id, 0) >= 1;
        ini_close();
        return _seen;
    };

    queue_first_game_guidance = function(_id, _title, _body) {
        if (!settings_first_game_guidance
        || title_menu_active
        || game_state.game_mode == ""
        || game_state.game_mode == "batch"
        || game_state.game_mode == "regression"
        || game_state.game_mode == "ai_watch"
        || variable_struct_exists(guidance_queued, _id)) {
            return false;
        }
        if (guidance_has_seen(_id)) {
            variable_struct_set(guidance_queued, _id, true);
            return false;
        }
        variable_struct_set(guidance_queued, _id, true);
        array_push(guidance_queue, {
            id: _id,
            title: _title,
            body: _body,
            persistent: true,
            allow_disable: true
        });
        return true;
    };

    queue_blocking_notice = function(_title, _body) {
        if (game_state.game_mode == "regression") return false;
        array_push(guidance_queue, {
            id: "",
            title: _title,
            body: _body,
            persistent: false,
            allow_disable: false
        });
        return true;
    };

    dismiss_first_game_guidance = function(_disable_all) {
        if (!is_undefined(guidance_active)
        && (!variable_struct_exists(guidance_active, "persistent")
            || guidance_active.persistent)) {
            ini_open("loc_settings.ini");
            ini_write_real("guidance_seen", guidance_active.id, 1);
            ini_close();
        }
        guidance_active = undefined;
        if (_disable_all) {
            settings_first_game_guidance = false;
            guidance_queue = [];
            save_persistent_settings();
        }
        return true;
    };

    restore_first_game_guidance = function() {
        ini_open("loc_settings.ini");
        ini_section_delete("guidance_seen");
        ini_close();
        settings_first_game_guidance = true;
        guidance_active = undefined;
        guidance_queue = [];
        guidance_queued = {};
        save_persistent_settings();
        return true;
    };
    debug_headless_to_game_over_active = false;
    debug_headless_original_mode = "";
    debug_headless_original_ai = [false, false];
    debug_headless_steps = 0;
    debug_headless_last_signature = "";
    debug_headless_same_state_steps = 0;
    end_counter_tint_surface = -1;
    end_screen_preview = undefined;
    end_report_page = 0;
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
    net_leader_id = "bsl_researcher";
    net_player_name = settings_saved_player_name;
    title_player_two_name = settings_saved_player_two_name;
    global.loc_player_name = net_player_name;
    faction_starters_enabled = !variable_global_exists(
        "loc_faction_starters_enabled"
    ) || global.loc_faction_starters_enabled;
    title_leader_keys = [
        "random",
        "bsl_researcher",
        "adam_malkovich",
        "mother_brain",
        "quiet_robe",
        "raven_beak"
    ];
    title_leader_names = [
        "Random",
        "B.S.L. Researcher",
        "Adam Malkovich",
        "Mother Brain",
        "Quiet Robe",
        "Raven Beak"
    ];
    title_leader_button_names = [
        "RANDOM",
        "B.S.L.",
        "ADAM",
        "MOTHER BRAIN",
        "QUIET ROBE",
        "RAVEN BEAK"
    ];
    title_leader_p1_index = variable_global_exists("loc_leader_p1_index")
        ? clamp(global.loc_leader_p1_index, 0, array_length(title_leader_keys) - 1)
        : 0;
    title_leader_p2_index = variable_global_exists("loc_leader_p2_index")
        ? clamp(global.loc_leader_p2_index, 0, array_length(title_leader_keys) - 1)
        : 0;
    title_name_editing = 0;
    title_context_mode = "ai";
    batch_menu_active = false;
    if (variable_global_exists("loc_batch_show_results")
    && global.loc_batch_show_results) {
        batch_menu_active = true;
    }
    batch_profile_options = ["", "GF", "SP", "CZ"];
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
    batch_report_page = 0;
    net_join_field = "";
    network_local_player = 0;
    net_command_sequence = 0;
    net_last_applied_sequence = 0;
    ai_next_step_time = 0;
    ai_action_delay = 420;
    ai_last_action = "";
    ai_salvage_goal_instance_id = -1;
    ai_salvage_goal_mode = "";
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
        apply_leader_identity(
            game_state.players[0],
            global.loc_network_host_leader
        );
        apply_leader_identity(
            game_state.players[1],
            global.loc_network_guest_leader
        );
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
}

