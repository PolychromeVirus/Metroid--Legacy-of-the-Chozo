/// @description Load the generated card database and prepare a visual smoke test.

// Shared identity palette. Keep faction-facing UI colors centralized here so
// nameplates, reports, and future faction presentation stay synchronized.
// BSL/neutral presentation is deliberately near-white. Its panels inherit a
// restrained gray tint while enabled borders and text remain visibly brighter
// than the muted treatment used for disabled controls.
#macro LOC_COLOR_NEUTRAL make_color_rgb(236, 241, 245)
#macro LOC_COLOR_GF make_color_rgb(84, 229, 242)
#macro LOC_COLOR_SP make_color_rgb(255, 99, 110)
#macro LOC_COLOR_CZ make_color_rgb(255, 220, 70)
#macro LOC_COLOR_BH make_color_rgb(38, 255, 24)
#macro LOC_COLOR_PZ make_color_rgb(70, 104, 210)

loc_bootstrap_data();
loc_bootstrap_state();
loc_rules();
loc_actions();
loc_abilities();
loc_raids();
loc_modes_testing();
loc_batch();
loc_network();
loc_ai();
loc_regression();
loc_developer_ui();
