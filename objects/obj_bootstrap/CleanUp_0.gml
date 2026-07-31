/// @description Release sprites created dynamically by the bootstrap loader.

var _sprite_keys = variable_struct_get_names(sprite_cache);
for (var _i = 0; _i < array_length(_sprite_keys); _i++) {
    var _sprite = variable_struct_get(sprite_cache, _sprite_keys[_i]);
    if (_sprite >= 0 && sprite_exists(_sprite)) {
        sprite_delete(_sprite);
    }
}

sprite_cache = {};
