import { MATERIALS, SEDIMENT_MATERIAL_IDS } from "../../core/materials/materials";
import type { FaultEvent, FoldEvent, GeoEvent, SedimentationEvent, ValidationResult } from "../../geology/events/types";
import { Num, Section, Select } from "./fields";

const matOpts = [...SEDIMENT_MATERIAL_IDS].map((id) => ({ value: id, label: MATERIALS[id]!.name }));

export function ParameterPanel({ event, onChange, validation }: { event: GeoEvent | null; onChange: (e: GeoEvent) => void; validation?: ValidationResult | undefined }) {
  if (!event) return <p className="font-mono text-[11px] text-muted-foreground">Vyberte událost na časové ose.</p>;
  const base = (
    <Section title={`${event.id} · v${event.algorithmVersion}`}>
      <label className="block font-mono text-[10px] text-muted-foreground">Název
        <input className="lab-input mt-0.5" value={event.name} onChange={(e) => onChange({ ...event, name: e.target.value })} />
      </label>
      <label className="flex items-center justify-between font-mono text-[10px] text-muted-foreground">Seed
        <input type="number" className="lab-input w-28 text-right" value={event.seed} onChange={(e) => onChange({ ...event, seed: (parseInt(e.target.value) || 0) >>> 0 })} />
      </label>
      {validation && (validation.errors.length > 0 || validation.warnings.length > 0) && (
        <ul className="space-y-0.5 font-mono text-[10px]">
          {validation.errors.map((e) => <li key={e} className="text-destructive">✕ {e}</li>)}
          {validation.warnings.map((w) => <li key={w} className="text-primary">! {w}</li>)}
        </ul>
      )}
    </Section>
  );
  return (
    <div className="space-y-3">
      {base}
      {event.type === "sedimentation" && <SedParams e={event} on={onChange} />}
      {event.type === "fold" && <FoldParams e={event} on={onChange} />}
      {event.type === "fault" && <FaultParams e={event} on={onChange} />}
    </div>
  );
}

function SedParams({ e, on }: { e: SedimentationEvent; on: (e: GeoEvent) => void }) {
  const p = e.params;
  const set = (q: Partial<SedimentationEvent["params"]>) => on({ ...e, params: { ...p, ...q } });
  return (
    <>
      <Section title="Rozsah sedimentace (osa Y)">
        <Num label="Výška počátku (erozní báze)" value={p.yStart} min={0} max={128} step={0.5} unit="m" onChange={(v) => set({ yStart: v })} />
        <Num label="Výška konce" value={p.yEnd} min={0} max={128} step={0.5} unit="m" onChange={(v) => set({ yEnd: v })} />
        <Select label="Režim" value={p.mode} options={[{ value: "erode", label: "eroze + uložení (diskordance)" }, { value: "onlap", label: "jen vyplnění prázdna" }]} onChange={(v) => set({ mode: v })} />
      </Section>
      <Section title="Nepravidelnost">
        <Num label="Variace mocnosti" value={p.thicknessVariation} min={0} max={0.9} step={0.01} onChange={(v) => set({ thicknessVariation: v })} />
        <Num label="Frekvence variace" value={p.thicknessFrequency} min={0.005} max={0.2} step={0.005} unit="1/m" onChange={(v) => set({ thicknessFrequency: v })} />
        <Num label="Amplituda šumu rozhraní" value={p.roughness} min={0} max={4} step={0.05} unit="m" onChange={(v) => set({ roughness: v })} />
        <Num label="Frekvence šumu rozhraní" value={p.roughnessFrequency} min={0.02} max={0.5} step={0.01} unit="1/m" onChange={(v) => set({ roughnessFrequency: v })} />
      </Section>
      <Section title={`Vrstvy (${p.layers.length}) – zdola nahoru`}>
        {p.layers.map((l, i) => (
          <div key={i} className="flex items-center gap-1">
            <select className="lab-input" value={l.materialId} onChange={(ev) => set({ layers: p.layers.map((x, j) => (j === i ? { ...x, materialId: +ev.target.value } : x)) })}>
              {matOpts.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
            </select>
            <input type="number" className="lab-input w-14 text-right" step={0.5} min={0} value={l.thickness}
              onChange={(ev) => set({ layers: p.layers.map((x, j) => (j === i ? { ...x, thickness: Math.max(0, +ev.target.value) } : x)) })} />
            <button className="lab-btn" onClick={() => set({ layers: p.layers.filter((_, j) => j !== i) })}>×</button>
          </div>
        ))}
        <button className="lab-btn w-full" onClick={() => set({ layers: [...p.layers, { materialId: matOpts[p.layers.length % matOpts.length]!.value, thickness: 4 }] })}>+ vrstva</button>
      </Section>
      <Section title="Lokální změny mocnosti">
        {p.local.map((l, i) => (
          <div key={i} className="grid grid-cols-5 gap-1">
            {(["x", "z", "radius", "factor"] as const).map((k) => (
              <input key={k} title={k} type="number" step={k === "factor" ? 0.05 : 1} className="lab-input" value={l[k]}
                onChange={(ev) => set({ local: p.local.map((x, j) => (j === i ? { ...x, [k]: +ev.target.value } : x)) })} />
            ))}
            <button className="lab-btn" onClick={() => set({ local: p.local.filter((_, j) => j !== i) })}>×</button>
          </div>
        ))}
        <div className="font-mono text-[9px] text-muted-foreground">x · z · poloměr · faktor</div>
        <button className="lab-btn w-full" onClick={() => set({ local: [...p.local, { x: 32, z: 32, radius: 12, factor: 0.4 }] })}>+ lokální změna</button>
      </Section>
    </>
  );
}

function FoldParams({ e, on }: { e: FoldEvent; on: (e: GeoEvent) => void }) {
  const p = e.params;
  const set = (q: Partial<FoldEvent["params"]>) => on({ ...e, params: { ...p, ...q } });
  return (
    <>
      <Section title="Vlna">
        <Num label="Amplituda A" value={p.amplitude} min={0} max={20} step={0.1} unit="m" onChange={(v) => set({ amplitude: v })} />
        <Num label="Vlnová délka λ" value={p.wavelength} min={4} max={200} step={1} unit="m" onChange={(v) => set({ wavelength: v })} />
        <Num label="Směr α (od +X k +Z)" value={p.azimuthDeg} min={0} max={180} step={1} unit="°" onChange={(v) => set({ azimuthDeg: v })} />
        <Num label="Fáze φ" value={p.phaseDeg} min={0} max={360} step={1} unit="°" onChange={(v) => set({ phaseDeg: v })} />
        <Num label="Intenzita" value={p.intensity} min={0} max={2} step={0.05} onChange={(v) => set({ intensity: v })} />
      </Section>
      <Section title="Nepravidelnost a hloubka">
        <Num label="Nepravidelnost I" value={p.irregularity} min={0} max={1} step={0.01} onChange={(v) => set({ irregularity: v })} />
        <Num label="Frekvence nepravidelnosti" value={p.irregularityFrequency} min={0.005} max={0.2} step={0.005} unit="1/m" onChange={(v) => set({ irregularityFrequency: v })} />
        <Num label="Hloubkový gradient γ (≠0 → numerická inverze)" value={p.depthGradient} min={-0.1} max={0.1} step={0.001} unit="1/m" onChange={(v) => set({ depthGradient: v })} />
        <Num label="Referenční výška yRef" value={p.yRef} min={0} max={128} step={1} unit="m" onChange={(v) => set({ yRef: v })} />
      </Section>
      <Section title="Prostorový rozsah (0 = neomezený)">
        <Num label="Střed X" value={p.extent.cx} min={0} max={128} step={1} unit="m" onChange={(v) => set({ extent: { ...p.extent, cx: v } })} />
        <Num label="Střed Z" value={p.extent.cz} min={0} max={128} step={1} unit="m" onChange={(v) => set({ extent: { ...p.extent, cz: v } })} />
        <Num label="Poloměr" value={p.extent.radius} min={0} max={128} step={1} unit="m" onChange={(v) => set({ extent: { ...p.extent, radius: v } })} />
        <Num label="Přechod" value={p.extent.falloff} min={1} max={64} step={1} unit="m" onChange={(v) => set({ extent: { ...p.extent, falloff: v } })} />
      </Section>
    </>
  );
}

function FaultParams({ e, on }: { e: FaultEvent; on: (e: GeoEvent) => void }) {
  const p = e.params;
  const set = (q: Partial<FaultEvent["params"]>) => on({ ...e, params: { ...p, ...q } });
  return (
    <>
      <Section title="Rovina zlomu">
        <Num label="Bod X" value={p.x} min={0} max={128} step={0.5} unit="m" onChange={(v) => set({ x: v })} />
        <Num label="Bod Y (výška)" value={p.y} min={0} max={128} step={0.5} unit="m" onChange={(v) => set({ y: v })} />
        <Num label="Bod Z" value={p.z} min={0} max={128} step={0.5} unit="m" onChange={(v) => set({ z: v })} />
        <Num label="Směr (strike, od +X k +Z)" value={p.strikeDeg} min={0} max={360} step={1} unit="°" onChange={(v) => set({ strikeDeg: v })} />
        <Num label="Sklon (dip)" value={p.dipDeg} min={1} max={90} step={1} unit="°" onChange={(v) => set({ dipDeg: v })} />
      </Section>
      <Section title="Posun">
        <Select label="Typ zlomu" value={p.faultType} onChange={(v) => set({ faultType: v })}
          options={[{ value: "normal", label: "normální (pokles)" }, { value: "reverse", label: "reverzní (přesmyk)" }, { value: "strike-slip", label: "horizontální posun" }, { value: "oblique", label: "kombinovaný" }]} />
        <Num label="Velikost posunu" value={p.displacement} min={0} max={30} step={0.1} unit="m" onChange={(v) => set({ displacement: v })} />
        {p.faultType === "oblique" && <Num label="Rake" value={p.rakeDeg} min={-90} max={90} step={1} unit="°" onChange={(v) => set({ rakeDeg: v })} />}
        <Num label="Šířka drcené zóny" value={p.damageWidth} min={0} max={6} step={0.1} unit="m" onChange={(v) => set({ damageWidth: v })} />
      </Section>
    </>
  );
}
