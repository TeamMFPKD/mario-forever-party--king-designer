shader_type canvas_item;

uniform bool enabled = true;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    
    if (enabled) {
        COLOR = vec4(1.0 - color.rgb, color.a);
    } else {
        COLOR = color;
    }
}