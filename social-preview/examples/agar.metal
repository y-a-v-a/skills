// A petri dish of amber agar on a dark bench. u.a = (centre x, centre y, radius, mode: 0 base, 1 lid overlay)
float4 shade(float2 p, constant U &u, texture2d<float> t1) {
    float2 uv = p / u.view.xy;
    float2 c = u.a.xy; float R = u.a.z; bool lid = u.a.w > 0.5;
    float2 d = p - c; float r = length(d); float2 dir = d / max(r, 1e-3);
    const float3 L = normalize(float3(-0.55, -0.7, 0.85));
    float facing = dot(dir, -L.xy / length(L.xy)); // 1 on the side towards the light (top-left)

    if (lid) {
        // Glass lid, slightly larger and nudged: rim glints, a broad softbox reflection, a few condensation beads.
        float2 lc = c + float2(-5.0, -4.0); float lr = length(p - lc); float Rl = R + 12.0;
        float4 o = float4(0.0);
        float rim = exp(-pow((lr - Rl) / 1.6, 2.0));
        float rimIn = exp(-pow((lr - (Rl - 7.0)) / 1.2, 2.0));
        float glint = smoothstep(-0.2, 0.9, facing);
        float a = rim * (0.30 + 0.70 * glint) + rimIn * (0.12 + 0.40 * glint);
        // Softbox reflection: a soft, slightly curved window on the upper left of the lid.
        float2 q = (p - (c + float2(-R * 0.36, -R * 0.42))) ;
        q = float2(q.x * 0.82 + q.y * 0.57, -q.x * 0.57 + q.y * 0.82);
        q.y += q.x * q.x / (R * 2.4);
        float box = (1.0 - smoothstep(0.0, 26.0, abs(q.y) - 34.0)) * (1.0 - smoothstep(0.0, 60.0, abs(q.x) - R * 0.28));
        box *= step(lr, Rl - 3.0);
        a = max(a, box * 0.15);
        // Condensation beads near the rim, sparse.
        float2 bp = p / 9.0;
        float4 wv = worley(bp, 1.0);
        float bead = fract(wv.z * 31.7) < 0.18 ? 1.0 : 0.0;
        float near = smoothstep(Rl - 90.0, Rl - 20.0, lr) * step(lr, Rl - 8.0) * smoothstep(0.62, 0.8, fbm(p / 70.0 + 4.0, 3));
        float br = mix(0.16, 0.34, fract(wv.z * 7.1));
        float beadA = (1.0 - smoothstep(br - 0.05, br, wv.x)) * bead * near;
        float beadHi = (1.0 - smoothstep(0.0, br * 0.45, length(bp - floor(bp) - 0.5 + float2(0.06, 0.06)) )) ;
        a = max(a, beadA * 0.22);
        a *= step(lr, Rl + 3.0);
        return float4(float3(1.0, 0.98, 0.94), saturate(a));
    }

    // Bench: very dark slate with a soft pool of light at the top-left and slow mottling.
    float pool = exp(-pow(length((uv - float2(0.2, 0.1)) * float2(1.0, 1.4)) / 0.75, 2.0));
    float mott = fbm(p / 160.0, 4);
    float3 bench = mix(hexc(0x0B0E12), hexc(0x1C2228), pool * 0.85) * (0.88 + 0.24 * mott);
    // Dish shadow: soft, offset away from the light.
    float sr = length(p - (c + float2(16.0, 22.0)));
    float shadow = 1.0 - smoothstep(R - 20.0, R + 46.0, sr);
    bench *= 1.0 - 0.6 * shadow;
    // Light caustic: amber glow thrown onto the bench past the shadow side.
    float caust = exp(-pow((sr - R - 18.0) / 22.0, 2.0)) * smoothstep(0.2, -0.8, facing);
    bench += hexc(0x6A3A10) * caust * 0.35;
    float3 col = bench;

    // Glass base wall.
    float wall = smoothstep(R + 1.0, R - 0.5, r) * smoothstep(R - 8.5, R - 6.0, r);
    float3 glass = mix(hexc(0x2B3236), hexc(0xE8EEF0), smoothstep(-0.3, 1.0, facing) * 0.75);
    // Agar disc.
    float Ra = R - 7.0;
    float inAgar = smoothstep(Ra + 0.8, Ra - 0.8, r);
    float t = r / Ra;
    float gel = fbm(p / 140.0 + 3.0, 3);
    float fine = fbm(p / 9.0, 3);
    float3 amberC = hexc(0xE7A642), amberE = hexc(0xA75A17), amberD = hexc(0x6E3510);
    float3 agar = mix(amberC, amberE, smoothstep(0.1, 1.0, t));
    agar = mix(agar, amberD, smoothstep(0.86, 1.0, t) * 0.6);
    agar *= 0.95 + 0.07 * gel + 0.015 * (fine - 0.5);
    // Light passing through: brighter towards the light side, a warm hot spot top-left of centre.
    float hot = exp(-pow(length(p - (c + float2(-R * 0.25, -R * 0.3))) / (R * 0.75), 2.0));
    agar *= 0.82 + 0.38 * hot;
    // Meniscus: agar climbs the wall, catching a bright line, then a darker refracted band.
    float men = exp(-pow((r - (Ra - 3.0)) / 2.2, 2.0));
    float band = exp(-pow((r - (Ra - 12.0)) / 6.0, 2.0));
    agar = mix(agar, agar * 0.72, band * 0.5);
    agar += float3(1.0, 0.86, 0.6) * men * (0.25 + 0.4 * smoothstep(-0.2, 1.0, facing));
    // A few trapped bubbles near the edge.
    float4 bw = worley(p / 26.0 + 11.0, 1.0);
    float isB = step(fract(bw.z * 17.3), 0.05) * smoothstep(0.78, 0.9, t);
    float bR = mix(0.07, 0.16, fract(bw.z * 5.3));
    float ring = exp(-pow((bw.x - bR) / 0.025, 2.0)) * isB;
    agar = mix(agar, float3(1.0, 0.92, 0.75), ring * 0.55);

    col = mix(col, glass, wall * 0.55);
    col = mix(col, agar, inAgar);
    return float4(col, 1.0);
}
