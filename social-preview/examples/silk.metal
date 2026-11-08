// Citrus silk: a few large, slow folds sweeping diagonally, lit from the top-left like a macOS wallpaper.
float silkField(float2 p, float seed) {
    float2 d1 = normalize(float2(1.0, -0.62));
    float2 d2 = normalize(float2(1.0, -0.35));
    float w1 = gnoise(p / 820.0 + seed) * 2.4 + gnoise(p / 410.0 + seed + 3.1) * 0.6;
    float w2 = gnoise(p / 600.0 + seed + 7.7) * 2.0;
    float x1 = dot(p, d1), x2 = dot(p, d2);
    float h = 0.62 * sin(x1 * 6.2831 / 760.0 + w1)
            + 0.30 * sin(x2 * 6.2831 / 360.0 + w2 + 1.3)
            + 0.10 * sin(x1 * 6.2831 / 170.0 + w1 * 1.7 + w2);
    return h;
}

float4 shade(float2 p, constant U &u, texture2d<float> t1) {
    float2 uv = p / u.view.xy;
    float seed = u.view.w;
    const float e = 0.8;
    float h = silkField(p, seed);
    float hx = silkField(p + float2(e, 0), seed);
    float hy = silkField(p + float2(0, e), seed);
    float k = u.a.x > 0.0 ? u.a.x : 70.0; // fold depth (pt)
    float3 n = normalize(float3(-(hx - h) / e * k, -(hy - h) / e * k, 1.0));

    // Base: tangerine at the top-left, blood orange at the bottom-right; folds shift it lighter/darker.
    float g = saturate(dot(uv - float2(0.0, 0.0), normalize(float2(1.0, 0.9))) / 1.35);
    float3 alb = mix(hexc(0xFF9A2A), hexc(0xF26510), smoothstep(0.0, 0.55, g));
    alb = mix(alb, hexc(0xC7340C), smoothstep(0.45, 1.0, g));
    alb = mix(alb, alb * float3(1.0, 0.78, 0.80), smoothstep(0.5, 0.8, fbm(p / 420.0 + seed * 3.0, 3)) * 0.3); // grapefruit blush
    float3 A = srgb2lin(alb);

    const float3 L = normalize(float3(-0.55, -0.7, 0.85));
    float diff = saturate(dot(n, L));
    float3 lit = A * (0.30 + 0.92 * diff);
    // Satin sheen along the crests.
    float3 H = normalize(L + float3(0, 0, 1));
    lit += float3(1.0, 0.86, 0.62) * pow(saturate(dot(n, H)), 22.0) * 0.30;
    // Deep, saturated occlusion in the troughs.
    float trough = smoothstep(-0.2, -0.9, h);
    lit = mix(lit, lit * float3(0.72, 0.36, 0.26), trough * 0.45);
    float vig = smoothstep(0.45, 1.25, length((uv - 0.5) * float2(1.0, 1.1)));
    lit *= 1.0 - 0.38 * vig;
    return float4(lin2srgb(lit), 1.0);
}
