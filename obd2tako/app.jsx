// ─── OBD2 Tako Dashboard — main app ────────────────────────────────────────
const { useState: useAppState, useEffect: useAppEffect, useRef: useAppRef } = React;

// ─── Metric configurations ─────────────────────────────────────────────────
const METRICS = {
  water: {
    id: 'water',
    label: '水温 / COOLANT',
    unit: '°C',
    theme: THEMES.red,
    min: 40, max: 130,
    redline: 105, limit: 120,
    majorStep: 20, minorStep: 10,
    labelDiv: 1, labelDecimals: 0,
    scaleLabel: '°C  COOLANT',
    hotThresholdPct: 0.6,
    digits: 0,
    obdPid: '0x05',
  },
  rpm: {
    id: 'rpm',
    label: 'エンジン回転数 / RPM',
    unit: 'rpm',
    theme: THEMES.red,
    min: 0, max: 8000,
    redline: 6500, limit: 7500,
    majorStep: 1000, minorStep: 500,
    labelDiv: 1000, labelDecimals: 0,
    scaleLabel: '×1000  RPM',
    hotThresholdPct: 0.75,
    digits: 0,
    obdPid: '0x0C',
  },
  oil: {
    id: 'oil',
    label: '油温 / OIL TEMP',
    unit: '°C',
    theme: THEMES.red,
    min: 40, max: 150,
    redline: 125, limit: 140,
    majorStep: 20, minorStep: 10,
    labelDiv: 1, labelDecimals: 0,
    scaleLabel: '°C  OIL TEMP',
    hotThresholdPct: 0.65,
    digits: 0,
    obdPid: '0x5C',
  },
};

// ─── Simulation profiles for demo ──────────────────────────────────────────
const PROFILES = {
  idle:    { rpmBase: 850,  rpmAmp: 80,   waterTarget: 88,  oilTarget: 95  },
  cruise:  { rpmBase: 2400, rpmAmp: 400,  waterTarget: 92,  oilTarget: 105 },
  spirited:{ rpmBase: 4500, rpmAmp: 2200, waterTarget: 98,  oilTarget: 118 },
  redline: { rpmBase: 5800, rpmAmp: 1600, waterTarget: 103, oilTarget: 128 },
  overheat:{ rpmBase: 3200, rpmAmp: 1000, waterTarget: 115, oilTarget: 138 },
};

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "profile": "spirited",
  "showValueReadout": true,
  "showConnectionBar": true,
  "rpmScale": 1.2
}/*EDITMODE-END*/;

// ─── Readout below each gauge ──────────────────────────────────────────────
function ValueReadout({ value, metric, isRed, sub }) {
  const display = Math.round(value);
  const color = isRed ? '#ef4444' : '#ddeeff';
  return (
    <div style={{ textAlign: 'center', marginTop: 4 }}>
      <div style={{
        fontSize: 38, fontWeight: 700,
        color, fontFamily: 'Orbitron',
        textShadow: isRed ? '0 0 18px #ef4444' : '0 0 10px #06b6d420',
        letterSpacing: '0.02em',
        transition: 'color 0.08s',
        lineHeight: 1,
      }}>
        {display.toLocaleString()}
        <span style={{ fontSize: 16, marginLeft: 6, color: isRed ? '#ef444488' : '#4a6e90', fontWeight: 400 }}>
          {metric.unit}
        </span>
      </div>
      <div style={{
        marginTop: 8,
        fontSize: 9, letterSpacing: '0.35em',
        color: isRed ? '#ef444488' : '#2d4d70',
      }}>
        {isRed ? '⚠ ' + sub.warn : sub.normal}
      </div>
    </div>
  );
}

// ─── One full gauge column (gauge + readout + label) ──────────────────────
function GaugeColumn({ metric, value, scale = 1, showReadout, sub }) {
  const isRed = value >= metric.redline;
  // Width driven by CSS vars set on parent so all gauges scale together.
  const w = scale === 1
    ? 'var(--base-w)'
    : `calc(var(--base-w) * ${scale})`;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', flexShrink: 0, minWidth: 0 }}>
      <div style={{
        fontSize: 10, letterSpacing: '0.35em',
        color: isRed ? '#ef4444' : '#2d4d70',
        marginBottom: 8,
        fontFamily: 'Orbitron',
        whiteSpace: 'nowrap',
      }}>
        {metric.label}
      </div>
      <div style={{ width: w, aspectRatio: '500 / 520' }}>
        <TakoGauge
          id={metric.id}
          value={value}
          min={metric.min} max={metric.max}
          redline={metric.redline} limit={metric.limit}
          majorStep={metric.majorStep} minorStep={metric.minorStep}
          labelDiv={metric.labelDiv} labelDecimals={metric.labelDecimals}
          hotThresholdPct={metric.hotThresholdPct}
          theme={metric.theme}
          scaleLabel={metric.scaleLabel}
        />
      </div>
      {showReadout && <ValueReadout value={value} metric={metric} isRed={isRed} sub={sub}/>}
    </div>
  );
}

// ─── Top status bar ───────────────────────────────────────────────────────
function ConnectionBar({ connected }) {
  return (
    <div style={{
      display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 36,
      fontSize: 10, letterSpacing: '0.28em', color: '#1d3450',
      animation: 'scanIn 0.6s ease both',
      fontFamily: 'Orbitron',
      padding: '16px 24px 8px',
      flexWrap: 'wrap',
    }}>
      <span>OBD2 TAKO DASHBOARD</span>
      <span style={{ color: '#22d3ee30' }}>●</span>
      <span>ELM327 · BT</span>
      <span style={{ color: '#22d3ee30' }}>●</span>
      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
        <span style={{
          width: 8, height: 8, borderRadius: '50%',
          background: connected ? '#22d3ee' : '#ef4444',
          boxShadow: `0 0 8px ${connected ? '#22d3ee' : '#ef4444'}`,
          animation: connected ? 'bounce 1.6s ease-in-out infinite' : 'none',
        }}/>
        {connected ? 'CONNECTED · 10 Hz' : 'DISCONNECTED'}
      </span>
      <span style={{ color: '#22d3ee30' }}>●</span>
      <span>{new Date().toLocaleString('ja-JP', { hour: '2-digit', minute: '2-digit', second: '2-digit' })}</span>
    </div>
  );
}

// ─── Bottom OBD2 PID summary ──────────────────────────────────────────────
function PidLegend({ values }) {
  const items = [
    { name: METRICS.water.label, pid: METRICS.water.obdPid, val: values.water, unit: '°C' },
    { name: METRICS.rpm.label,   pid: METRICS.rpm.obdPid,   val: values.rpm,   unit: 'rpm' },
    { name: METRICS.oil.label,   pid: METRICS.oil.obdPid,   val: values.oil,   unit: '°C' },
  ];
  return (
    <div style={{
      display: 'flex', justifyContent: 'center', gap: 48,
      fontSize: 10, letterSpacing: '0.18em',
      color: '#2d4d70', fontFamily: 'Orbitron',
      padding: '10px 24px 16px',
      flexWrap: 'wrap',
    }}>
      {items.map((it, i) => (
        <div key={i} style={{ display: 'flex', gap: 10, alignItems: 'baseline' }}>
          <span style={{ color: '#1d3450' }}>PID {it.pid}</span>
          <span>{it.name}</span>
          <span style={{ color: '#4a6e90' }}>{Math.round(it.val)}{it.unit}</span>
        </div>
      ))}
    </div>
  );
}

// ─── Main Dashboard ────────────────────────────────────────────────────────
function Dashboard() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const profileKey = PROFILES[t.profile] ? t.profile : 'spirited';
  const profile = PROFILES[profileKey];

  const [rpm, setRpm] = useAppState(profile.rpmBase);
  const [water, setWater] = useAppState(70);
  const [oil, setOil]     = useAppState(70);

  // Smooth state targets
  const stateRef = useAppRef({ rpm: profile.rpmBase, water: 70, oil: 70 });

  useAppEffect(() => {
    let raf;
    const animate = (ts) => {
      const time = ts / 1000;
      // RPM: oscillation around base
      const noise = Math.sin(time * 1.3) * 0.5 + Math.sin(time * 3.7 + 1.2) * 0.3 + Math.sin(time * 0.7) * 0.2;
      const rpmTarget = Math.max(700, profile.rpmBase + noise * profile.rpmAmp);
      // Smooth water/oil
      const waterTarget = profile.waterTarget + Math.sin(time * 0.4) * 1.4;
      const oilTarget = profile.oilTarget + Math.sin(time * 0.3 + 0.8) * 1.8;

      stateRef.current.rpm   += (rpmTarget   - stateRef.current.rpm)   * 0.18;
      stateRef.current.water += (waterTarget - stateRef.current.water) * 0.015;
      stateRef.current.oil   += (oilTarget   - stateRef.current.oil)   * 0.012;

      setRpm(stateRef.current.rpm);
      setWater(stateRef.current.water);
      setOil(stateRef.current.oil);
      raf = requestAnimationFrame(animate);
    };
    raf = requestAnimationFrame(animate);
    return () => cancelAnimationFrame(raf);
  }, [profileKey]);

  const isAnyRed = rpm >= METRICS.rpm.redline || water >= METRICS.water.redline || oil >= METRICS.oil.redline;

  // Compute gauge width responsively. The center gauge takes scale× the side ones.
  // Horizontal budget: 2 + scale side units + gap*2 + padding
  // Vertical budget: gauge col height = label(30) + base*scale*1.04 + readout(80)
  const rowFactor = 2 + t.rpmScale;     // total width units
  const hPad = 140;                      // gap + outer padding budget
  const vReserved = 160;                 // top spacer + bottom spacer + label + readout
  const baseW = `min(360px, calc((100vw - ${hPad}px) / ${rowFactor}), calc((100vh - ${vReserved}px) * 500 / (520 * ${t.rpmScale})))`;

  return (
    <div style={{ width: '100vw', height: '100vh', display: 'flex', flexDirection: 'column', position: 'relative', overflow: 'hidden' }}>
      {/* Dot grid background */}
      <div style={{
        position: 'absolute', inset: 0, pointerEvents: 'none',
        backgroundImage: 'radial-gradient(circle, #12233a 1px, transparent 1px)',
        backgroundSize: '28px 28px', opacity: 0.22,
      }}/>
      {/* Redline screen flash */}
      {isAnyRed && (
        <div style={{
          position: 'absolute', inset: 0, pointerEvents: 'none',
          background: 'radial-gradient(ellipse at center, transparent 40%, rgba(200,20,20,0.07) 100%)',
          animation: 'redPulse 0.2s ease-in-out infinite',
        }}/>
      )}

      <div style={{ flexShrink: 0, height: 24 }}/>

      <div style={{
        flex: 1, minHeight: 0,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        position: 'relative', zIndex: 1,
      }}>
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          gap: 'min(28px, 2vw)', padding: '0 16px',
          '--base-w': baseW,
        }}>
          <GaugeColumn
            metric={METRICS.water} value={water} scale={1}
            showReadout={t.showValueReadout}
            sub={{ normal: 'COOLANT TEMP', warn: 'OVERHEAT' }}
          />
          <GaugeColumn
            metric={METRICS.rpm} value={rpm} scale={t.rpmScale}
            showReadout={t.showValueReadout}
            sub={{ normal: 'ENGINE RPM', warn: 'REDLINE' }}
          />
          <GaugeColumn
            metric={METRICS.oil} value={oil} scale={1}
            showReadout={t.showValueReadout}
            sub={{ normal: 'OIL TEMP', warn: 'OIL HOT' }}
          />
        </div>
      </div>

      <div style={{ flexShrink: 0, height: 24 }}/>

      <TweaksPanel title="Tweaks">
        <TweakSection title="シミュレーション">
          <TweakSelect
            label="走行プロファイル"
            value={t.profile}
            onChange={v => setTweak('profile', v)}
            options={[
              { value: 'idle',     label: 'アイドリング' },
              { value: 'cruise',   label: '巡航 (Cruise)' },
              { value: 'spirited', label: 'スポーツ走行' },
              { value: 'redline',  label: '全開 (Redline)' },
              { value: 'overheat', label: 'オーバーヒート警告' },
            ]}
          />
        </TweakSection>
        <TweakSection title="レイアウト">
          <TweakSlider
            label="RPMサイズ倍率"
            value={t.rpmScale}
            onChange={v => setTweak('rpmScale', v)}
            min={1} max={1.5} step={0.05}
            format={v => `×${v.toFixed(2)}`}
          />
          <TweakToggle
            label="数値リードアウト"
            value={t.showValueReadout}
            onChange={v => setTweak('showValueReadout', v)}
          />
        </TweakSection>
      </TweaksPanel>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<Dashboard/>);
