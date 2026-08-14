param(
    [Parameter(Mandatory=$true)][string]$CsvPath,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [int]$PairedSeeds = 100,
    [string[]]$CompletedP1Profiles = @('NA', 'GF')
)

$profiles = @('NA', 'GF', 'SP', 'CZT', 'CZM')
$internal = @{ NA=''; GF='GF'; SP='SP'; CZT='CZT'; CZM='CZM' }
$starter = @{
    NA='loc.armoured_frigate'; GF='loc.gf_marine'; SP='loc.zebesian_pirate'
    CZT='loc.quiet_robe'; CZM='loc.raven_beak'
}
$source = @(Import-Csv -LiteralPath $CsvPath)
if ($source.Count -eq 0) { throw 'Source CSV has no completed results.' }
$seedBase = [int64](($source | Measure-Object seed -Minimum).Minimum)

$matchups = @()
$records = @()
$pairIndex = 0
for ($left = 0; $left -lt $profiles.Count; $left++) {
    for ($right = $left; $right -lt $profiles.Count; $right++) {
        $a = $profiles[$left]; $b = $profiles[$right]
        $matchups += ,@($internal[$a], $internal[$b])
        for ($seedIndex = 0; $seedIndex -lt $PairedSeeds; $seedIndex++) {
            $records += [ordered]@{
                pair_index=$pairIndex; pair_id=$pairIndex + 1
                matchup_index=$matchups.Count - 1; seed_index=$seedIndex
                seed=$seedBase + $pairIndex
                deck_a_profile=$internal[$a]; deck_b_profile=$internal[$b]
                deck_a_starter_id=$starter[$a]; deck_b_starter_id=$starter[$b]
            }
            $pairIndex++
        }
    }
}

$schedule = @()
foreach ($p1 in $profiles) {
    foreach ($p2 in $profiles) {
        foreach ($record in $records) {
            $one = $record.deck_a_profile -eq $internal[$p1] -and
                $record.deck_b_profile -eq $internal[$p2]
            $two = $record.deck_a_profile -eq $internal[$p2] -and
                $record.deck_b_profile -eq $internal[$p1] -and
                $record.deck_a_profile -ne $record.deck_b_profile
            if (!$one -and !$two) { continue }
            $schedule += [ordered]@{
                pair_index=$record.pair_index; pair_id=$record.pair_id
                leg=if($one){1}else{2}; matchup_index=$record.matchup_index
                seed_index=$record.seed_index; seed=$record.seed
                deck_a_profile=$record.deck_a_profile
                deck_b_profile=$record.deck_b_profile
                p1_deck=if($one){'A'}else{'B'}; p2_deck=if($one){'B'}else{'A'}
                p1_profile=$internal[$p1]; p2_profile=$internal[$p2]
                deck_a_starter_id=$record.deck_a_starter_id
                deck_b_starter_id=$record.deck_b_starter_id
                starting_deck=if($one){'A'}else{'B'}; first_player=1
            }
        }
    }
}

$lookup = @{}
foreach ($row in $source) {
    $key = "$($row.p1_profile)|$($row.p2_profile)|$($row.seed)"
    $lookup[$key] = $row
}
function Num($value) { if ([string]::IsNullOrEmpty($value)) { return 0 }; return [double]$value }
function PlayerStats($row, $prefix) {
    $topId = $row."${prefix}_top_card"
    $topCount = [int](Num $row."${prefix}_top_card_count")
    return [ordered]@{
        max_cp=Num $row."${prefix}_max_cp"
        captures=Num $row."${prefix}_captures"
        raids_started=Num $row."${prefix}_raids"
        raids_won=Num $row."${prefix}_raid_wins"
        raids_lost=0; raid_ties=0
        breaches=Num $row."${prefix}_breaches"
        metroid_counts=@(0,0,0,0,0,0)
        metroid_research=@(
            (Num $row."${prefix}_larva_rp")
            (Num $row."${prefix}_alpha_rp")
            (Num $row."${prefix}_gamma_rp")
            (Num $row."${prefix}_zeta_rp")
            (Num $row."${prefix}_omega_rp")
            (Num $row."${prefix}_hunter_rp")
        )
        most_taken_id=$topId; most_taken_count=$topCount
        card_take_ids=if($topId){@($topId)}else{@()}
        card_take_counts=if($topId){@($topCount)}else{@()}
    }
}

$results = @()
for ($index = 0; $index -lt $schedule.Count; $index++) {
    $entry = $schedule[$index]
    $p1Label = if($entry.p1_profile -eq ''){'NA'}else{$entry.p1_profile}
    if ($CompletedP1Profiles -notcontains $p1Label) { break }
    $p2Label = if($entry.p2_profile -eq ''){'NA'}else{$entry.p2_profile}
    $key = "$p1Label|$p2Label|$($entry.seed)"
    if (!$lookup.ContainsKey($key)) { throw "Missing completed row for $key" }
    $row = $lookup[$key]
    $results += [ordered]@{
        match_number=$index + 1; pair_id=$entry.pair_id; leg=$entry.leg
        seed=Num $row.seed; deck_a_profile=$entry.deck_a_profile
        deck_b_profile=$entry.deck_b_profile; p1_deck=$entry.p1_deck
        p2_deck=$entry.p2_deck; starting_deck=$entry.starting_deck
        winner_deck=$row.winner_deck; first_player=1
        p1_profile=$entry.p1_profile; p2_profile=$entry.p2_profile
        faction_starters=[bool][int]$row.faction_starters
        focused_drafting=[bool][int]$row.focused_drafting
        breaching_mutation=[bool][int]$row.breaching_mutation
        loaded_ships_exhausted=[bool][int]$row.loaded_ships_exhausted
        p1_starter=$row.p1_starter; p2_starter=$row.p2_starter
        winner=Num $row.winner; turns=Num $row.turns; mutation=Num $row.mutation
        p1_research=Num $row.p1_research; p2_research=Num $row.p2_research
        p1_cp=Num $row.p1_cp; p2_cp=Num $row.p2_cp
        p1_profile_cards=Num $row.p1_profile_cards
        valid=[bool][int]$row.valid; invalid_reason=$row.invalid_reason
        replay_log=$row.replay_log; p2_profile_cards=Num $row.p2_profile_cards
        p1_owned_cards=Num $row.p1_owned_cards; p2_owned_cards=Num $row.p2_owned_cards
        p1_stats=PlayerStats $row 'p1'; p2_stats=PlayerStats $row 'p2'
        captures=Num $row.captures; raids=Num $row.raids
        breaches=Num $row.breaches; evolutions=Num $row.evolutions
        hand_refreshes=Num $row.hand_refreshes; shop_refreshes=Num $row.shop_refreshes
    }
}

$directory = Split-Path -Parent $CsvPath
$state = [ordered]@{
    mode='matrix'; matrix_filter='ALL'; matchups=$matchups; schedule=$schedule
    games_per_matchup=$PairedSeeds * 2; paired_seeds_per_matchup=$PairedSeeds
    total_pairs=$pairIndex; total_games=$schedule.Count; completed=$results.Count
    seed_base=$seedBase; results=$results; faction_starters_enabled=$true
    focused_drafting=$false; breaching_mutation=$true
    loaded_ships_exhausted=$true; detailed_logs=$true
    replay_active=$false; replay_index=-1
    csv_path=(Join-Path $directory 'loc_batch_20260813_114315.csv')
    summary_path=(Join-Path $directory 'loc_batch_20260813_114315_summary.txt')
}
$json = $state | ConvertTo-Json -Depth 12 -Compress
[System.IO.File]::WriteAllText(
    [System.IO.Path]::GetFullPath($OutputPath),
    $json,
    [System.Text.UTF8Encoding]::new($false)
)
Write-Output "Checkpoint created: $($results.Count)/$($schedule.Count) games; next P1 $($schedule[$results.Count].p1_profile)."
