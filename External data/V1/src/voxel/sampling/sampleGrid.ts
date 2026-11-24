import { cellCenter, gridDims, type WorldConfig } from "../../core/coordinates/world";
import { GeologicalFieldEvaluator, FLAG_INVALID, FLAG_NOT_CONVERGED, newSample } from "../../geology/evaluator/evaluator";
import type { GeoEvent } from "../../geology/events/types";
import { compileTimeline, type TimelineQuery } from "../../geology/timeline/timeline";
import { sectionPixelPoint, sectionSize, type SectionAxis } from "./sectionCoordinates";
export type { SectionAxis } from "./sectionCoordinates";

export const SOURCE_NONE_U8 = 255;

export interface GridResult {
  nx: number; ny: number; nz: number; res: number;
  /** index = i + nx·(j + ny·k); i→X, j→Y (up), k→Z */
  material: Uint8Array;
  /** compiled op index of producing material event, 255 = none */
  source: Uint8Array;
  /** Snapshot-local sedimentary layer index, not a stable body identifier. */
  layer: Int32Array;
  stats: {
    samples: number;
    evalMs: number;
    maxResidual: number;
    invalidCells: number;
    notConverged: number;
    materialCounts: number[];
  };
}

/** Point sampling at cell centres. The geological function is resolution independent; res only sets density. */
export function sampleGrid(events: GeoEvent[], world: WorldConfig, res: number, q: TimelineQuery = {}): GridResult {
  const t0 = performance.now();
  const { ops } = compileTimeline(events, world, q);
  const ev = new GeologicalFieldEvaluator(ops, world);
  const { nx, ny, nz } = gridDims(world, res);
  const N = nx * ny * nz;
  const material = new Uint8Array(N);
  const source = new Uint8Array(N);
  const layer = new Int32Array(N);
  const s = newSample();
  const counts = new Array<number>(256).fill(0);
  let maxResidual = 0, invalid = 0, nc = 0;
  // Y (vertical) innermost: consecutive samples share the column (x,z) so interface caches hit.
  for (let k = 0; k < nz; k++) {
    const z = cellCenter(k, res);
    for (let i = 0; i < nx; i++) {
      const x = cellCenter(i, res);
      for (let j = 0; j < ny; j++) {
        ev.evaluate(x, cellCenter(j, res), z, s);
        const idx = i + nx * (j + ny * k);
        material[idx] = s.materialId;
        source[idx] = s.sourceIndex < 0 ? SOURCE_NONE_U8 : s.sourceIndex;
        layer[idx] = s.layerIndex;
        counts[s.materialId]!++;
        if (s.maxResidual > maxResidual) maxResidual = s.maxResidual;
        if (s.flags & FLAG_INVALID) invalid++;
        if (s.flags & FLAG_NOT_CONVERGED) nc++;
      }
    }
  }
  return {
    nx, ny, nz, res, material, source, layer,
    stats: { samples: N, evalMs: performance.now() - t0, maxResidual, invalidCells: invalid, notConverged: nc, materialCounts: counts.slice(0, 16) },
  };
}

export interface SectionResult { w: number; h: number; axis: SectionAxis; pos: number; pxPerM: number; material: Uint8Array; source: Uint8Array; layer: Int32Array; evalMs: number }

/**
 * Direct evaluation of an axis-aligned plane (no voxel grid). Pixel (u,v), v=0 at top.
 * axis x: vertical plane x=pos, u=z, v=y · axis z: vertical plane z=pos, u=x, v=y
 * axis y: horizontal plane y=pos, u=x, v=z (map view)
 */
export function sampleSection(events: GeoEvent[], world: WorldConfig, axis: SectionAxis, pos: number, pxPerM: number, q: TimelineQuery = {}): SectionResult {
  const t0 = performance.now();
  const { ops } = compileTimeline(events, world, q);
  const ev = new GeologicalFieldEvaluator(ops, world);
  const { u: uSize, v: vSize } = sectionSize(world, axis);
  const w = Math.round(uSize * pxPerM), h = Math.round(vSize * pxPerM);
  const material = new Uint8Array(w * h), source = new Uint8Array(w * h);
  const layer = new Int32Array(w * h);
  const s = newSample();
  const p = { x: 0, y: 0, z: 0 };
  for (let u = 0; u < w; u++) {
    for (let v = 0; v < h; v++) {
      sectionPixelPoint(world, axis, pos, u, v, pxPerM, p);
      ev.evaluate(p.x, p.y, p.z, s);
      material[u + w * v] = s.materialId;
      source[u + w * v] = s.sourceIndex < 0 ? SOURCE_NONE_U8 : s.sourceIndex;
      layer[u + w * v] = s.layerIndex;
    }
  }
  return { w, h, axis, pos, pxPerM, material, source, layer, evalMs: performance.now() - t0 };
}
