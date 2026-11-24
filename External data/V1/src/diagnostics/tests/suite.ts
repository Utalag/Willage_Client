import { DEFAULT_WORLD, type WorldConfig } from "../../core/coordinates/world";
import { hashInt3 } from "../../core/deterministic/hash";
import { fbm2 } from "../../core/deterministic/noise";
import { AIR, BRECCIA } from "../../core/materials/materials";
import { SCENARIOS } from "../../experiments/scenarios/scenarios";
import { FaultOperation } from "../../geology/events/deformation/fault";
import { FoldingOperation } from "../../geology/events/deformation/folding";
import type { FaultEvent, FoldEvent, GeoEvent, SedimentationEvent } from "../../geology/events/types";
import { GeologicalFieldEvaluator, newSample } from "../../geology/evaluator/evaluator";
import { contextFor } from "../../geology/operations/compile";
import { compileTimeline, createEvent } from "../../geology/timeline/timeline";
import { sampleGrid } from "../../voxel/sampling/sampleGrid";
import { measureTransforms } from "../profiler/metrics";

export interface TestResult { id: string; name: string; passed: boolean; detail: string; ms: number }
export const INVERSE_TOLERANCE = 1e-6;

const scen = (id: string) => SCENARIOS.find((s) => s.id === id)!.build();
const evaluatorFor = (events: GeoEvent[], world: WorldConfig = DEFAULT_WORLD) =>
  new GeologicalFieldEvaluator(compileTimeline(events, world).ops, world);
const pt = (n: number, a: number, size: number) => (hashInt3(n, a, 7, 0xbeef) / 4294967296) * size;
function fnv(a: Uint8Array) {
  let h = 0x811c9dc5;
  for (let i = 0; i < a.length; i++) h = Math.imul(h ^ a[i]!, 0x01000193);
  return h >>> 0;
}

type T = () => { passed: boolean; detail: string };
const TESTS: { id: string; name: string; fn: T }[] = [
  {
    id: "determinism", name: "1. Determinismus",
    fn: () => {
      const ev = scen("E");
      const g1 = sampleGrid(ev, DEFAULT_WORLD, 2), g2 = sampleGrid(scen("E"), DEFAULT_WORLD, 2);
      const h1 = fnv(g1.material), h2 = fnv(g2.material);
      // order independence: forward vs reversed evaluation order with a fresh evaluator
      const e1 = evaluatorFor(ev), e2 = evaluatorFor(ev), s = newSample();
      const N = 2000, fw = new Uint8Array(N), bw = new Uint8Array(N);
      for (let n = 0; n < N; n++) fw[n] = e1.evaluate(pt(n, 1, 64), pt(n, 2, 64), pt(n, 3, 64), s).materialId;
      for (let n = N - 1; n >= 0; n--) bw[n] = e2.evaluate(pt(n, 1, 64), pt(n, 2, 64), pt(n, 3, 64), s).materialId;
      const orderOk = fnv(fw) === fnv(bw);
      return { passed: h1 === h2 && orderOk, detail: `hash mřížky ${h1.toString(16)} / ${h2.toString(16)}; pořadí vzorkování ${orderOk ? "neovlivňuje" : "OVLIVŇUJE"} výsledek (${N} bodů)` };
    },
  },
  {
    id: "inverse", name: "2. Inverzní transformace",
    fn: () => {
      let worst = 0;
      for (const sc of SCENARIOS) worst = Math.max(worst, measureTransforms(compileTimeline(sc.build(), DEFAULT_WORLD).ops, DEFAULT_WORLD).maxInverseError);
      const g = createEvent("fold", "fold-num") as FoldEvent;
      g.params.depthGradient = 0.02; g.params.amplitude = 4;
      const num = measureTransforms([new FoldingOperation(g, contextFor(DEFAULT_WORLD))], DEFAULT_WORLD).maxInverseError;
      worst = Math.max(worst, num);
      return { passed: worst < INVERSE_TOLERANCE, detail: `max |F(F⁻¹(p))−p| = ${worst.toExponential(2)} m (tolerance ${INVERSE_TOLERANCE}); numerická inverze (γ≠0): ${num.toExponential(2)} m` };
    },
  },
  {
    id: "jacobian", name: "3. Jacobian (bez překrytí)",
    fn: () => {
      const g = createEvent("fold", "fold-ext") as FoldEvent;
      g.params.amplitude = 50; g.params.wavelength = 10; g.params.depthGradient = 0.5;
      const op = new FoldingOperation(g, contextFor(DEFAULT_WORLD));
      let minDet = measureTransforms([op], DEFAULT_WORLD, 13).minJacobianDet;
      for (const sc of SCENARIOS) minDet = Math.min(minDet, measureTransforms(compileTimeline(sc.build(), DEFAULT_WORLD).ops, DEFAULT_WORLD).minJacobianDet);
      // monotone column check in 3D: layer order never reverses along +Y in folded scenario C
      const ev = evaluatorFor(scen("C")), s = newSample();
      let reversals = 0;
      for (let c = 0; c < 400; c++) {
        const x = pt(c, 4, 64), z = pt(c, 5, 64);
        let last = -1;
        for (let y = 0.25; y < 64; y += 0.25) {
          ev.evaluate(x, y, z, s);
          if (s.layerIndex >= 0) { if (s.layerIndex < last) reversals++; last = s.layerIndex; }
        }
      }
      return { passed: minDet > 0 && reversals === 0, detail: `min det J = ${minDet.toFixed(4)} (extrémní parametry omezeny: A=${op.A.toFixed(2)}, γ=${op.gamma.toExponential(2)}); obrácení pořadí vrstev v 400 sloupcích: ${reversals}` };
    },
  },
  {
    id: "periodicity", name: "4. Periodicita (torus X/Z)",
    fn: () => {
      const world: WorldConfig = { ...DEFAULT_WORLD, periodicX: true, periodicZ: true };
      const ev = scen("C"); // sedimentation + two folds (faults are not periodic in v0)
      const e = evaluatorFor(ev, world), s = newSample();
      let mism = 0, noiseErr = 0;
      for (let n = 0; n < 1500; n++) {
        const x = pt(n, 1, 64), y = pt(n, 2, 64), z = pt(n, 3, 64);
        const a = e.evaluate(x, y, z, s).materialId;
        const b = e.evaluate(x + 64, y, z - 128, s).materialId;
        if (a !== b) mism++;
        noiseErr = Math.max(noiseErr, Math.abs(fbm2(x, z, 9, 0.03, 3, 64, 64) - fbm2(x + 64, z + 64, 9, 0.03, 3, 64, 64)));
      }
      // also unwrapped fold periodicity (no coordinate wrapping): F(x) == F(x+P)
      const f = new FoldingOperation((scen("C")[2] as FoldEvent), contextFor(world));
      const fErr = Math.abs(f.F(10.3, 20.7) - f.F(74.3, 84.7));
      return { passed: mism === 0 && noiseErr < 1e-9 && fErr < 1e-9, detail: `Sample(x)≠Sample(x+P): ${mism}/1500; max šum Δ = ${noiseErr.toExponential(1)}; vrása F Δ = ${fErr.toExponential(1)}` };
    },
  },
  {
    id: "chronology", name: "5. Chronologie",
    fn: () => {
      const d = scen("D");
      const fault = new FaultOperation(d[2] as FaultEvent);
      const withF = evaluatorFor(d), noF = evaluatorFor(d.slice(0, 2)), s = newSample();
      let bad = 0, checked = 0;
      for (let n = 0; n < 1500; n++) {
        const x = pt(n, 1, 64), y = pt(n, 2, 64), z = pt(n, 3, 64);
        const m = withF.evaluate(x, y, z, s);
        if (m.materialId === BRECCIA) continue;
        const hw = fault.side(x, y, z) > 0;
        const q = hw ? { x: x - fault.slip.x, y: y - fault.slip.y, z: z - fault.slip.z } : { x, y, z };
        const ref = noF.evaluate(q.x, q.y, q.z, newSample()).materialId;
        checked++;
        if (ref !== m.materialId) bad++;
      }
      // order matters: fold→fault vs fault→fold differ
      const swapped = [d[0]!, d[2]!, d[1]!];
      const ga = sampleGrid(d, DEFAULT_WORLD, 2).material, gb = sampleGrid(swapped, DEFAULT_WORLD, 2).material;
      let diff = 0;
      for (let i = 0; i < ga.length; i++) if (ga[i] !== gb[i]) diff++;
      // younger sedimentation (E) overlies: above its erosion base everything is from event 4
      const e = evaluatorFor(scen("E"));
      let younger = 0;
      for (let n = 0; n < 300; n++) { e.evaluate(pt(n, 1, 64), 48, pt(n, 3, 64), s); if (s.sourceIndex === 4 || s.materialId === AIR) younger++; }
      return { passed: bad === 0 && diff > 0 && younger === 300, detail: `zlom = posun starší struktury: ${bad} chyb z ${checked}; změna pořadí změnila ${diff} buněk; pokryv E na y=48: ${younger}/300` };
    },
  },
  {
    id: "continuity", name: "6. Spojitost vrstev",
    fn: () => {
      // top of layer 2 as height field on a 1 m column grid; max neighbour jump
      const jump = (events: GeoEvent[]) => {
        const e = evaluatorFor(events), s = newSample();
        const top = new Float64Array(64 * 64);
        for (let i = 0; i < 64; i++) for (let k = 0; k < 64; k++) {
          let h = NaN;
          for (let y = 63.9; y > 0; y -= 0.1) { e.evaluate(i + 0.5, y, k + 0.5, s); if (s.sourceIndex === 0 && s.layerIndex <= 2 && s.materialId !== BRECCIA) { h = y; break; } }
          top[i + 64 * k] = h;
        }
        let m = 0;
        for (let i = 0; i < 63; i++) for (let k = 0; k < 64; k++) {
          const d = Math.abs(top[i + 1 + 64 * k]! - top[i + 64 * k]!);
          if (Number.isFinite(d)) m = Math.max(m, d); // columns entirely inside the damage zone are skipped
        }
        return m;
      };
      const d = scen("D");
      // near-vertical variant of the D fault: a dipping fault makes the interface follow the plane
      // (kinked, not a step), a vertical one gives a pure step equal to the throw.
      const vf = structuredClone(d[2]!) as FaultEvent; vf.params.dipDeg = 90; vf.params.damageWidth = 0;
      const jC = jump(scen("C")), jD = jump([d[0]!, vf]);
      return { passed: jC < 3 && jD > 5, detail: `max skok rozhraní mezi sousedními sloupci: bez zlomu (C) ${jC.toFixed(2)} m; sedimentace + svislý zlom (posun 9 m) ${jD.toFixed(2)} m (nespojitost jen na zlomu)` };
    },
  },
  {
    id: "resolution", name: "7. Nezávislost na rozlišení",
    fn: () => {
      const ev = scen("D");
      const g2 = sampleGrid(ev, DEFAULT_WORLD, 2), g1 = sampleGrid(ev, DEFAULT_WORLD, 1);
      const e = evaluatorFor(ev), s = newSample();
      let pointMism = 0;
      for (let n = 0; n < 500; n++) {
        const i = n % g2.nx, j = (n * 7) % g2.ny, k = (n * 13) % g2.nz;
        if (e.evaluate((i + 0.5) * 2, (j + 0.5) * 2, (k + 0.5) * 2, s).materialId !== g2.material[i + g2.nx * (j + g2.ny * k)]) pointMism++;
      }
      let maxFrac = 0;
      for (let m = 0; m < 8; m++) maxFrac = Math.max(maxFrac, Math.abs(g2.stats.materialCounts[m]! / g2.stats.samples - g1.stats.materialCounts[m]! / g1.stats.samples));
      return { passed: pointMism === 0 && maxFrac < 0.02, detail: `buňka = funkce ve středu: ${pointMism} rozdílů; max rozdíl objemového podílu materiálu 2 m vs 1 m: ${(maxFrac * 100).toFixed(2)} %` };
    },
  },
];

export function runSuite(): TestResult[] {
  return TESTS.map((t) => {
    const t0 = performance.now();
    try {
      const r = t.fn();
      return { id: t.id, name: t.name, ...r, ms: performance.now() - t0 };
    } catch (e) {
      return { id: t.id, name: t.name, passed: false, detail: `Výjimka: ${(e as Error).message}`, ms: performance.now() - t0 };
    }
  });
}
export type { SedimentationEvent };
