import { describe, expect, it } from "vitest";
import { DEFAULT_WORLD } from "../../core/coordinates/world";
import { hashString } from "../../core/deterministic/hash";
import { buildGoldenVectors } from "../../diagnostics/golden/goldenVectors";
import { SCENARIOS } from "../../experiments/scenarios/scenarios";
import { GeologicalFieldEvaluator, newSample } from "../evaluator/evaluator";
import { compileTimeline, createEvent } from "../timeline/timeline";
import { sampleGrid, sampleSection } from "../../voxel/sampling/sampleGrid";
import { sectionCorners, sectionPickPoint } from "../../voxel/sampling/sectionCoordinates";
import { sampleVisible } from "../../visualization/cross-section/sectionDisplay";

const scenario = SCENARIOS.find(s => s.id === "E");
if (!scenario) throw new Error("Missing E");
const events = scenario.build();

describe("Visualization A numerical contracts", () => {
  it("preserves the pre-change v0 golden vectors exactly", () => {
    expect(hashString(JSON.stringify(buildGoldenVectors(16)))).toBe(881396785);
  });
  for (const axis of ["x", "y", "z"] as const) {
    it(`direct ${axis.toUpperCase()} section matches evaluator material, source and layer`, () => {
      const section = sampleSection(events, DEFAULT_WORLD, axis, 23.375, 0.5);
      const ev = new GeologicalFieldEvaluator(compileTimeline(events, DEFAULT_WORLD).ops, DEFAULT_WORLD);
      for (let row = 0; row < section.h; row++) for (let col = 0; col < section.w; col++) {
        // Independent expected coordinates, not the shared implementation under test.
        const u = (col + 0.5) * 2, v = 64 - (row + 0.5) * 2;
        const p = axis === "x" ? { x: 23.375, y: v, z: u }
          : axis === "z" ? { x: u, y: v, z: 23.375 } : { x: u, y: 23.375, z: 64 - v };
        const result = ev.evaluate(p.x, p.y, p.z, newSample());
        const i = col + row * section.w;
        expect(section.material[i]).toBe(result.materialId);
        expect(section.source[i]).toBe(result.sourceIndex < 0 ? 255 : result.sourceIndex);
        expect(section.layer[i]).toBe(result.layerIndex);
        expect(result.bodyId).toBeNull();
      }
    });
  }
  it("maps the same raster centre to exact X/Y/Z coordinates for both views", () => {
    const base = { w: 256, h: 256, pxPerM: 4, pos: 23.375 };
    expect(sectionPickPoint(DEFAULT_WORLD, { ...base, axis: "x" }, 0, 0)).toEqual({ x: 23.375, y: 63.875, z: 0.125 });
    expect(sectionPickPoint(DEFAULT_WORLD, { ...base, axis: "z" }, 1, 1)).toEqual({ x: 63.875, y: 0.125, z: 23.375 });
    expect(sectionPickPoint(DEFAULT_WORLD, { ...base, axis: "y" }, 0, 0)).toEqual({ x: 0.125, y: 23.375, z: 0.125 });
    expect(sectionCorners(DEFAULT_WORLD, "y", 23.375)).toEqual([0, 23.375, 0, 64, 23.375, 0, 64, 23.375, 64, 0, 23.375, 64]);
  });
  it("offers 2/1/0.5/0.25m sections independently of a 2m grid", () => {
    const grid = sampleGrid(events, DEFAULT_WORLD, 2);
    expect(grid.nx).toBe(32);
    for (const resolution of [2, 1, 0.5, 0.25]) {
      const section = sampleSection(events, DEFAULT_WORLD, "z", 32.375, 1 / resolution);
      expect(section.w).toBe(64 / resolution);
      expect(section.pos).toBe(32.375);
      expect(section.pxPerM).toBe(1 / resolution);
    }
  });
  it("can hide one source layer without hiding another layer of the same material", () => {
    const material = new Uint8Array(256); material[2] = 1;
    const filter = { visible: material, hiddenSources: [], hiddenLayers: ["0:1"] };
    expect(sampleVisible(2, 0, 1, filter)).toBe(false);
    expect(sampleVisible(2, 0, 2, filter)).toBe(true);
    expect(sampleVisible(2, 1, 1, filter)).toBe(true);
    expect(sampleVisible(2, 0, 2, { ...filter, hiddenSources: [0] })).toBe(false);
  });
  it("does not modify the original stored events while sampling", () => {
    const e = createEvent("sedimentation", "unchanged");
    const before = JSON.stringify(e);
    sampleSection([e], DEFAULT_WORLD, "y", 12.375, 0.5);
    expect(JSON.stringify(e)).toBe(before);
    expect(e.algorithmVersion).toBe(1);
  });
});