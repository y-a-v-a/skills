// Macro orange rind: oil-gland pits in gently domed cushions, waxy sheen, lit from the top-left like the mould.
float rindHeight(float2 p, thread float &gland) {
    float2 w = float2(gfbm(p / 60.0, 3), gfbm(p / 60.0 + 9.1, 3));
    float2 q = p + w * 3.5;
    // Gland spacing ~9pt: about a millimetre if a colony is a centimetre or two across.
    float4 c1 = worley(q / 9.0, 0.85);
    float r1 = mix(0.26, 0.42, hash12(float2(c1.z * 91.0, 3.0)));
    float t1 = saturate(c1.x / r1);
    float pit1 = (1.0 - t1 * t1) * (1.0 - t1 * t1) * mix(0.7, 1.0, fract(c1.z * 13.7));
    float cushion = smoothstep(-0.1, 0.6, sworley(q / 9.0, 0.85, 9.0)) * 0.35;
    // Finer pores in between, only some cells.
    float4 c2 = worley(q / 4.4 + 40.0, 0.9);
    float on2 = step(0.55, fract(c2.z * 7.3));
    float t2 = saturate(c2.x / 0.30);
    float pit2 = (1.0 - t2 * t2) * (1.0 - t2 * t2) * 0.22 * on2;
    float und = gfbm(p / 140.0, 4) * 3.0 + gfbm(p / 40.0 + 3.0, 3) * 0.5;
    float micro = 0.0;
    gland = max(pit1, pit2 * 0.6);
    return und + cushion - pit1 * 0.9 - pit2 * 0.6 + micro;
}

float4 shade(float2 p, constant U &u, texture2d<float> t1) {
    float2 size = u.view.xy;
    float2 uv = p / size;
    float g, gx, gy;
    const float e = 0.35;
    float h = rindHeight(p, g);
    float hx = rindHeight(p + float2(e, 0), gx);
    float hy = rindHeight(p + float2(0, e), gy);
    float bump = u.a.x > 0.0 ? u.a.x : 0.5;
    // Macro depth of field: sharp around the focus point (where the mould is), soft towards the text.
    float focus = 1.0 - smoothstep(0.18, 0.62, length((uv - u.a.yz) * float2(1.0, 0.8)));
    bump *= mix(u.a.w, 1.0, focus);
    float3 n = normalize(float3(-(hx - h) / e * bump, -(hy - h) / e * bump, 1.0));

    // Albedo: waxy orange, slow subtle hue drift; glands deeper, redder and more translucent.
    float mott = fbm(p / 320.0 + u.view.w, 4);
    float3 alb = mix(hexc(0xEC6A0C), hexc(0xF98C1A), smoothstep(0.3, 0.7, mott));
    alb = mix(alb, hexc(0xF4A23C), smoothstep(0.55, 0.8, fbm(p / 110.0 + 7.0, 3)) * 0.18);
    alb = mix(alb, alb * float3(0.86, 0.66, 0.55), g * 0.55);
    float3 A = srgb2lin(alb);

    // Large-scale form: the fruit curves away from the light towards the bottom-right.
    float form = 1.0 - 0.6 * smoothstep(0.1, 1.3, length((uv - float2(0.3, 0.0)) * float2(1.0, 1.35)));
    const float3 L = normalize(float3(-0.55, -0.7, 0.85));
    float diff = saturate(dot(n, L));
    float3 lit = A * (0.25 + 0.95 * diff) * form;
    lit += A * float3(0.6, 0.15, 0.0) * 0.20 * (1.0 - diff) * form; // warm translucency in the shade

    // Waxy specular: glints on every cushion, gathered in a broad softbox reflection near the top.
    float3 Hh = normalize(L + float3(0, 0, 1));
    float nh = saturate(dot(n, Hh));
    float2 bc = u.b.xy; // softbox centre (uv)
    float box = exp(-pow(length((uv - bc) * float2(1.0, 2.0)) / u.b.z, 2.0));
    float spec = pow(nh, mix(30.0, 90.0, focus)) * (0.06 + 1.1 * box) * mix(0.4, 1.0, focus) + pow(nh, 14.0) * 0.06 * box;
    lit += float3(1.0, 0.94, 0.84) * spec * u.b.w;

    // Vignette, deepening into rind red.
    float vig = smoothstep(0.35, 1.15, length((uv - float2(0.40, 0.40)) * float2(1.0, 1.3)));
    lit = mix(lit, lit * float3(0.62, 0.30, 0.12), vig * 0.6);
    return float4(lin2srgb(lit), 1.0);
}
