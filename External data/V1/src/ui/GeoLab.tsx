import { useCallback, useEffect, useMemo, useState } from "react";
import { DEFAULT_WORLD, RESOLUTIONS, WORLD_SIZES, type WorldConfig } from "../core/coordinates/world";
import { MATERIALS } from "../core/materials/materials";
import { buildGoldenVectors } from "../diagnostics/golden/goldenVectors";
import { measureTransforms } from "../diagnostics/profiler/metrics";
import { runSuite, type TestResult } from "../diagnostics/tests/suite";
import { SCENARIOS } from "../experiments/scenarios/scenarios";
import { GeologicalFieldEvaluator, newSample } from "../geology/evaluator/evaluator";
import type { GeoEvent, GeoEventType } from "../geology/events/types";
import { compileTimeline, createEvent, nextId, retime, type TimelineQuery } from "../geology/timeline/timeline";
import { exportTimeline, importTimeline } from "../geology/timeline/serialization";
import { CrossSection2D } from "../visualization/cross-section/CrossSection2D";
import { eventPalette, materialPalette, rgbCss } from "../visualization/materials/palette";
import { Viewport3D } from "../visualization/viewport/Viewport3D";
import { buildCulledMesh } from "../voxel/mesh/culledMesher";
import type { SectionAxis } from "../voxel/sampling/sampleGrid";
import { sectionPickPoint } from "../voxel/sampling/sectionCoordinates";
import { buildSectionPixels, sampleVisible } from "../visualization/cross-section/sectionDisplay";
import { readRenderTheme, type RenderTheme } from "../visualization/theme";
import { useGeologySamples } from "./useGeologySamples";
import { Button } from "../components/ui/button";
import { Eye, EyeOff } from "lucide-react";
import { DiagnosticsPanel } from "./diagnostics/DiagnosticsPanel";
import { Inspector, type InspectResult } from "./inspector/Inspector";
import { ParameterPanel } from "./parameters/ParameterPanel";
import { Num, Select } from "./parameters/fields";
import { TimelinePanel } from "./timeline/TimelinePanel";

const MAT_PAL = materialPalette();
const EV_PAL = eventPalette();
const download = (name: string, data: unknown) => {
  const url = URL.createObjectURL(new Blob([JSON.stringify(data, null, 2)], { type: "application/json" }));
  const a = document.createElement("a"); a.href = url; a.download = name; a.click(); URL.revokeObjectURL(url);
};

export function GeoLab() {
  const [world, setWorld] = useState<WorldConfig>(DEFAULT_WORLD);
  const [events, setEvents] = useState<GeoEvent[]>(() => (SCENARIOS.find(s => s.id === "E")?.build() ?? []));
  const [scenario, setScenario] = useState("E");
  const [selectedId, setSelectedId] = useState<string | null>("fault-1");
  const [isolateId, setIsolateId] = useState<string | null>(null);
  const [upToIndex, setUpToIndex] = useState<number | null>(null);
  const [res, setRes] = useState(1);
  const [mode, setMode] = useState<"3d" | "2d">("3d");
  const [colorBy, setColorBy] = useState<"material" | "event">("material");
  const [hidden, setHidden] = useState<number[]>([0]);
  const [solo, setSolo] = useState<number | null>(null);
  const [showSection, setShowSection] = useState(true);
  const [cut, setCut] = useState(true);
  const [boundaries, setBoundaries] = useState(false);
  const [sectionRes, setSectionRes] = useState(0.25);
  const [hiddenSources, setHiddenSources] = useState<number[]>([]);
  const [hiddenLayers, setHiddenLayers] = useState<string[]>([]);
  const [theme, setTheme] = useState<RenderTheme | null>(null);
  useEffect(() => setTheme(readRenderTheme()), []);
  const [cells, setCells] = useState(false);
  const [secAxis, setSecAxis] = useState<SectionAxis>("z");
  const [secPos, setSecPos] = useState(32);
  const [renderMs, setRenderMs] = useState(0);
  const [tests, setTests] = useState<TestResult[]>([]);
  const [testing, setTesting] = useState(false);
  const [inspect, setInspect] = useState<InspectResult | null>(null);
  const [tab, setTab] = useState<"params" | "inspect" | "diag">("params");
  const [msg, setMsg] = useState<string | null>(null);
  const query: TimelineQuery = useMemo(() => ({ upToIndex, isolateId }), [upToIndex, isolateId]);
  const samples = Math.round(world.sizeX / res) * Math.round(world.sizeY / res) * Math.round(world.sizeZ / res);
  const axisMax = (a: string) => a === "y" ? world.sizeY : a === "x" ? world.sizeX : world.sizeZ;
  const safeSecPos = Math.max(0, Math.min(axisMax(secAxis), secPos));
  const { grid, section, busy, error, client } = useGeologySamples(events, world, res, query, mode, secAxis, safeSecPos, sectionRes, showSection);
  // Source/layer indices are snapshot-local visual selections, never stable body identities.
  useEffect(() => { setHiddenSources([]); setHiddenLayers([]); }, [events, query]);

  const visible = useMemo(() => {
    const v = new Uint8Array(256);
    for (const m of MATERIALS) v[m.id] = solo !== null ? (m.id === solo ? 1 : 0) : hidden.includes(m.id) ? 0 : 1;
    v[0] = 0;
    return v;
  }, [hidden, solo]);
  const filter = useMemo(() => ({ visible, hiddenSources, hiddenLayers }), [visible, hiddenSources, hiddenLayers]);
  // Presentation-only mesh; the shader clips the surface without generating a voxel cap.
  const mesh = useMemo(() => {
    if (mode !== "3d" || !grid) return null;
    const mask = hiddenSources.length || hiddenLayers.length ? Uint8Array.from(grid.material, (m, i) =>
      sampleVisible(m, grid.source[i] ?? 255, grid.layer[i] ?? -1, filter) ? 1 : 0) : undefined;
    return buildCulledMesh({
      nx: grid.nx, ny: grid.ny, nz: grid.nz, res: grid.res, material: grid.material,
      colorKey: colorBy === "material" ? grid.material : grid.source, visible,
      palette: colorBy === "material" ? MAT_PAL : EV_PAL, cutAxis: -1, cutPos: 0, cellInset: cells ? 0.08 : 0,
      ...(mask ? { cellVisible: mask } : {}),
    });
  }, [mode, grid, colorBy, visible, cells, hiddenSources, hiddenLayers, filter]);
  const pixels = useMemo(() => section && theme ? buildSectionPixels(section,
    colorBy === "material" ? MAT_PAL : EV_PAL, colorBy === "event", filter, boundaries, theme.boundary) : null,
    [section, theme, colorBy, filter, boundaries]);

  const compiled = useMemo(() => compileTimeline(events, world, query), [events, world, query]);
  const metrics = useMemo(() => measureTransforms(compiled.ops, world), [compiled, world]);
  const invalidIds = useMemo(() => new Set(compiled.validations.filter((v) => !v.result.valid).map((v) => v.id)), [compiled]);

  const doInspect = useCallback((x: number, y: number, z: number) => {
    const ev = new GeologicalFieldEvaluator(compiled.ops, world);
    const h = new Float64Array(3 * (compiled.ops.length + 1));
    const s = ev.evaluate(x, y, z, newSample(), h);
    const stages = [];
    for (let i = 0; i <= compiled.ops.length; i++) {
      const hx = h[3 * i], hy = h[3 * i + 1], hz = h[3 * i + 2];
      stages.push({ label: compiled.events[i] ? `před ${compiled.events[i]?.name}` : "současnost",
        pos: hx !== undefined && hy !== undefined && hz !== undefined && Number.isFinite(hx + hy + hz) ? [hx, hy, hz] as [number, number, number] : null });
    }
    setInspect({ p: [x, y, z], materialId: s.materialId, sourceEventId: compiled.ops[s.sourceIndex]?.id ?? null,
      bodyId: null, layerIndex: s.layerIndex, flags: s.flags, stages });
    setTab("inspect");
  }, [compiled, world]);

  const update = (e: GeoEvent) => setEvents((es) => es.map((x) => (x.id === e.id ? e : x)));
  const move = (id: string, d: -1 | 1) => setEvents((es) => {
    const i = es.findIndex((e) => e.id === id), j = i + d;
    if (i < 0 || j < 0 || j >= es.length) return es;
    const a = es[i], b = es[j]; if (!a || !b) return es;
    const c = [...es]; c[i] = b; c[j] = a; return retime(c);
  });
  const add = (t: GeoEventType) => setEvents((es) => { const e = createEvent(t, nextId(es, t)); setSelectedId(e.id); return retime([...es, e]); });
  const loadScenario = (id: string) => { const s = SCENARIOS.find((x) => x.id === id); if (!s) return; setScenario(id); setEvents(s.build()); setIsolateId(null); setUpToIndex(null); setSelectedId(null); };
  const onImport = async (f: File) => {
    try { const r = importTimeline(JSON.parse(await f.text())); setWorld(r.world); setEvents(r.events); setMsg(`Načteno ${r.events.length} událostí.`); }
    catch (e) { setMsg((e as Error).message); }
  };
  const runTests = () => { setTesting(true); setTab("diag"); setTimeout(() => { setTests(runSuite()); setTesting(false); }, 30); };

  const selected = events.find((e) => e.id === selectedId) ?? null;
  const stats = {
    events: compiled.ops.length, samples: grid?.stats.samples ?? 0, evalMs: grid?.stats.evalMs ?? 0, meshMs: mesh?.ms ?? 0, renderMs,
    sectionMs: section?.evalMs ?? 0,
    dataBytes: (grid ? grid.material.byteLength + grid.source.byteLength + grid.layer.byteLength : 0) + (mesh ? mesh.positions.byteLength + mesh.normals.byteLength + mesh.colors.byteLength + mesh.indices.byteLength : 0)
      + (section ? section.material.byteLength + section.source.byteLength + section.layer.byteLength + (pixels?.byteLength ?? 0) : 0),
    materials: grid ? grid.stats.materialCounts.filter((c, i) => i > 0 && c > 0).length : 0,
    invalidTransforms: compiled.invalidCount, maxInverseError: metrics.maxInverseError, maxDisplacement: metrics.maxDisplacement,
    maxStrain: metrics.maxStrain, minDet: metrics.minJacobianDet, invalidCells: grid ? grid.stats.invalidCells + grid.stats.notConverged : 0,
    faces: mesh?.faces ?? 0, worker: client.current?.usingWorker ?? false, maxResidual: grid?.stats.maxResidual ?? 0,
  };
  const pickSection = useCallback((u: number, v: number) => {
    if (!section) return;
    const p = sectionPickPoint(world, section, u, v);
    doInspect(p.x, p.y, p.z);
  }, [section, world, doInspect]);
  useEffect(() => {
    if (!import.meta.env.DEV) return;
    const target = window as Window & { __geologyView?: () => unknown };
    target.__geologyView = () => ({ mode, axis: section?.axis, pos: section?.pos, width: section?.w,
      height: section?.h, gridResolution: grid?.res, sectionResolution: section ? 1 / section.pxPerM : null, inspect });
    return () => { delete target.__geologyView; };
  }, [mode, section, grid, inspect]);

  return (
    <div className="flex min-h-screen flex-col bg-background font-sans text-foreground lg:h-screen">
      <header className="flex flex-wrap items-center gap-x-4 gap-y-2 border-b border-border px-3 py-2">
        <div>
          <h1 className="font-mono text-sm font-semibold tracking-normal">WILLAGE · Geological Engine <span className="text-primary">v0</span></h1>
          <p className="font-mono text-[10px] text-muted-foreground">Y nahoru · X/Z vodorovně · metry · výpočet v prohlížeči (Web Worker)</p>
        </div>
        <Select label="Scénář" value={scenario} options={SCENARIOS.map((s) => ({ value: s.id, label: s.name }))} onChange={loadScenario} />
        <Select label="Objem" value={world.sizeX} options={WORLD_SIZES.map((s) => ({ value: s as number, label: `${s} m` }))} onChange={(v) => setWorld({ ...world, sizeX: v, sizeY: v, sizeZ: v })} />
        <Select label="Rozlišení 3D" value={res} options={RESOLUTIONS.map((r) => ({ value: r as number, label: `${r} m` }))} onChange={setRes} />
        <span className={`font-mono text-[10px] ${samples > 4e6 ? "text-destructive" : "text-muted-foreground"}`}>{samples.toLocaleString("cs")} vzorků{busy ? " · počítám…" : ""}</span>
        <div className="ml-auto flex flex-wrap gap-1">
          <Button variant="secondary" size="sm" className="lab-btn" onClick={() => download("willage-timeline.json", exportTimeline(events, world))}>Export JSON</Button>
          <label className="lab-btn cursor-pointer">Import JSON<input type="file" accept="application/json" className="hidden" onChange={(e) => e.target.files?.[0] && onImport(e.target.files[0])} /></label>
          <Button variant="secondary" size="sm" className="lab-btn" onClick={() => download("willage-golden-vectors.json", buildGoldenVectors())}>Golden vectors A–E</Button>
          <Button variant="secondary" size="sm" className="lab-btn" onClick={runTests}>Testy</Button>
        </div>
        {error && <span className="w-full font-mono text-[11px] text-destructive" role="alert">{error}</span>}
        {msg && <span className="w-full font-mono text-[10px] text-primary" onClick={() => setMsg(null)}>{msg}</span>}
      </header>

      <div className="flex flex-1 flex-col lg:grid lg:min-h-0 lg:grid-cols-[300px_1fr_340px]">
        <aside className="order-2 overflow-y-auto border-border p-3 lg:order-1 lg:border-r">
          <div className="lab-heading mb-2">Geologická časová osa</div>
          <TimelinePanel events={events} selectedId={selectedId} isolateId={isolateId} upToIndex={upToIndex} invalidIds={invalidIds}
            onSelect={(id) => { setSelectedId(id); setTab("params"); }} onToggle={(id) => setEvents((es) => es.map((e) => (e.id === id ? { ...e, enabled: !e.enabled } : e)))}
            onMove={move} onDelete={(id) => setEvents((es) => retime(es.filter((e) => e.id !== id)))} onIsolate={setIsolateId} onUpTo={setUpToIndex} onAdd={add} />
          {(isolateId || upToIndex !== null) && (
            <p className="mt-2 font-mono text-[10px] text-primary">
              {isolateId ? `Samostatný účinek: ${isolateId} (deformace na referenčních vodorovných vrstvách)` : `Stav po události ${(upToIndex ?? 0) + 1}`}
            </p>
          )}
        </aside>

        <main className="order-1 flex min-h-0 flex-col lg:order-2">
          <div className="flex flex-wrap items-center gap-1 border-b border-border px-2 py-1.5">
            <Button variant="secondary" size="sm" className={`lab-btn ${mode === "3d" ? "lab-btn-active" : ""}`} onClick={() => setMode("3d")}>3D povrch</Button>
            <Button variant="secondary" size="sm" className={`lab-btn ${mode === "2d" ? "lab-btn-active" : ""}`} onClick={() => setMode("2d")}>2D průřez</Button>
            <span className="mx-1 h-4 w-px bg-border" />
            <Button variant="secondary" size="sm" className={`lab-btn ${colorBy === "material" ? "lab-btn-active" : ""}`} onClick={() => setColorBy("material")}>barva: hornina</Button>
            <Button variant="secondary" size="sm" className={`lab-btn ${colorBy === "event" ? "lab-btn-active" : ""}`} onClick={() => setColorBy("event")}>barva: událost</Button>
            {mode === "3d" && <Button variant="secondary" size="sm" className={`lab-btn ${cells ? "lab-btn-active" : ""}`} onClick={() => setCells(!cells)}>voxelové buňky</Button>}
          </div>
          <div className="relative h-[58vh] min-h-[300px] lg:h-auto lg:flex-1">
            {mode === "3d" && theme ? (
              <Viewport3D mesh={mesh} world={world} res={res} theme={theme} onRendered={setRenderMs}
                section={showSection ? section : null} pixels={showSection ? pixels : null} cut={showSection && cut}
                onPickSection={pickSection}
                onPickCell={(i, j, k) => doInspect((i + 0.5) * res, (j + 0.5) * res, (k + 0.5) * res)} />
            ) : <CrossSection2D section={section} pixels={pixels} onPick={pickSection} />}
            {(!section && (mode === "2d" || showSection)) && <div className="pointer-events-none absolute inset-x-0 top-2 text-center font-mono text-xs text-muted-foreground">Počítám průřez…</div>}
          </div>
          <div className="grid gap-3 border-t border-border p-2 sm:grid-cols-2">
            <div className="space-y-2">
              <div className="lab-heading">Průřez</div>
              <Select label="Rovina průřezu" value={secAxis} onChange={setSecAxis}
                options={[{ value: "z", label: "Z = konst. (svislá)" }, { value: "x", label: "X = konst. (svislá)" }, { value: "y", label: "Y = konst. (vodorovná)" }]} />
              <Num label="Poloha řezu" value={safeSecPos} min={0} max={axisMax(secAxis)} step={sectionRes} unit="m" onChange={v => setSecPos(Math.max(0, Math.min(axisMax(secAxis), v)))} />
              <Select label="Rozlišení řezu" value={sectionRes} onChange={setSectionRes}
                options={[2, 1, 0.5, 0.25].map(r => ({ value: r, label: `${r} m` }))} />
              <div className="flex flex-wrap gap-2 text-[11px]">
                {mode === "3d" && <>
                  <label className="flex items-center gap-1"><input type="checkbox" checked={showSection} onChange={e => setShowSection(e.target.checked)} />Zobrazit řez</label>
                  <label className="flex items-center gap-1"><input type="checkbox" checked={cut} onChange={e => setCut(e.target.checked)} />Odkrýt vnitřek</label>
                </>}
                <label className="flex items-center gap-1"><input type="checkbox" checked={boundaries} onChange={e => setBoundaries(e.target.checked)} />Hranice vrstev</label>
              </div>
              {section && <div className="font-mono text-[10px] text-muted-foreground">{section.w} × {section.h} · {section.evalMs.toFixed(1)} ms</div>}
            </div>
            <div>
              <div className="lab-heading mb-1">Materiály (klik = skrýt, dvojklik = jen tento)</div>
              <div className="flex flex-wrap gap-1">
                {MATERIALS.filter((m) => m.id > 0).map((m) => {
                  const on = visible[m.id] === 1;
                  return (
                    <Button variant="secondary" size="sm" key={m.id} className={`lab-btn ${on ? "" : "opacity-40"}`} title={`ID ${m.id}`}
                      onClick={() => { setSolo(null); setHidden((h) => (h.includes(m.id) ? h.filter((x) => x !== m.id) : [...h, m.id])); }}
                      onDoubleClick={() => setSolo(solo === m.id ? null : m.id)}>
                      <i className="inline-block h-2.5 w-2.5" style={{ background: colorBy === "material" ? rgbCss(MAT_PAL, m.id) : m.color }} />{m.id} {m.name.split(" ")[0]}
                    </Button>
                  );
                })}
              </div>
            </div>
          </div>
          <div className="max-h-44 overflow-y-auto border-t border-border p-2">
            <div className="lab-heading mb-2">Viditelnost zdrojů a vrstev</div>
            <div className="space-y-2">
              {compiled.events.map((event, source) => event.type === "sedimentation" && <div key={event.id} className="flex flex-wrap items-center gap-1">
                <Button variant="ghost" size="sm" aria-label={`Zdroj ${event.name}`} aria-pressed={!hiddenSources.includes(source)}
                  className="h-7 font-mono text-[11px]" onClick={() => setHiddenSources(values => values.includes(source) ? values.filter(v => v !== source) : [...values, source])}>
                  {hiddenSources.includes(source) ? <EyeOff /> : <Eye />} {event.name}
                </Button>
                {event.params.layers.map((layer, index) => {
                  const key = `${source}:${index}`, shown = !hiddenLayers.includes(key) && !hiddenSources.includes(source);
                  return <Button key={index} variant="outline" size="sm" className={`h-7 font-mono text-[10px] ${shown ? "" : "opacity-40"}`}
                    aria-label={`${event.name}, vrstva ${index + 1}, materiál ${layer.materialId}`} aria-pressed={shown}
                    onClick={() => setHiddenLayers(values => values.includes(key) ? values.filter(v => v !== key) : [...values, key])}>
                    {shown ? <Eye /> : <EyeOff />} {index + 1} · {MATERIALS.find(m => m.id === layer.materialId)?.name ?? layer.materialId}
                  </Button>;
                })}
              </div>)}
            </div>
          </div>
        </main>

        <aside className="order-3 overflow-y-auto border-border p-3 lg:border-l">
          <div className="mb-3 flex gap-1">
            {([["params", "Parametry"], ["inspect", "Inspektor"], ["diag", "Diagnostika"]] as const).map(([k, l]) => (
              <Button variant="secondary" size="sm" key={k} className={`lab-btn flex-1 ${tab === k ? "lab-btn-active" : ""}`} onClick={() => setTab(k)}>{l}</Button>
            ))}
          </div>
          {tab === "params" && <ParameterPanel event={selected} onChange={update} validation={compiled.validations.find((v) => v.id === selectedId)?.result} />}
          {tab === "inspect" && <Inspector r={inspect} events={events} />}
          {tab === "diag" && <DiagnosticsPanel s={stats} tests={tests} running={testing} onRun={runTests} />}
        </aside>
      </div>
    </div>
  );
}
