shader_type canvas_item;

uniform vec2 iResolution;
uniform float iTime;

#define PI 3.141592

float rand1(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

vec2 scale(vec2 p, float f) {
    mat2 m = mat2(vec2(1.0/f, 0.0), vec2(0.0, 1.0/f));
    return m * p;
}

vec2 rotate(vec2 p, float a) {
    float c = cos(a);
    float s = sin(a);
    mat2 m = mat2(vec2(c, -s), vec2(s, c));
    return m * p;
}

float sdfStar5(in vec2 p) {
    const vec2 k1 = vec2(0.809016994375, -0.587785252292);
    const vec2 k2 = vec2(-k1.x, k1.y);
    p.x = abs(p.x);
    p -= 2.0 * max(dot(k1, p), 0.0) * k1;
    p -= 2.0 * max(dot(k2, p), 0.0) * k2;
    const vec2 k3 = vec2(0.951056516295, 0.309016994375);
    return dot(vec2(abs(p.x) - 0.3, p.y), k3);
}

float SmoothSquareWave(float a, float blur) {
    a = a - floor(a);
    if (a <= 0.25) return smoothstep(-blur, blur, a);
    if (a >= 0.75) return smoothstep(1.0 - blur, 1.0 + blur, a);
    return 1.0 - smoothstep(0.5 - blur, 0.5 + blur, a);
}

#define BLACK vec3(0.0, 0.0, 0.0)
#define RED vec3(0.85, 0.137, 0.137)

void fragment() {
    vec2 fit = (FRAGCOORD.xy - 0.5 * iResolution.xy) / min(iResolution.x, iResolution.y);
    float ratioX = iResolution.x / min(iResolution.x, iResolution.y);
    float ratioY = iResolution.y / min(iResolution.x, iResolution.y);
    float scroll = iTime * 0.75 * ratioX;
    vec3 color = vec3(0.0);
    float totalAlpha = 0.0;

    for (float i = 0.0; i < 150.0; i++) {
        float offset = rand1(i) < 0.5 ? iTime : -iTime;
        float randX = (rand1(i + 66042.0) - 0.5) * ratioX;
        float randY = (rand1(i + 93472.0) - 0.5) * ratioY;

        // 原版 size 公式完全保留，自带放大出现、缩小消失
        float size = mix(0.0, clamp(rand1(i + 84.0), 0.05, 0.2) * ratioX,
                         pow(clamp(cos(abs(randX - scroll) - 1.0), 0.001, 1.0), 20.0));
        if (size < 0.01) continue;

        // 只屏蔽轴尚未到达的星：scroll 还没推进到 randX 时跳过
        if (randX > scroll) continue;

        float rot = rand1(i + 54634.0) * PI * 2.0;
        vec2 pos = fit - vec2(randX, randY);
        pos = rotate(pos, rot);
        pos = scale(pos, size);
        float star = sdfStar5(pos);
        float blur = fwidth(star);
        vec3 cur = mix(BLACK, RED, vec3(SmoothSquareWave(star * 9.0 - offset * 0.3, blur * 9.0)));
        float a = 1.0 - smoothstep(0.0, blur, star);
        color = mix(color, cur, a);
        totalAlpha = max(totalAlpha, a);
    }

    COLOR = vec4(color, totalAlpha);
}
