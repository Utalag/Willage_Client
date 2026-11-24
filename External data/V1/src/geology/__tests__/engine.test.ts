import { describe, expect, it } from "vitest";
import { DEFAULT_WORLD } from "@/core/coordinates/world";
import { BRECCIA, CONGLOMERATE, SHALE, AIR, BASEMENT } from "@/core/materials/materials";
import { SedimentationOperation } from "@/geology/events/material/sedimentation";
import { FoldingOperation } from "@/geology/events/deformation/folding";
import { FaultOperation } from "@/geology/events/deformation/fault";
import { makeTestTransformation } from "@/geology/events/transformation/transformation";
import type { FaultEvent, FoldEvent, SedimentationEvent } from "@/geology/events/types";
import { GeologicalFieldEvaluator, newSample } from "@/geology/evaluator/evaluator";
import { contextFor } from "@/geology/operations/compile";
import { compileTimeline, createEvent } from "@/geology/timeline/timeline";
import { exportTimeline, importTimeline } from "@/geology/timeline/serialization";
import { SCENARIOS } from "@/experiments/scenarios/scenarios";
import { runSuite } from "@/diagnostics/tests/suite";
import { buildGoldenVectors } from "@/diagnostics/golden/goldenVectors";

const ctx = contextFor(DEFAULT_WORLD);
const A = SCENARIOS[0]!.build();

describe("SedimentationOperation", () => {
  const op = new SedimentationOperation(A[0] as SedimentationEvent, ctx);
  it("orders interfaces monotonically (no negative thickness)", () => {
    for (let n = 0; n < 200; n++) {
      const f = op.interfaces(n * 0.31, n * 0.17);
      for (let i = 1; i < f.length; i++) expect(f[i]!).toBeGreaterThanOrEqual(f[i - 1]!);
    }
  });
  it("bottom layer is conglomerate, top is shale, has 5 layers", () => {
    const f = op.interfaces(10, 10);
    expect(f.length).toBe(6);
    expect(op.materialOf(op.classify(10, (f[0]! + f[1]!) / 2, 10))).toBe(CONGLOMERATE);
    expect(op.materialOf(op.classify(10, (f[4]! + f[5]!) / 2, 10))).toBe(SHALE);
  });
  it("interfaces are not flat", () => {
    expect(Math.abs(op.interfaces(5, 5)[2]! - op.interfaces(50, 40)[2]!)).toBeGreaterThan(0.1);
  });
});

describe("FoldingOperation", () => {
  const ev = createEvent("fold", "f") as FoldEvent;
  it("analytic inverse is exact", () => {
    const op = new FoldingOperation(ev, ctx);
    const a = { x: 3.3, y: 20.1, z: 7.7 }, b = { x: 0, y: 0, z: 0 }, c = { x: 0, y: 0, z: 0 };
    op.forward(a, b); op.inverse(b, c);
    expect(Math.abs(c.y - a.y)).toBeLessThan(1e-12);
    expect(op.isInvertible()).toBe(true);
  });
  it("numerical inverse converges within tolerance when gamma != 0", () => {
    const e2 = structuredClone(ev); e2.params.depthGradient = 0.03;
    const op = new FoldingOperation(e2, ctx);
    const a = { x: 11, y: 40, z: 3 }, b = { x: 0, y: 0, z: 0 }, c = { x: 0, y: 0, z: 0 };
    op.forward(a, b);
    const r = op.inverse(b, c);
    expect(r.converged).toBe(true);
    expect(Math.abs(c.y - a.y)).toBeLessThan(1e-6);
  });
  it("clamps amplitude to A*k <= 1.2 and keeps det J > 0", () => {
    const e3 = structuredClone(ev); e3.params.amplitude = 100; e3.params.wavelength = 10;
    const op = new FoldingOperation(e3, ctx);
    expect(op.A).toBeCloseTo((1.2 * 10) / (2 * Math.PI), 6);
    expect(op.validate().warnings.length).toBeGreaterThan(0);
    expect(op.evaluateJacobian({ x: 1, y: 1, z: 1 }, new Float64Array(9))).toBeGreaterThan(0);
  });
});

describe("FaultOperation", () => {
  const ev = createEvent("fault", "x") as FaultEvent;
  it("hanging wall (positive side) moves, footwall does not; inverse exact", () => {
    const op = new FaultOperation(ev);
    const hw = { x: 32 + op.n.x * 5, y: 24 + op.n.y * 5, z: 32 + op.n.z * 5 };
    const out = { x: 0, y: 0, z: 0 }, back = { x: 0, y: 0, z: 0 };
    op.forward(hw, out);
    expect(out.y).toBeLessThan(hw.y); // normal fault: hanging wall down
    op.inverse(out, back);
    expect(Math.hypot(back.x - hw.x, back.y - hw.y, back.z - hw.z)).toBeLessThan(1e-12);
    const fw = { x: 32 - op.n.x * 5, y: 24 - op.n.y * 5, z: 32 - op.n.z * 5 };
    op.forward(fw, out);
    expect(out).toEqual(fw);
  });
  it("slip lies in the plane", () => {
    const op = new FaultOperation(ev);
    expect(Math.abs(op.n.x * op.slip.x + op.n.y * op.slip.y + op.n.z * op.slip.z)).toBeLessThan(1e-12);
  });
  it("damage zone produces breccia", () => {
    const D = SCENARIOS[3]!.build();
    const e = new GeologicalFieldEvaluator(compileTimeline(D, DEFAULT_WORLD).ops, DEFAULT_WORLD);
    expect(e.evaluate(32, 24, 32, newSample()).materialId).toBe(BRECCIA);
  });
});

describe("Evaluator", () => {
  it("air above, basement below", () => {
    const e = new GeologicalFieldEvaluator(compileTimeline(A, DEFAULT_WORLD).ops, DEFAULT_WORLD);
    expect(e.evaluate(10, 63, 10, newSample()).materialId).toBe(AIR);
    expect(e.evaluate(10, 1, 10, newSample()).materialId).toBe(BASEMENT);
  });
  it("records historical positions p0..pN", () => {
    const D = SCENARIOS[3]!.build();
    const { ops } = compileTimeline(D, DEFAULT_WORLD);
    const h = new Float64Array(3 * (ops.length + 1));
    new GeologicalFieldEvaluator(ops, DEFAULT_WORLD).evaluate(50, 30, 50, newSample(), h);
    expect(h[3 * ops.length + 1]).toBe(30);
    expect(Number.isFinite(h[1]!)).toBe(true);
  });
  it("transformation hook receives position at transformation time", () => {
    const { ops } = compileTimeline(A, DEFAULT_WORLD);
    const t = makeTestTransformation("t", (m, _x, y) => (y < 20 && m !== AIR ? BASEMENT : m));
    const e = new GeologicalFieldEvaluator([...ops, t], DEFAULT_WORLD);
    expect(e.evaluate(10, 15, 10, newSample()).materialId).toBe(BASEMENT);
  });
});

describe("Serialization", () => {
  it("round-trips versioned JSON", () => {
    const doc = JSON.parse(JSON.stringify(exportTimeline(A, DEFAULT_WORLD)));
    expect(doc.schemaVersion).toBe(1);
    expect(importTimeline(doc).events).toEqual(A);
    expect(() => importTimeline({ ...doc, schemaVersion: 99 })).toThrow();
  });
  it("golden vectors are reproducible", () => {
    expect(JSON.stringify(buildGoldenVectors(16))).toBe(JSON.stringify(buildGoldenVectors(16)));
  });
});

describe("In-app diagnostic suite", () => {
  const results = runSuite();
  for (const r of results) it(r.name, () => expect(r.passed, r.detail).toBe(true));
});
