import { DEFAULT_WORLD } from "../../core/coordinates/world";
import { hashInt3 } from "../../core/deterministic/hash";
import { SCENARIOS } from "../../experiments/scenarios/scenarios";
import { GeologicalFieldEvaluator, newSample } from "../../geology/evaluator/evaluator";
import { compileTimeline } from "../../geology/timeline/timeline";
import { exportTimeline, SCHEMA_VERSION } from "../../geology/timeline/serialization";

/**
 * Golden vectors for porting (C#/Godot). Points: deterministic integer-hash lattice
 * (no Math.random), snapped to 1/1024 m so they are exact in binary floating point.
 * history[i] = position before event i (p_i), history[N] = present (p_N).
 */
export function buildGoldenVectors(pointsPerScenario = 64) {
  const world = DEFAULT_WORLD;
  return {
    schemaVersion: SCHEMA_VERSION,
    note: "Repeatability on one machine only; bit-exact cross-platform match is not guaranteed (float64 transcendental functions).",
    scenarios: SCENARIOS.map((sc) => {
      const events = sc.build();
      const { ops } = compileTimeline(events, world);
      const ev = new GeologicalFieldEvaluator(ops, world);
      const s = newSample();
      const hist = new Float64Array(3 * (ops.length + 1));
      const points = [];
      for (let n = 0; n < pointsPerScenario; n++) {
        const q = (a: number, size: number) => Math.round((hashInt3(n, a, 0, 0x601d) / 4294967296) * size * 1024) / 1024;
        const x = q(1, world.sizeX), y = q(2, world.sizeY), z = q(3, world.sizeZ);
        ev.evaluate(x, y, z, s, hist);
        const history = [];
        for (let i = 0; i <= ops.length; i++) {
          const hx = hist[3 * i]!;
          history.push(Number.isNaN(hx) ? null : [hx, hist[3 * i + 1]!, hist[3 * i + 2]!]);
        }
        points.push({ p: [x, y, z], materialId: s.materialId, sourceEventId: s.sourceIndex >= 0 ? ops[s.sourceIndex]!.id : null, layerIndex: s.layerIndex, flags: s.flags, history });
      }
      return { scenario: sc.id, timeline: exportTimeline(events, world), points };
    }),
  };
}
