#include <metal_stdlib>
using namespace metal;

struct U {
    float4 view; // width (pt), height (pt), px per pt, seed
    float4 a;
    float4 b;
    float4 c;
};

// ---- noise, the same functions the app's shader uses, so peel halo and wallpaper agree
float hash12(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}
float2 hash22(float2 p) {
    float3 p3 = fract(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}
float vnoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash12(i), b = hash12(i + float2(1, 0)), c = hash12(i + float2(0, 1)), d = hash12(i + float2(1, 1));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float fbm(float2 p, int octaves) {
    float sum = 0.0, amp = 0.5, norm = 0.0;
    const float2x2 rot = float2x2(1.6, 1.2, -1.2, 1.6);
    for (int i = 0; i < octaves; i++) { sum += amp * vnoise(p); norm += amp; p = rot * p + 17.3; amp *= 0.5; }
    return sum / norm;
}
float2 voronoi(float2 p) {
    float2 n = floor(p), f = fract(p);
    float md = 8.0, id = 0.0;
    for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
        float2 g = float2(i, j); float2 o = hash22(n + g); float2 r = g + o - f; float d = dot(r, r);
        if (d < md) { md = d; id = hash12(n + g + 17.0); }
    }
    return float2(sqrt(md), id);
}

// ---- extras
// Quintic gradient noise, roughly -1..1: smoother than value noise, no grid-aligned creases.
float2 grad2(float2 i) { float a = hash12(i) * 6.2831853; return float2(cos(a), sin(a)); }
float gnoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float a = dot(grad2(i), f), b = dot(grad2(i + float2(1, 0)), f - float2(1, 0));
    float c = dot(grad2(i + float2(0, 1)), f - float2(0, 1)), d = dot(grad2(i + float2(1, 1)), f - float2(1, 1));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 1.414;
}
float gfbm(float2 p, int octaves) {
    float sum = 0.0, amp = 0.5, norm = 0.0;
    const float2x2 rot = float2x2(1.6, 1.2, -1.2, 1.6);
    for (int i = 0; i < octaves; i++) { sum += amp * gnoise(p); norm += amp; p = rot * p + 17.3; amp *= 0.5; }
    return sum / norm;
}
// Worley with jitter control: x = F1, y = F2, z = cell id, w = jittered cell radius factor
float4 worley(float2 p, float jitter) {
    float2 n = floor(p), f = fract(p);
    float f1 = 8.0, f2 = 8.0, id = 0.0;
    for (int j = -2; j <= 2; j++) for (int i = -2; i <= 2; i++) {
        float2 g = float2(i, j);
        float2 o = 0.5 + (hash22(n + g + 3.7) - 0.5) * jitter;
        float d = length(g + o - f);
        if (d < f1) { f2 = f1; f1 = d; id = hash12(n + g + 71.0); } else if (d < f2) { f2 = d; }
    }
    return float4(f1, f2, id, 0.0);
}
float3 srgb2lin(float3 c) { return pow(max(c, 0.0), 2.2); }
float3 lin2srgb(float3 c) { return pow(max(c, 0.0), 1.0 / 2.2); }
float3 hexc(uint h) { return float3((h >> 16) & 255, (h >> 8) & 255, h & 255) / 255.0; }
float luma(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
float3 overlayBlend(float3 a, float3 b) { return select(1.0 - 2.0 * (1.0 - a) * (1.0 - b), 2.0 * a * b, a < 0.5); }

float4 shade(float2 p, constant U &u, texture2d<float> t1);

// 4x rotated-grid supersampling: the high-frequency peel detail stays crisp without shimmering.
kernel void bg(texture2d<float, access::write> out [[texture(0)]], texture2d<float> t1 [[texture(1)]], constant U &u [[buffer(0)]],
               uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= out.get_width() || gid.y >= out.get_height()) return;
    const float2 offs[4] = { float2(0.375, 0.125), float2(0.875, 0.375), float2(0.125, 0.625), float2(0.625, 0.875) };
    float4 acc = 0.0;
    for (int k = 0; k < 4; k++) {
        float4 c = shade((float2(gid) + offs[k]) / u.view.z, u, t1);
        acc += float4(c.rgb * c.a, c.a);
    }
    acc /= 4.0;
    out.write(float4(acc.a > 0.0 ? acc.rgb / acc.a : float3(0.0), acc.a), gid);
}

// Smooth F1 (log-sum-exp over neighbours): no creases where cells meet.
float sworley(float2 p, float jitter, float k) {
    float2 n = floor(p), f = fract(p);
    float s = 0.0;
    for (int j = -2; j <= 2; j++) for (int i = -2; i <= 2; i++) {
        float2 g = float2(i, j);
        float2 o = 0.5 + (hash22(n + g + 3.7) - 0.5) * jitter;
        s += exp(-k * length(g + o - f));
    }
    return -log(s) / k;
}
