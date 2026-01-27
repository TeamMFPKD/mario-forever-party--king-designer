shader_type canvas_item;

uniform float radius = 150.0;
uniform float softness = 2.0;

void fragment() {
    vec2 texture_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 xy = UV * texture_size;
    vec2 center = texture_size * 0.5;
    
    float distance_to_center = length(center - xy);
    float alpha = distance_to_center / radius;
    
    alpha = clamp(alpha, 0.0, 1.0);
    
    COLOR.a = smoothstep(radius, radius - softness, distance_to_center);
}