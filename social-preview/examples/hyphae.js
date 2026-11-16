// Darkfield hyphae: tips grow out of each colony, wander, branch, and some end in a Penicillium brush.
function mulberry32(a){return function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}}
function growHyphae(canvas, colonies, opt){
  const S=2, W=1280*S, H=640*S;
  canvas.width=W; canvas.height=H;
  const ctx=canvas.getContext('2d');
  const rnd=mulberry32(opt.seed??7);
  const cell=8, gw=Math.ceil(W/cell), gh=Math.ceil(H/cell), dens=new Float32Array(gw*gh);
  const segs=[], heads=[];
  const tips=[];
  for(const c of colonies){
    const n=Math.round(c.r*(opt.perR??0.55));
    for(let i=0;i<n;i++){
      const a=2*Math.PI*(i+rnd()*0.8)/n;
      const r0=c.r*(1.0+rnd()*0.08)*S;
      tips.push({x:c.x*S+Math.cos(a)*r0, y:c.y*S+Math.sin(a)*r0, a:a, da:0, life:c.r*S*(0.4+Math.pow(rnd(),opt.tail??1.6)*(opt.reach??1.6)), w:opt.w0??1.1, gen:0});
    }
  }
  const step=2.2, avoid=opt.avoid??null;
  let guard=0;
  while(tips.length && guard++<400000){
    const t=tips.pop();
    while(t.life>0){
      t.da=t.da*0.9+(rnd()-0.5)*(opt.wander??0.07);
      t.a+=t.da;
      const nx=t.x+Math.cos(t.a)*step, ny=t.y+Math.sin(t.a)*step;
      if(nx<0||ny<0||nx>=W||ny>=H){t.life=0;break}
      const gi=((ny/cell)|0)*gw+((nx/cell)|0);
      if(dens[gi]>(opt.maxDens??1.3)||segs.length>(opt.maxSegs??160000)){t.life=0;break}
      dens[gi]+=0.08*t.w;
      segs.push([t.x,t.y,nx,ny,t.w,t.gen,t.life]);
      t.x=nx;t.y=ny;t.life-=step;
      if(rnd()<(opt.branch??0.011) && t.gen<5){
        const s=rnd()<0.5?-1:1;
        tips.push({x:t.x,y:t.y,a:t.a+s*(0.35+rnd()*0.5),da:0,life:t.life*(0.4+rnd()*0.45),w:Math.max(0.45,t.w*0.72),gen:t.gen+1});
      }
    }
    if(t.gen>=1 && rnd()<(opt.brush??0.22)) heads.push({x:t.x,y:t.y,a:t.a,w:t.w});
  }
  // Batch strokes by width/alpha bucket into Path2Ds: a few dozen strokes instead of a million.
  function render(target, widthMul){
    const c=target.getContext('2d');
    c.globalCompositeOperation='lighter'; c.lineCap='round';
    const buckets=new Map();
    for(const s of segs){
      const fade=Math.min(1, s[6]/(60*S));
      const w=Math.round(s[4]*(0.6+0.4*fade)*10)/10, al=Math.round(((opt.a0??0.16)+(opt.a1??0.24)*fade)*20)/20;
      const k=w+'|'+al; let p=buckets.get(k); if(!p){p=new Path2D();buckets.set(k,p)}
      p.moveTo(s[0],s[1]); p.lineTo(s[2],s[3]);
    }
    for(const [k,p] of buckets){const [w,al]=k.split('|').map(Number);
      c.strokeStyle=`rgba(232,238,226,${al})`; c.lineWidth=w*widthMul; c.stroke(p);}
    // Penicillium brushes: a stalk splits into metulae, then phialides, each pushing out a chain of conidia.
    const r2=mulberry32(99), stalks=new Path2D(), spores=new Path2D(), bs=opt.brushScale??0.7;
    for(const h of heads){
      const m=3+((r2()*2)|0);
      for(let i=0;i<m;i++){
        const a=h.a+(i-(m-1)/2)*0.3+(r2()-0.5)*0.1, L1=(7+r2()*4)*bs;
        const mx=h.x+Math.cos(a)*L1, my=h.y+Math.sin(a)*L1;
        stalks.moveTo(h.x,h.y); stalks.lineTo(mx,my);
        for(let j=0;j<2;j++){
          const b=a+(j-0.5)*0.2, L2=(5+r2()*2)*bs;
          let px=mx+Math.cos(b)*L2, py=my+Math.sin(b)*L2;
          stalks.moveTo(mx,my); stalks.lineTo(px,py);
          const chain=4+((r2()*6)|0);
          for(let k=0;k<chain;k++){ px+=Math.cos(b)*3.1*bs; py+=Math.sin(b)*3.1*bs;
            spores.moveTo(px+1.35*bs,py); spores.arc(px,py,1.35*bs,0,Math.PI*2); }
        }
      }
    }
    c.strokeStyle='rgba(236,240,230,.42)'; c.lineWidth=0.8*widthMul; c.stroke(stalks);
    c.fillStyle=`rgba(${opt.sporeTint??'205,226,196'},.6)`; c.fill(spores);
  }
  const off=document.createElement('canvas'); off.width=W; off.height=H;
  render(off, 1);
  ctx.save(); ctx.filter=`blur(${opt.glow??7}px)`; ctx.globalAlpha=opt.glowAlpha??0.9; ctx.drawImage(off,0,0); ctx.restore();
  ctx.save(); ctx.globalCompositeOperation='lighter'; ctx.drawImage(off,0,0); ctx.restore();
  return {segs:segs.length, heads:heads.length};
}
