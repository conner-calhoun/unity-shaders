// For splitting splat maps in custom terrain shaders (credit goes to adamgryu)
half4 SplitMap(half4 map) {
    map.r = step(0.1, map.r - map.g - map.b - map.a);
    map.g = step(0.1, map.g - map.r - map.b - map.a);
    map.b = step(0.1, map.b - map.g - map.r - map.a);
    map.a = step(0.1, map.a - map.g - map.b - map.r);

    return map;
}