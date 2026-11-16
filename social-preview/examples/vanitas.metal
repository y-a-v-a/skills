// Vanitas: one mouldy orange on a stone ledge, chiaroscuro, aged varnish and craquelure.
// u.a = (sphere x, sphere y, radius, ledge back edge y); u.b = (ledge front edge y, mould map size pt, map offset y, map offset x)
// t1 (BG_TEX) is the mould map, wrapped onto the sphere in arc-length coordinates.
float peelH(float2 p) {
    float2 w = float2(gfbm(p / 50.0, 2), gfbm(p / 50.0 + 9.1, 2));
    float4 c1 = worley((p + w * 3.0) / 6.5, 0.85);
    float r1 = mix(0.26, 0.42, hash12(float2(c1.z * 91.0, 3.0)));
    float t1v = saturate(c1.x / r1);
    float pit = (1.0 - t1v * t1v) * (1.0 - t1v * t1v);
    return gfbm(p / 60.0, 3) * 1.5 - pit * 0.8;
}

float4 shade(float2 p, constant U &u, texture2d<float> t1) {
    constexpr sampler ls(filter::linear, address::clamp_to_zero);
    float2 size = u.view.xy, uv = p / size;
    float2 C = u.a.xy; float R = u.a.z; float yBack = u.a.w, yFront = u.b.x; float mapSize = u.b.y;
    const float3 L = normalize(float3(-0.80, -0.55, 0.36));

    // ---- wall: warm umber, lit from the upper left, with dragged-brush streaks
    float2 rp = float2(p.x * 0.8 + p.y * 0.6, -p.x * 0.6 + p.y * 0.8);
    float strokes = gfbm(rp * float2(1.0 / 160.0, 1.0 / 22.0), 4) * 0.5 + gfbm(rp * float2(1.0 / 60.0, 1.0 / 9.0) + 5.0, 3) * 0.25;
    float wallLight = exp(-pow(length((uv - float2(0.30, 0.22)) * float2(1.0, 1.25)) / 0.55, 2.0));
    float3 col = mix(hexc(0x090706), hexc(0x2E2219), wallLight);
    col *= 1.0 + strokes * 0.16;
    // the orange's glow on the wall behind (bounce)
    col += hexc(0x3A1A06) * exp(-pow(length(p - C) / (R * 1.9), 2.0)) * 0.35;

    // ---- stone ledge
    if (p.y > yBack) {
        float edgeN = (gfbm(float2(p.x / 70.0, 3.0), 3)) * 2.0 + (fbm(float2(p.x / 9.0, 1.0), 2) - 0.5) * 0.8;
        float front = yFront + edgeN;
        float stone = fbm(p / 30.0, 4), stoneF = fbm(p / 5.0, 3);
        if (p.y < front) {
            float depth = (p.y - yBack) / (yFront - yBack);
            float3 top = mix(hexc(0x15100C), hexc(0x3E3127), smoothstep(0.0, 1.0, depth));
            top *= 0.45 + 0.75 * exp(-pow((p.x / size.x - 0.42) / 0.42, 2.0));
            top *= 0.88 + 0.2 * stone + 0.06 * (stoneF - 0.5);
            col = top;
            // soft back edge where ledge meets the dark
            col = mix(col, hexc(0x0D0A08), (1.0 - smoothstep(0.0, 14.0, p.y - yBack)) * 0.8);
            // cast shadow of the orange, falling to the right along the ledge, plus a dark contact
            float2 sc = (p - float2(C.x + R * 0.55, C.y + R * 0.93)) / float2(R * 1.25, R * 0.16);
            float sh = 1.0 - smoothstep(0.35, 1.15, length(sc));
            float2 cc = (p - float2(C.x + 8.0, C.y + R * 0.985)) / float2(R * 0.62, R * 0.06);
            float contact = 1.0 - smoothstep(0.2, 1.0, length(cc));
            col *= 1.0 - 0.72 * sh;
            col *= 1.0 - 0.8 * contact;
            // warm reflected colour from the peel
            col += hexc(0x5A2205) * exp(-pow(length((p - float2(C.x - R * 0.2, C.y + R)) / float2(R * 0.9, R * 0.22)), 2.0)) * 0.45;
            // the lit front lip
            col += hexc(0x6A5643) * exp(-pow((p.y - front + 2.0) / 1.3, 2.0)) * 0.30 * (0.25 + 0.75 * exp(-pow((p.x / size.x - 0.4) / 0.45, 2.0)));
        } else {
            float3 face = mix(hexc(0x140F0C), hexc(0x080605), smoothstep(front, size.y, p.y));
            face *= 0.85 + 0.25 * stone + 0.08 * (stoneF - 0.5);
            face *= 0.6 + 0.55 * exp(-pow((p.x / size.x - 0.3) / 0.6, 2.0));
            col = face;
        }
    }

    // ---- the orange
    float2 d0 = (p - C) / R; float ang = atan2(d0.y, d0.x);
    float wob = 1.0 + 0.012 * sin(ang * 3.0 + 1.3) + 0.008 * sin(ang * 5.0 + 0.4) + 0.006 * gnoise(float2(ang * 2.0, 4.0));
    float2 d = float2(d0.x, d0.y / 0.955) / wob; float rr = dot(d, d);
    float aa = 1.5 / R;
    float cover = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, sqrt(rr));
    if (rr < 1.03) {
        float2 dd = d * min(1.0, 0.9995 / max(sqrt(rr), 1e-4));
        float z = sqrt(max(0.0, 1.0 - dot(dd, dd)));
        float3 N0 = float3(dd, z);
        float lon = atan2(N0.x, N0.z), lat = asin(clamp(N0.y, -1.0, 1.0));
        float2 m = float2(lon, lat) * R; // arc-length coordinates (pt) on the peel
        const float e = 0.35;
        float h = peelH(m), hx = peelH(m + float2(e, 0)), hy = peelH(m + float2(0, e));
        float3 N = normalize(N0 + float3(-(hx - h) / e, -(hy - h) / e, 0.0) * 0.45 * z);

        float mott = fbm(m / 90.0 + 2.0, 4);
        float3 alb = mix(hexc(0xE0600C), hexc(0xF2801F), smoothstep(0.25, 0.75, mott));
        float pit = saturate(-(h - gfbm(m / 60.0, 3) * 1.5) / 0.8);
        alb *= 1.0 - 0.12 * pit;
        // stem button near the top
        float2 stemP = m - float2(-R * 0.18, -R * 1.18);
        float stem = 1.0 - smoothstep(6.0, 9.0, length(stemP));
        float stemRing = exp(-pow((length(stemP) - 12.0) / 3.0, 2.0));
        alb = mix(alb, hexc(0x4A4A1E), stem);
        alb *= 1.0 - 0.25 * stemRing;
        float3 A = srgb2lin(alb);

        float ndl = dot(N, L);
        float wrap = saturate((ndl + 0.08) / 1.08);
        float3 lit = A * (pow(wrap, 1.35) * 1.35 + 0.012);
        // subsurface: the terminator glows red-orange instead of going grey
        float term = exp(-pow((ndl - 0.02) / 0.22, 2.0));
        lit += A * float3(0.9, 0.25, 0.02) * term * 0.22;
        // bounce from the ledge onto the underside
        lit += A * float3(0.55, 0.32, 0.18) * saturate(N.y * 0.9 - 0.1) * 0.12;
        // waxy highlight + glints from the gland ridges
        float3 Hh = normalize(L + float3(0, 0, 1));
        float nh = saturate(dot(N, Hh));
        float nh0 = saturate(dot(N0, Hh));
        lit += float3(1.0, 0.9, 0.76) * (pow(nh0, 9.0) * 0.10 + pow(nh0, 40.0) * 0.18 + pow(nh, 160.0) * 0.6 * smoothstep(0.7, 0.97, nh0));
        // dark rim on the shadow side so it turns away into the gloom
        lit *= mix(1.0, 0.55, smoothstep(0.55, 1.0, sqrt(rr)) * saturate(-ndl + 0.3));

        // mould, wrapped onto the peel and lit by the same key
        float2 tuv = (m + float2(u.b.w, u.b.z) + mapSize * 0.5) / mapSize;
        float4 mc = t1.sample(ls, tuv);
        float shadeF = pow(wrap, 1.2) * 1.15 + 0.03;
        float3 mouldLit = srgb2lin(mc.a > 0.0 ? mc.rgb / mc.a : float3(0.0)) * shadeF;
        lit = mix(lit, mouldLit, mc.a);
        float3 orange = lin2srgb(lit);
        col = mix(col, orange, cover);
    }

    // ---- painted finish: varnish, craquelure, vignette
    float2 cq = p + float2(gfbm(p / 80.0, 2), gfbm(p / 80.0 + 3.0, 2)) * 14.0;
    float4 cr = worley(cq / 34.0, 1.0);
    float4 cr2 = worley(cq / 11.0 + 7.0, 1.0);
    float crack = (1.0 - smoothstep(0.0, 0.035, cr.y - cr.x)) * 0.8 + (1.0 - smoothstep(0.0, 0.05, cr2.y - cr2.x)) * 0.35 * step(0.5, fbm(p / 120.0, 2));
    float lum = luma(col);
    col *= 1.0 - crack * 0.14 * smoothstep(0.05, 0.4, lum);
    col = col * float3(1.0, 0.955, 0.86) + float3(0.012, 0.008, 0.0);
    float vig = smoothstep(0.35, 1.15, length((uv - float2(0.52, 0.45)) * float2(1.0, 1.2)));
    col *= 1.0 - 0.55 * vig;
    return float4(col, 1.0);
}
