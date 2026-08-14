function loc_batch() {
    batch_profile_label = function(_profile) {
        return _profile == "" ? "NA" : _profile;
    };

    batch_profile_faction = function(_profile) {
        return (_profile == "CZT" || _profile == "CZM")
            ? "CZ" : _profile;
    };

    batch_array_total = function(_values) {
        var _total = 0;
        for (var _value_index = 0;
             _value_index < array_length(_values);
             _value_index++) {
            _total += _values[_value_index];
        }
        return _total;
    };

    batch_count_owned_faction = function(_player, _faction) {
        _faction = batch_profile_faction(_faction);
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

    batch_player_telemetry_snapshot = function(_player) {
        var _metroid_ids = [
            "metroid.larva",
            "metroid.alpha",
            "metroid.gamma",
            "metroid.zeta",
            "metroid.omega",
            "metroid.hunter"
        ];
        var _metroid_counts = [0, 0, 0, 0, 0, 0];
        var _metroid_research = [0, 0, 0, 0, 0, 0];
        for (var _lab_index = 0;
             _lab_index < array_length(_player.lab);
             _lab_index++) {
            var _metroid = _player.lab[_lab_index];
            for (var _stage_index = 0; _stage_index < 6; _stage_index++) {
                if (_metroid.definition_id == _metroid_ids[_stage_index]) {
                    _metroid_counts[_stage_index] += 1;
                    _metroid_research[_stage_index] +=
                        _metroid.definition.research_value;
                    break;
                }
            }
        }
        var _most_taken_id = "";
        var _most_taken_count = 0;
        for (var _take_index = 0;
             _take_index < array_length(_player.telemetry.card_take_ids);
             _take_index++) {
            if (_player.telemetry.card_take_counts[_take_index]
            > _most_taken_count) {
                _most_taken_count =
                    _player.telemetry.card_take_counts[_take_index];
                _most_taken_id = _player.telemetry.card_take_ids[_take_index];
            }
        }
        var _take_ids = [];
        var _take_counts = [];
        for (var _copy_index = 0;
             _copy_index < array_length(_player.telemetry.card_take_ids);
             _copy_index++) {
            array_push(
                _take_ids,
                _player.telemetry.card_take_ids[_copy_index]
            );
            array_push(
                _take_counts,
                _player.telemetry.card_take_counts[_copy_index]
            );
        }
        return {
            max_cp: max(_player.telemetry.max_cp, _player.command_points),
            captures: _player.telemetry.captures,
            raids_started: _player.telemetry.raids_started,
            raids_won: _player.telemetry.raids_won,
            raids_lost: _player.telemetry.raids_lost,
            raid_ties: _player.telemetry.raid_ties,
            breaches: _player.telemetry.breaches,
            metroid_counts: _metroid_counts,
            metroid_research: _metroid_research,
            most_taken_id: _most_taken_id,
            most_taken_count: _most_taken_count,
            card_take_ids: _take_ids,
            card_take_counts: _take_counts
        };
    };

    batch_build_profile_report = function(_batch, _profile) {
        var _profiles = ["", "GF", "SP", "CZT", "CZM"];
        var _report = {
            profile: _profile,
            games: 0,
            wins: 0,
            losses: 0,
            draws: 0,
            research: 0,
            max_cp: 0,
            captures: 0,
            raids: 0,
            raid_wins: 0,
            breaches: 0,
            metroids: 0,
            metroid_research: [0, 0, 0, 0, 0, 0],
            opponent_games: array_create(array_length(_profiles), 0),
            opponent_wins: array_create(array_length(_profiles), 0),
            opponent_points: array_create(array_length(_profiles), 0),
            card_ids: [],
            card_counts: [],
            top_card_id: "",
            top_card_count: 0
        };
        for (var _result_index = 0;
             _result_index < array_length(_batch.results);
             _result_index++) {
            var _result = _batch.results[_result_index];
            if (!_result.valid) continue;
            for (var _seat = 1; _seat <= 2; _seat++) {
            var _seat_profile = _seat == 1
                ? _result.p1_profile : _result.p2_profile;
            if (_seat_profile != _profile) continue;
            var _stats = _seat == 1 ? _result.p1_stats : _result.p2_stats;
            var _opponent = _seat == 1
                ? _result.p2_profile : _result.p1_profile;
            _report.games += 1;
            if (_result.winner == 0) {
                _report.draws += 1;
            } else if (_result.winner == _seat) {
                _report.wins += 1;
            } else {
                _report.losses += 1;
            }
            _report.research += _seat == 1
                ? _result.p1_research : _result.p2_research;
            _report.max_cp += _stats.max_cp;
            _report.captures += _stats.captures;
            _report.raids += _stats.raids_started;
            _report.raid_wins += _stats.raids_won;
            _report.breaches += _stats.breaches;
            _report.metroids += batch_array_total(_stats.metroid_counts);
            for (var _stage_index = 0; _stage_index < 6; _stage_index++) {
                _report.metroid_research[_stage_index] +=
                    _stats.metroid_research[_stage_index];
            }
            for (var _profile_index = 0;
                 _profile_index < array_length(_profiles);
                 _profile_index++) {
                if (_profiles[_profile_index] == _opponent) {
                    _report.opponent_games[_profile_index] += 1;
                    _report.opponent_wins[_profile_index] +=
                        _result.winner == _seat ? 1 : 0;
                    _report.opponent_points[_profile_index] +=
                        _result.winner == 0 ? 0.5
                            : (_result.winner == _seat ? 1 : 0);
                    break;
                }
            }
            for (var _take_index = 0;
                 _take_index < array_length(_stats.card_take_ids);
                 _take_index++) {
                var _take_id = _stats.card_take_ids[_take_index];
                var _found_take = false;
                for (var _card_index = 0;
                     _card_index < array_length(_report.card_ids);
                     _card_index++) {
                    if (_report.card_ids[_card_index] == _take_id) {
                        _report.card_counts[_card_index] +=
                            _stats.card_take_counts[_take_index];
                        _found_take = true;
                        break;
                    }
                }
                if (!_found_take) {
                    array_push(_report.card_ids, _take_id);
                    array_push(
                        _report.card_counts,
                        _stats.card_take_counts[_take_index]
                    );
                }
            }
            }
        }
        for (var _top_index = 0;
             _top_index < array_length(_report.card_ids);
             _top_index++) {
            if (_report.card_counts[_top_index] > _report.top_card_count) {
                _report.top_card_count = _report.card_counts[_top_index];
                _report.top_card_id = _report.card_ids[_top_index];
            }
        }
        return _report;
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
            starting_deck: _p1_deck,
            first_player: 1
        };
    };

    batch_checkpoint_filename = "loc_batch_checkpoint.json";

    batch_delete_checkpoint = function() {
        if (file_exists(batch_checkpoint_filename)) {
            file_delete(batch_checkpoint_filename);
        }
    };

    batch_write_checkpoint = function() {
        if (!variable_global_exists("loc_batch_state")) return false;
        var _checkpoint_file = file_text_open_write(
            batch_checkpoint_filename
        );
        if (_checkpoint_file < 0) return false;
        file_text_write_string(
            _checkpoint_file,
            json_stringify(global.loc_batch_state)
        );
        file_text_close(_checkpoint_file);
        return true;
    };

    batch_resume_checkpoint = function() {
        if (!file_exists(batch_checkpoint_filename)) return false;
        var _checkpoint_file = file_text_open_read(
            batch_checkpoint_filename
        );
        if (_checkpoint_file < 0) return false;
        var _checkpoint_text = "";
        while (!file_text_eof(_checkpoint_file)) {
            _checkpoint_text += file_text_read_string(_checkpoint_file);
            file_text_readln(_checkpoint_file);
        }
        file_text_close(_checkpoint_file);
        try {
            var _restored_batch = json_parse(_checkpoint_text);
            if (!variable_struct_exists(_restored_batch, "schedule")
            || !variable_struct_exists(_restored_batch, "results")
            || _restored_batch.completed >= _restored_batch.total_games) {
                return false;
            }
            global.loc_batch_state = _restored_batch;
            global.loc_batch_active = true;
            global.loc_batch_show_results = false;
            show_debug_message(
                "[BATCH] Resuming checkpoint at match "
                + string(_restored_batch.completed + 1) + "/"
                + string(_restored_batch.total_games) + "."
            );
            return batch_prepare_next_room();
        } catch (_checkpoint_error) {
            show_debug_message(
                "[BATCH] Could not resume checkpoint: "
                + string(_checkpoint_error)
            );
            return false;
        }
    };

    batch_identity_starter_id = function(_profile, _seed, _deck_key) {
        if (_profile == "CZT") return "loc.quiet_robe";
        if (_profile == "CZM") return "loc.raven_beak";
        return get_identity_starter_config(
            batch_profile_faction(_profile), undefined
        ).starter_id;
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
            + "faction_starters,focused_drafting,breaching_mutation,"
            + "loaded_ships_exhausted,"
            + "p1_starter,p2_starter,"
            + "p1_research,p2_research,p1_cp,p2_cp,p1_profile_cards,"
            + "valid,invalid_reason,replay_log,p2_profile_cards,"
            + "p1_owned_cards,p2_owned_cards,captures,"
            + "raids,breaches,evolutions,hand_refreshes,shop_refreshes,"
            + "p1_max_cp,p2_max_cp,p1_captures,p2_captures,"
            + "p1_raids,p2_raids,p1_raid_wins,p2_raid_wins,"
            + "p1_breaches,p2_breaches,p1_metroids,p2_metroids,"
            + "p1_metroid_research,p2_metroid_research,"
            + "p1_larva_rp,p1_alpha_rp,p1_gamma_rp,p1_zeta_rp,"
            + "p1_omega_rp,p1_hunter_rp,"
            + "p2_larva_rp,p2_alpha_rp,p2_gamma_rp,p2_zeta_rp,"
            + "p2_omega_rp,p2_hunter_rp,"
            + "p1_top_card,p1_top_card_count,p2_top_card,p2_top_card_count\n"
        );
        for (var _result_index = 0;
             _result_index < array_length(_batch.results);
             _result_index++) {
            var _result = _batch.results[_result_index];
            var _csv_row =
                string(_result.match_number) + ","
                + string(_result.pair_id) + ","
                + string(_result.leg) + ","
                + string(_result.seed) + ","
                + batch_profile_label(_result.deck_a_profile) + ","
                + batch_profile_label(_result.deck_b_profile) + ","
                + _result.p1_deck + ","
                + _result.p2_deck + ","
                + _result.starting_deck + ",";
            _csv_row +=
                _result.winner_deck + ","
                + string(_result.first_player) + ","
                + batch_profile_label(_result.p1_profile) + ","
                + batch_profile_label(_result.p2_profile) + ","
                + string(_result.winner) + ","
                + string(_result.turns) + ","
                + string(_result.mutation) + ","
                + string(_result.faction_starters) + ","
                + string(_result.focused_drafting) + ","
                + string(_result.breaching_mutation) + ","
                + string(_result.loaded_ships_exhausted) + ","
                + _result.p1_starter + ","
                + _result.p2_starter + ","
                + string(_result.p1_research) + ","
                + string(_result.p2_research) + ","
                + string(_result.p1_cp) + ","
                + string(_result.p2_cp) + ",";
            _csv_row +=
                string(_result.p1_profile_cards) + ","
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
                + string(_result.shop_refreshes) + ",";
            _csv_row +=
                string(_result.p1_stats.max_cp) + ","
                + string(_result.p2_stats.max_cp) + ","
                + string(_result.p1_stats.captures) + ","
                + string(_result.p2_stats.captures) + ","
                + string(_result.p1_stats.raids_started) + ","
                + string(_result.p2_stats.raids_started) + ","
                + string(_result.p1_stats.raids_won) + ","
                + string(_result.p2_stats.raids_won) + ","
                + string(_result.p1_stats.breaches) + ","
                + string(_result.p2_stats.breaches) + ",";
            _csv_row +=
                string(batch_array_total(
                    _result.p1_stats.metroid_counts
                )) + ","
                + string(batch_array_total(
                    _result.p2_stats.metroid_counts
                )) + ","
                + string(batch_array_total(
                    _result.p1_stats.metroid_research
                )) + ","
                + string(batch_array_total(
                    _result.p2_stats.metroid_research
                )) + ","
                + string(_result.p1_stats.metroid_research[0]) + ","
                + string(_result.p1_stats.metroid_research[1]) + ","
                + string(_result.p1_stats.metroid_research[2]) + ","
                + string(_result.p1_stats.metroid_research[3]) + ","
                + string(_result.p1_stats.metroid_research[4]) + ","
                + string(_result.p1_stats.metroid_research[5]) + ",";
            _csv_row +=
                string(_result.p2_stats.metroid_research[0]) + ","
                + string(_result.p2_stats.metroid_research[1]) + ","
                + string(_result.p2_stats.metroid_research[2]) + ","
                + string(_result.p2_stats.metroid_research[3]) + ","
                + string(_result.p2_stats.metroid_research[4]) + ","
                + string(_result.p2_stats.metroid_research[5]) + ","
                + _result.p1_stats.most_taken_id + ","
                + string(_result.p1_stats.most_taken_count) + ","
                + _result.p2_stats.most_taken_id + ","
                + string(_result.p2_stats.most_taken_count) + "\n";
            file_text_write_string(_file, _csv_row);
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
            + "Matrix filter: "
            + (variable_struct_exists(_batch, "matrix_filter")
                && _batch.matrix_filter != "ALL"
                ? batch_profile_label(_batch.matrix_filter) : "ALL") + "\n"
            + "Faction starters: "
            + (_batch.faction_starters_enabled ? "ENABLED" : "DISABLED")
            + " | Drafting: "
            + (_batch.focused_drafting ? "FOCUSED" : "ADAPTABLE")
            + " | Breaching Mutation: "
            + (_batch.breaching_mutation ? "ENABLED" : "DISABLED")
            + " | Loaded Ships Stay Exhausted: "
            + (_batch.loaded_ships_exhausted ? "ENABLED" : "DISABLED") + "\n"
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
                        for (var _other_index = 0;
                             _other_index < array_length(_batch.results);
                             _other_index++) {
                            var _other = _batch.results[_other_index];
                            if (_other.pair_id == _result.pair_id
                            && _other.leg == 2) {
                                _other_winner = _other.winner_deck;
                                break;
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
                    + ": first-player wins " + string(_a_p1_wins)
                    + " | second-player wins " + string(_a_p2_wins)
                    + " | paired sweeps " + string(_a_sweeps) + "\n"
                    + "  Deck B " + batch_profile_label(_matchup[1])
                    + ": first-player wins " + string(_b_p1_wins)
                    + " | second-player wins " + string(_b_p2_wins)
                    + " | paired sweeps " + string(_b_sweeps) + "\n"
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
        var _profiles = ["", "GF", "SP", "CZT", "CZM"];
        file_text_write_string(_file, "PROFILE TURN-ORDER RESULTS\n");
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
                    for (var _other_index = 0;
                         _other_index < array_length(_batch.results);
                         _other_index++) {
                        var _other = _batch.results[_other_index];
                        if (_other.pair_id == _result.pair_id
                        && _other.leg == 2) {
                            _other_winner = _other.winner_deck;
                            break;
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
                + ": first-player wins " + string(_slot1_wins)
                + " | second-player wins " + string(_slot2_wins)
                + " | total wins " + string(_slot1_wins + _slot2_wins)
                + " | paired sweeps " + string(_profile_sweeps) + "\n"
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
        var _profiles = ["", "GF", "SP", "CZT", "CZM"];
        var _matchups = [];
        var _matrix_filter = batch_matrix_filter_options[
            batch_matrix_filter_index
        ];
        if (_matrix_mode) {
            for (var _left = 0; _left < array_length(_profiles); _left++) {
                for (var _right = _left;
                     _right < array_length(_profiles);
                     _right++) {
                    if (_matrix_filter != "ALL"
                    && _profiles[_left] != _matrix_filter
                    && _profiles[_right] != _matrix_filter) {
                        continue;
                    }
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
        // Pair metadata is canonical and independent of execution order. This
        // keeps swapped-seat games on the same seed even though each leg runs
        // in a different Player 1 block.
        var _pair_records = [];
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
                var _deck_a_starter_id = batch_identity_starter_id(
                    _schedule_matchup[0], _schedule_seed, "A"
                );
                var _deck_b_starter_id = batch_identity_starter_id(
                    _schedule_matchup[1], _schedule_seed, "B"
                );
                array_push(_pair_records, {
                    pair_index: _schedule_pair_index,
                    pair_id: _schedule_pair_index + 1,
                    matchup_index: _schedule_matchup_index,
                    seed_index: _schedule_seed_index,
                    seed: _schedule_seed,
                    deck_a_profile: _schedule_matchup[0],
                    deck_b_profile: _schedule_matchup[1],
                    deck_a_starter_id: _deck_a_starter_id,
                    deck_b_starter_id: _deck_b_starter_id
                });
            }
        }
        // Execute top-to-bottom within each Player 1 column, then advance to
        // the next Player 1 profile. Checkpoints are written between columns.
        for (var _p1_profile_index = 0;
             _p1_profile_index < array_length(_profiles);
             _p1_profile_index++) {
            var _p1_profile = _profiles[_p1_profile_index];
            for (var _p2_profile_index = 0;
                 _p2_profile_index < array_length(_profiles);
                 _p2_profile_index++) {
                var _p2_profile = _profiles[_p2_profile_index];
                for (var _record_index = 0;
                     _record_index < array_length(_pair_records);
                     _record_index++) {
                    var _record = _pair_records[_record_index];
                    var _is_leg_one = _record.deck_a_profile == _p1_profile
                        && _record.deck_b_profile == _p2_profile;
                    var _is_leg_two = _record.deck_a_profile == _p2_profile
                        && _record.deck_b_profile == _p1_profile
                        && _record.deck_a_profile != _record.deck_b_profile;
                    if (!_is_leg_one && !_is_leg_two) continue;
                    array_push(_schedule, {
                        pair_index: _record.pair_index,
                        pair_id: _record.pair_id,
                        leg: _is_leg_one ? 1 : 2,
                        matchup_index: _record.matchup_index,
                        seed_index: _record.seed_index,
                        seed: _record.seed,
                        deck_a_profile: _record.deck_a_profile,
                        deck_b_profile: _record.deck_b_profile,
                        p1_deck: _is_leg_one ? "A" : "B",
                        p2_deck: _is_leg_one ? "B" : "A",
                        p1_profile: _p1_profile,
                        p2_profile: _p2_profile,
                        deck_a_starter_id: _record.deck_a_starter_id,
                        deck_b_starter_id: _record.deck_b_starter_id,
                        starting_deck: _is_leg_one ? "A" : "B",
                        first_player: 1
                    });
                }
            }
        }
        batch_delete_checkpoint();
        global.loc_batch_state = {
            mode: _matrix_mode ? "matrix" : "matchup",
            matrix_filter: _matrix_mode ? _matrix_filter : "ALL",
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
            focused_drafting: batch_focused_drafting,
            breaching_mutation: settings_experimental_breaching_mutation,
            loaded_ships_exhausted:
                settings_experimental_loaded_ships_exhausted,
            detailed_logs: batch_detailed_logs,
            replay_active: false,
            replay_index: -1,
            csv_path: working_directory
                + "loc_batch_" + _stamp + ".csv",
            summary_path: working_directory
                + "loc_batch_" + _stamp + "_summary.txt"
        };
        batch_write_results_csv();
        batch_write_checkpoint();
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
        game_state.players[0].favored_faction = batch_profile_faction(
            _schedule.p1_profile
        );
        game_state.players[1].favored_faction = batch_profile_faction(
            _schedule.p2_profile
        );
        game_state.players[0].name = "AI " + _schedule.p1_deck + " "
            + batch_profile_label(_schedule.p1_profile);
        game_state.players[1].name = "AI " + _schedule.p2_deck + " "
            + batch_profile_label(_schedule.p2_profile);
        faction_starters_enabled = variable_struct_exists(
            _batch,
            "faction_starters_enabled"
        ) ? _batch.faction_starters_enabled : false;
        settings_experimental_breaching_mutation = variable_struct_exists(
            _batch,
            "breaching_mutation"
        ) && _batch.breaching_mutation;
        settings_experimental_loaded_ships_exhausted = variable_struct_exists(
            _batch,
            "loaded_ships_exhausted"
        ) && _batch.loaded_ships_exhausted;
        var _deck_a_player = _schedule.p1_deck == "A"
            ? game_state.players[0]
            : game_state.players[1];
        var _deck_b_player = _schedule.p1_deck == "B"
            ? game_state.players[0]
            : game_state.players[1];
        // Bootstrap deals the neutral starters in seat order before the batch
        // identities are known. Rebuild canonical pools so even the NONE deck
        // does not inherit a different pre-shuffle ordering after seats swap.
        _deck_a_player.hand = [];
        _deck_a_player.deck = expand_card_pool(
            card_database.pools.starter,
            _deck_a_player.index,
            "deck"
        );
        _deck_b_player.hand = [];
        _deck_b_player.deck = expand_card_pool(
            card_database.pools.starter,
            _deck_b_player.index,
            "deck"
        );
        // Keep each persistent deck on the same RNG stream in both legs.
        // Seat-order initialization would give A and B different opening hands
        // after they swap, weakening paired-seed comparisons.
        apply_identity_starter(
            _deck_a_player,
            false,
            _schedule.deck_a_starter_id
        );
        apply_identity_starter(
            _deck_b_player,
            false,
            _schedule.deck_b_starter_id
        );
        var _focused_drafting = variable_struct_exists(
            _batch,
            "focused_drafting"
        ) && _batch.focused_drafting;
        game_state.players[0].favored_faction = _focused_drafting
            ? batch_profile_faction(_schedule.p1_profile) : "";
        game_state.players[1].favored_faction = _focused_drafting
            ? batch_profile_faction(_schedule.p2_profile) : "";
        game_state.active_player = _schedule.first_player - 1;
        game_state.priority_player = game_state.active_player;
        game_state.view_player = game_state.active_player;
        for (var _opening_event_index = 0;
             _opening_event_index < array_length(game_state.event_log);
             _opening_event_index++) {
            if (string_pos(
                "takes the first turn.",
                game_state.event_log[_opening_event_index]
            ) > 0) {
                game_state.event_log[_opening_event_index] =
                    game_state.players[game_state.active_player].name
                    + " takes the first turn.";
                break;
            }
        }
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
                batch_delete_checkpoint();
                global.loc_batch_active = false;
                global.loc_batch_last_summary = _batch.summary_path;
                global.loc_batch_show_results = true;
                room_restart();
                return true;
            }
            batch_write_checkpoint();
            return batch_prepare_next_room();
        }
        var _schedule = batch_get_schedule_info(_batch.completed);
        var _p0 = game_state.players[0];
        var _p1 = game_state.players[1];
        var _p0_stats = batch_player_telemetry_snapshot(_p0);
        var _p1_stats = batch_player_telemetry_snapshot(_p1);
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
                p1_profile: _schedule.p1_profile,
                p2_profile: _schedule.p2_profile,
                faction_starters: faction_starters_enabled,
                focused_drafting: _batch.focused_drafting,
                breaching_mutation: _batch.breaching_mutation,
                loaded_ships_exhausted: _batch.loaded_ships_exhausted,
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
                    _schedule.p1_profile
                ),
                valid: batch_match_invalid_reason == "",
                invalid_reason: batch_match_invalid_reason,
                replay_log: "",
                p2_profile_cards: batch_count_owned_faction(
                    _p1,
                    _schedule.p2_profile
                ),
                p1_owned_cards: batch_count_owned_cards(_p0),
                p2_owned_cards: batch_count_owned_cards(_p1),
                p1_stats: _p0_stats,
                p2_stats: _p1_stats,
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
            batch_delete_checkpoint();
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
        var _finished_schedule = _schedule;
        var _next_schedule = batch_get_schedule_info(_batch.completed);
        if (_finished_schedule.p1_profile != _next_schedule.p1_profile) {
            batch_write_checkpoint();
            show_debug_message(
                "[BATCH] Checkpoint saved after Player 1 "
                + batch_profile_label(_finished_schedule.p1_profile)
                + " block (" + string(_batch.completed) + "/"
                + string(_batch.total_games) + ")."
            );
        }
        return batch_prepare_next_room();
    };

}

