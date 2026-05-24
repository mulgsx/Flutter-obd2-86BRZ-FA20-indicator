// ─── TakoGauge — reusable octopus-themed gauge ─────────────────────────────
// Adapted from the GT7 Octopus Tachometer for general OBD2 telemetry.
// Parameterized by value range, redline, theme colors, scale labels.

const { useMemo: useTakoMemo } = React;

// ─── Geometry (logical SVG units) ──────────────────────────────────────────
const TG_CX = 250, TG_CY = 218;
const TG_GAUGE_R  = 196;
const TG_TRACK_R  = TG_GAUGE_R - 10;
const TG_HEAD_R   = 70;
const TG_NEEDLE_R = 170;

const tgToRad = d => d * Math.PI / 180;
const tgPolar = (deg, r, ox = TG_CX, oy = TG_CY) => ({
  x: ox + r * Math.cos(tgToRad(deg)),
  y: oy + r * Math.sin(tgToRad(deg)),
});

// 0%→135°(SW), 100%→45°(SE), clockwise 270° through top
const pctToAngle = pct => 135 + Math.min(Math.max(pct, 0), 1) * 270;

const tgMakeArc = (a0, a1, r) => {
  const s = tgPolar(a0, r);
  const e = tgPolar(a1, r);
  const sw = ((a1 - a0) + 360) % 360 || 360;
  const lg = sw > 180 ? 1 : 0;
  return `M${s.x.toFixed(2)},${s.y.toFixed(2)} A${r},${r},0,${lg},1,${e.x.toFixed(2)},${e.y.toFixed(2)}`;
};

const tgBez = (t, p0, p1, p2, p3) => ({
  x: (1-t)**3*p0.x + 3*(1-t)**2*t*p1.x + 3*(1-t)*t**2*p2.x + t**3*p3.x,
  y: (1-t)**3*p0.y + 3*(1-t)**2*t*p1.y + 3*(1-t)*t**2*p2.y + t**3*p3.y,
});

// ─── SVG Defs — themed per gauge instance ──────────────────────────────────
function TgDefs({ id, theme, isRed }) {
  return (
    <defs>
      <radialGradient id={`bgGrad-${id}`} cx="50%" cy="50%">
        <stop offset="0%"   stopColor="#0d1728"/>
        <stop offset="100%" stopColor="#050810"/>
      </radialGradient>

      <radialGradient id={`headGrad-${id}`} cx="42%" cy="35%">
        <stop offset="0%"   stopColor={isRed ? theme.headHotLight : theme.headLight}/>
        <stop offset="60%"  stopColor={isRed ? theme.headHotMid   : theme.headMid}/>
        <stop offset="100%" stopColor={isRed ? theme.headHotDark  : theme.headDark}/>
      </radialGradient>

      <filter id={`glowTrack-${id}`} x="-50%" y="-50%" width="200%" height="200%">
        <feGaussianBlur stdDeviation="4" result="b"/>
        <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
      </filter>
      <filter id={`glowRed-${id}`} x="-50%" y="-50%" width="200%" height="200%">
        <feGaussianBlur stdDeviation="6" result="b"/>
        <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
      </filter>
      <filter id={`glowBeak-${id}`} x="-50%" y="-50%" width="200%" height="200%">
        <feGaussianBlur stdDeviation="5" result="b"/>
        <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
      </filter>
      <filter id={`softBlur-${id}`}>
        <feGaussianBlur stdDeviation="6"/>
      </filter>
      <filter id={`octoShadow-${id}`}>
        <feDropShadow dx="0" dy="4" stdDeviation="6" floodColor="#000" floodOpacity="0.35"/>
      </filter>
    </defs>
  );
}

// ─── Gauge Arc Tracks ──────────────────────────────────────────────────────
function TgGaugeArcs({ id, value, min, max, redline, limit, theme }) {
  const pct = (value - min) / (max - min);
  const pctRed = (redline - min) / (max - min);
  const pctLim = (limit - min) / (max - min);
  const cur = pctToAngle(pct);
  const red = pctToAngle(pctRed);
  const lim = pctToAngle(pctLim);
  const isRed = value >= redline;
  return (
    <g>
      <path d={tgMakeArc(red, 45, TG_TRACK_R)} fill="none" stroke="#4a0808" strokeWidth={16}/>
      <path d={tgMakeArc(135, red, TG_TRACK_R)} fill="none" stroke="#0e1e32" strokeWidth={16}/>
      {pct > 0.005 && (
        <path d={tgMakeArc(135, Math.min(cur, red), TG_TRACK_R)} fill="none"
              stroke={theme.track} strokeWidth={13} strokeLinecap="round" filter={`url(#glowTrack-${id})`}/>
      )}
      {isRed && (
        <path d={tgMakeArc(red, Math.min(cur, lim), TG_TRACK_R)} fill="none"
              stroke="#ef4444" strokeWidth={15} strokeLinecap="round" filter={`url(#glowRed-${id})`}
              style={{ animation: 'redPulse 0.2s ease-in-out infinite' }}/>
      )}
      <path d={tgMakeArc(135, 45, TG_GAUGE_R)} fill="none" stroke="#162540" strokeWidth={2}/>
      <path d={tgMakeArc(135, 45, TG_TRACK_R - 10)} fill="none" stroke="#0a1525" strokeWidth={1.5}/>
    </g>
  );
}

// ─── Tick Marks — configurable scale ───────────────────────────────────────
function TgGaugeTicks({ min, max, redline, majorStep, minorStep, labelDiv, labelDecimals = 0 }) {
  const marks = [];
  for (let v = min; v <= max + 1e-6; v += minorStep) {
    const major = Math.abs((v - min) % majorStep) < 1e-6 || Math.abs((v - min) % majorStep - majorStep) < 1e-6;
    const pct = (v - min) / (max - min);
    const a = pctToAngle(pct);
    const isRed = v >= redline;
    const o = tgPolar(a, TG_GAUGE_R - 2);
    const i = tgPolar(a, TG_GAUGE_R - (major ? 24 : 12));
    const lbl = tgPolar(a, TG_GAUGE_R - 40);
    marks.push(
      <g key={v.toFixed(2)}>
        <line x1={i.x.toFixed(1)} y1={i.y.toFixed(1)} x2={o.x.toFixed(1)} y2={o.y.toFixed(1)}
              stroke={isRed ? '#f87171' : '#233550'} strokeWidth={major ? 2.5 : 1.2}/>
        {major && (
          <text x={lbl.x.toFixed(1)} y={lbl.y.toFixed(1)}
                textAnchor="middle" dominantBaseline="middle"
                fontSize="13.5" fontFamily="Orbitron" fontWeight="700"
                fill={isRed ? '#f87171' : '#2d4d70'}>
            {(v / labelDiv).toFixed(labelDecimals)}
          </text>
        )}
      </g>
    );
  }
  return <g>{marks}</g>;
}

// ─── Tentacles ─────────────────────────────────────────────────────────────
function TgTentacles({ theme }) {
  const configs = [
    { a: 32,  len: 86,  curl: -1, delay: 0.00 },
    { a: 48,  len: 94,  curl:  1, delay: 0.15 },
    { a: 65,  len: 100, curl: -1, delay: 0.28 },
    { a: 82,  len: 104, curl:  1, delay: 0.40 },
    { a: 99,  len: 104, curl: -1, delay: 0.50 },
    { a: 116, len: 100, curl:  1, delay: 0.58 },
    { a: 133, len: 94,  curl: -1, delay: 0.65 },
    { a: 149, len: 86,  curl:  1, delay: 0.70 },
  ];
  return (
    <g>
      {configs.map(({ a, len, curl, delay }, i) => {
        const pA = a + 90;
        const s  = tgPolar(a, TG_HEAD_R * 0.9);
        const p1 = {
          x: s.x + len*0.40*Math.cos(tgToRad(a)) + curl*20*Math.cos(tgToRad(pA)),
          y: s.y + len*0.40*Math.sin(tgToRad(a)) + curl*20*Math.sin(tgToRad(pA)),
        };
        const p2 = {
          x: s.x + len*0.75*Math.cos(tgToRad(a)) - curl*12*Math.cos(tgToRad(pA)),
          y: s.y + len*0.75*Math.sin(tgToRad(a)) - curl*12*Math.sin(tgToRad(pA)),
        };
        const e = { x: s.x + len*Math.cos(tgToRad(a)), y: s.y + len*Math.sin(tgToRad(a)) };
        const spots = [0.28, 0.54, 0.78].map(t => tgBez(t, s, p1, p2, e));
        const curlAng = a + curl * 70;
        const tipCurl = {
          x: e.x + 22 * Math.cos(tgToRad(curlAng)),
          y: e.y + 22 * Math.sin(tgToRad(curlAng)),
        };
        return (
          <g key={i} style={{
            animation: `tentacleWave ${1.4 + i*0.18}s ease-in-out infinite`,
            animationDelay: `${delay}s`,
            transformOrigin: `${s.x.toFixed(0)}px ${s.y.toFixed(0)}px`,
          }}>
            <path
              d={`M${s.x.toFixed(1)},${s.y.toFixed(1)} C${p1.x.toFixed(1)},${p1.y.toFixed(1)} ${p2.x.toFixed(1)},${p2.y.toFixed(1)} ${e.x.toFixed(1)},${e.y.toFixed(1)}`}
              stroke={theme.body} strokeWidth="22" fill="none" strokeLinecap="round"
            />
            <path d={`M${e.x.toFixed(1)},${e.y.toFixed(1)} Q${tipCurl.x.toFixed(1)},${tipCurl.y.toFixed(1)} ${((e.x+tipCurl.x)/2).toFixed(1)},${((e.y+tipCurl.y)/2).toFixed(1)}`}
              stroke={theme.body} strokeWidth="14" fill="none" strokeLinecap="round"/>
            {spots.map((pt, si) => (
              <circle key={si} cx={pt.x.toFixed(1)} cy={pt.y.toFixed(1)}
                      r="9" fill={theme.spot}/>
            ))}
          </g>
        );
      })}
    </g>
  );
}

// ─── Beak Needle ───────────────────────────────────────────────────────────
function TgBeakNeedle({ id, value, min, max, redline, theme }) {
  const pct = (value - min) / (max - min);
  const a   = pctToAngle(pct);
  const aR  = tgToRad(a);
  const perpR = tgToRad(a + 90);
  const isRed = value >= redline;

  const tip = { x: TG_CX + TG_NEEDLE_R*Math.cos(aR), y: TG_CY + TG_NEEDLE_R*Math.sin(aR) };
  const bw  = 17;
  const bL  = { x: TG_CX + bw*Math.cos(perpR), y: TG_CY + bw*Math.sin(perpR) };
  const bR  = { x: TG_CX - bw*Math.cos(perpR), y: TG_CY - bw*Math.sin(perpR) };

  const ctrlPuff = 12;
  const ctrlFwd  = TG_NEEDLE_R * 0.55;
  const cL = {
    x: bL.x + ctrlFwd*Math.cos(aR) + ctrlPuff*Math.cos(perpR),
    y: bL.y + ctrlFwd*Math.sin(aR) + ctrlPuff*Math.sin(perpR),
  };
  const cR = {
    x: bR.x + ctrlFwd*Math.cos(aR) - ctrlPuff*Math.cos(perpR),
    y: bR.y + ctrlFwd*Math.sin(aR) - ctrlPuff*Math.sin(perpR),
  };
  const back = { x: TG_CX - 30*Math.cos(aR), y: TG_CY - 30*Math.sin(aR) };

  const beakClr = isRed ? '#fca5a5' : theme.beak;
  const beakCrease = isRed ? '#dc4444' : theme.beakCrease;
  const glowFlt = isRed ? `url(#glowRed-${id})` : `url(#glowBeak-${id})`;

  return (
    <g>
      <path
        d={`M${bL.x.toFixed(1)},${bL.y.toFixed(1)} Q${cL.x.toFixed(1)},${cL.y.toFixed(1)} ${tip.x.toFixed(1)},${tip.y.toFixed(1)} Q${cR.x.toFixed(1)},${cR.y.toFixed(1)} ${bR.x.toFixed(1)},${bR.y.toFixed(1)} Z`}
        fill={beakClr} filter={glowFlt}
      />
      <circle cx={tip.x.toFixed(1)} cy={tip.y.toFixed(1)} r="6"
              fill={beakClr} filter={glowFlt}/>
      <path
        d={`M${bL.x.toFixed(1)},${bL.y.toFixed(1)} Q${(TG_CX + TG_NEEDLE_R*0.25*Math.cos(aR)).toFixed(1)},${(TG_CY + TG_NEEDLE_R*0.25*Math.sin(aR)).toFixed(1)} ${bR.x.toFixed(1)},${bR.y.toFixed(1)}`}
        stroke={beakCrease} strokeWidth="2" fill="none" opacity="0.5"
      />
      <circle cx={back.x.toFixed(1)} cy={back.y.toFixed(1)} r="13"
              fill="#1a0a30" stroke={isRed ? '#cc1a1a' : theme.counterStroke} strokeWidth="2"/>
    </g>
  );
}

// ─── Head Background ───────────────────────────────────────────────────────
function TgHeadBack({ id, value, redline, theme }) {
  const isRed = value >= redline;
  const auraColor = isRed ? 'rgba(220,30,30,0.35)' : theme.aura;
  return (
    <g>
      <circle cx={TG_CX} cy={TG_CY} r={TG_HEAD_R + 20}
              fill={auraColor} filter={`url(#softBlur-${id})`}
              style={{ animation: isRed ? 'redPulse 0.2s infinite' : 'none' }}/>
      <circle cx={TG_CX} cy={TG_CY} r={TG_HEAD_R}
              fill={`url(#headGrad-${id})`} filter={`url(#octoShadow-${id})`}/>
      <path d={`M${TG_CX-55},${TG_CY-28} Q${TG_CX-42},${TG_CY-72} ${TG_CX+10},${TG_CY-68}`}
            stroke="rgba(255,255,255,0.12)" strokeWidth="10" fill="none" strokeLinecap="round"/>
    </g>
  );
}

// ─── Face Front ────────────────────────────────────────────────────────────
function TgFaceFront({ id, value, min, max, redline, hotThresholdPct, theme }) {
  const pct = (value - min) / (max - min);
  const a   = pctToAngle(pct);
  const aR  = tgToRad(a);
  const isRed = value >= redline;

  const pupilDx = Math.cos(aR) * 5;
  const pupilDy = Math.sin(aR) * 5;
  const browRaise = pct > hotThresholdPct ? (pct - hotThresholdPct) * 30 : 0;
  const blush = Math.max(0, Math.min((pct - 0.4) / 0.55, 0.55));

  return (
    <g>
      <path d={`M${TG_CX-40},${TG_CY-40-browRaise} Q${TG_CX-26},${TG_CY-50-browRaise} ${TG_CX-14},${TG_CY-42-browRaise}`}
            stroke={theme.brow} strokeWidth="4" fill="none" strokeLinecap="round"/>
      <path d={`M${TG_CX+14},${TG_CY-42-browRaise} Q${TG_CX+26},${TG_CY-50-browRaise} ${TG_CX+40},${TG_CY-40-browRaise}`}
            stroke={theme.brow} strokeWidth="4" fill="none" strokeLinecap="round"/>

      <circle cx={TG_CX-24} cy={TG_CY-26} r={16} fill="#140404"
              style={{ animation: 'eyeBlink 4s ease-in-out infinite', transformOrigin: `${TG_CX-24}px ${TG_CY-26}px` }}/>
      <circle cx={TG_CX+24} cy={TG_CY-26} r={16} fill="#140404"
              style={{ animation: 'eyeBlink 4s ease-in-out infinite 0.07s', transformOrigin: `${TG_CX+24}px ${TG_CY-26}px` }}/>

      <circle cx={(TG_CX-24+pupilDx*0.5).toFixed(1)} cy={(TG_CY-26+pupilDy*0.5).toFixed(1)} r="9" fill="#0a0202"/>
      <circle cx={(TG_CX+24+pupilDx*0.5).toFixed(1)} cy={(TG_CY-26+pupilDy*0.5).toFixed(1)} r="9" fill="#0a0202"/>

      <circle cx={(TG_CX-30+pupilDx*0.25).toFixed(1)} cy={(TG_CY-33+pupilDy*0.25).toFixed(1)} r="4.5" fill="white" opacity="0.9"/>
      <circle cx={(TG_CX+18+pupilDx*0.25).toFixed(1)} cy={(TG_CY-33+pupilDy*0.25).toFixed(1)} r="4.5" fill="white" opacity="0.9"/>
      <circle cx={(TG_CX-20+pupilDx*0.25).toFixed(1)} cy={(TG_CY-18+pupilDy*0.25).toFixed(1)} r="2" fill="white" opacity="0.45"/>
      <circle cx={(TG_CX+28+pupilDx*0.25).toFixed(1)} cy={(TG_CY-18+pupilDy*0.25).toFixed(1)} r="2" fill="white" opacity="0.45"/>

      {blush > 0 && (<>
        <circle cx={TG_CX-42} cy={TG_CY-8} r={14} fill="#f87171" opacity={blush*0.5} filter={`url(#softBlur-${id})`}/>
        <circle cx={TG_CX+42} cy={TG_CY-8} r={14} fill="#f87171" opacity={blush*0.5} filter={`url(#softBlur-${id})`}/>
      </>)}

      <circle cx={TG_CX} cy={TG_CY} r={20} fill={theme.mouthOuter} stroke={theme.mouthOuterStroke} strokeWidth="2"/>
      <circle cx={TG_CX} cy={TG_CY} r={12} fill="#3a0804"/>
      <path d={`M${TG_CX-11},${TG_CY-10} Q${TG_CX},${TG_CY-13} ${TG_CX+11},${TG_CY-10}`}
            stroke="rgba(255,140,60,0.45)" strokeWidth="3" fill="none" strokeLinecap="round"/>
    </g>
  );
}

// ─── Main TakoGauge component ──────────────────────────────────────────────
function TakoGauge({
  id, value, min, max, redline, limit,
  majorStep, minorStep, labelDiv = 1, labelDecimals = 0,
  hotThresholdPct = 0.7,
  theme,
  scaleLabel,
}) {
  const isRed = value >= redline;
  return (
    <svg viewBox="0 0 500 520" style={{ width: '100%', height: '100%', overflow: 'visible' }}>
      <TgDefs id={id} theme={theme} isRed={isRed}/>
      <circle cx={TG_CX} cy={TG_CY} r={TG_GAUGE_R + 12}
              fill={`url(#bgGrad-${id})`} stroke="#0f1e30" strokeWidth="2.5"/>
      <TgGaugeArcs id={id} value={value} min={min} max={max} redline={redline} limit={limit} theme={theme}/>
      <TgGaugeTicks min={min} max={max} redline={redline}
                    majorStep={majorStep} minorStep={minorStep}
                    labelDiv={labelDiv} labelDecimals={labelDecimals}/>
      {scaleLabel && (
        <text x={TG_CX} y={TG_CY + 150} textAnchor="middle"
              fontSize="11" fontFamily="Orbitron" fill="#1e3450" letterSpacing="3">
          {scaleLabel}
        </text>
      )}
      <TgTentacles theme={theme}/>
      <TgHeadBack id={id} value={value} redline={redline} theme={theme}/>
      <TgBeakNeedle id={id} value={value} min={min} max={max} redline={redline} theme={theme}/>
      <TgFaceFront id={id} value={value} min={min} max={max} redline={redline}
                   hotThresholdPct={hotThresholdPct} theme={theme}/>
    </svg>
  );
}

// ─── Themes for each metric ────────────────────────────────────────────────
const THEMES = {
  red: {
    track: '#22d3ee',
    headLight: '#ee4444', headMid: '#cc1a1a', headDark: '#8a0a0a',
    headHotLight: '#ff6060', headHotMid: '#ee2020', headHotDark: '#aa0a0a',
    body: '#cc1a1a',
    spot: '#e87030',
    beak: '#f0921a', beakCrease: '#b85a0a',
    counterStroke: '#5b21b6',
    aura: 'rgba(200,30,30,0.18)',
    brow: '#6a0808',
    mouthOuter: '#c04820', mouthOuterStroke: '#7a1c06',
  },
  blue: {
    track: '#22d3ee',
    headLight: '#5da9e8', headMid: '#2a6fc4', headDark: '#0e3a78',
    headHotLight: '#ff6060', headHotMid: '#ee2020', headHotDark: '#aa0a0a',
    body: '#2a6fc4',
    spot: '#7ec8ff',
    beak: '#ffd166', beakCrease: '#b8870a',
    counterStroke: '#1d4e94',
    aura: 'rgba(40,110,200,0.22)',
    brow: '#0a2a52',
    mouthOuter: '#1d4e94', mouthOuterStroke: '#0a2a52',
  },
  amber: {
    track: '#22d3ee',
    headLight: '#f4b860', headMid: '#d18a1c', headDark: '#7a4a08',
    headHotLight: '#ff6060', headHotMid: '#ee2020', headHotDark: '#aa0a0a',
    body: '#c98318',
    spot: '#ffd97a',
    beak: '#ff8b3a', beakCrease: '#8a3a08',
    counterStroke: '#7a4a08',
    aura: 'rgba(210,140,30,0.22)',
    brow: '#5a3208',
    mouthOuter: '#8a4a10', mouthOuterStroke: '#5a2c06',
  },
};

Object.assign(window, { TakoGauge, THEMES });
