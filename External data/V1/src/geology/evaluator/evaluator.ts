import { wrapCoord, type WorldConfig } from "../../core/coordinates/world";
import { AIR, BASEMENT, BRECCIA } from "../../core/materials/materials";
import type { Vec3 } from "../../core/math/vec3";
import type { GeoOperation, TransformationOperation } from "../events/types";

export const FLAG_DAMAGE = 1;
export const FLAG_INVALID = 2;
export const FLAG_NOT_CONVERGED = 4;
export const SOURCE_NONE = -1;

/** Reusable sample record – the evaluator never allocates per sample. */
export interface GeoSample {
  /** Stable body identity is unavailable in v0; never infer it from source/layer indices. */
  bodyId: null;
  materialId: number;
  layerIndex: number;
  /** Index of the material event (in compiled ops) that produced the material; -1 = basement/air. */
  sourceIndex: number;
  flags: number;
  maxResidual: number;
  iterations: number;
}
export const newSample = (): GeoSample => ({ bodyId: null, materialId: 0, layerIndex: -1, sourceIndex: -1, flags: 0, maxResidual: 0, iterations: 0 });

/**
 * Geological Field Evaluator – point query without generating the world.
 * Backward reconstruction pN → pN-1 → … → p0: walk events from youngest to oldest,
 * applying each deformation's inverse; the first material event that owns the
 * point decides the material at the point's deposition-time coordinates.
 */
export class GeologicalFieldEvaluator {
  private readonly tin: Vec3 = { x: 0, y: 0, z: 0 };
  private readonly tout: Vec3 = { x: 0, y: 0, z: 0 };
  /** pending transformations: op index + position at transformation time */
  private readonly tIdx: Int32Array;
  private readonly tPos: Float64Array;
  private tCount = 0;
  private hist: Float64Array | null = null;

  constructor(readonly ops: GeoOperation[], readonly world: WorldConfig) {
    this.tIdx = new Int32Array(ops.length + 1);
    this.tPos = new Float64Array(3 * (ops.length + 1));
  }

  /**
   * @param history optional Float64Array(3·(N+1)); stage i = position before event i,
   *                stage N = present position. Unvisited stages are NaN.
   */
  evaluate(x: number, y: number, z: number, out: GeoSample, history: Float64Array | null = null): GeoSample {
    if (this.world.periodicX) x = wrapCoord(x, this.world.sizeX);
    if (this.world.periodicZ) z = wrapCoord(z, this.world.sizeZ);
    out.flags = 0;
    out.maxResidual = 0;
    out.iterations = 0;
    this.tCount = 0;
    this.hist = history;
    if (history) {
      history.fill(NaN);
      const n = this.ops.length;
      history[3 * n] = x; history[3 * n + 1] = y; history[3 * n + 2] = z;
    }
    this.walk(this.ops.length - 1, x, y, z, false, out);
    if (!Number.isFinite(x + y + z)) out.flags |= FLAG_INVALID;
    return out;
  }

  private finish(out: GeoSample, mat: number, layer: number, src: number, damage: boolean) {
    if (damage && mat !== AIR) {
      mat = BRECCIA;
      out.flags |= FLAG_DAMAGE;
    }
    // apply pending transformations chronologically (oldest first = last recorded)
    for (let t = this.tCount - 1; t >= 0 && mat !== AIR; t--) {
      const op = this.ops[this.tIdx[t]!] as TransformationOperation;
      mat = op.transform(mat, this.tPos[3 * t]!, this.tPos[3 * t + 1]!, this.tPos[3 * t + 2]!);
    }
    out.materialId = mat;
    out.layerIndex = layer;
    out.sourceIndex = src;
  }

  private walk(start: number, px: number, py: number, pz: number, damage: boolean, out: GeoSample): void {
    for (let i = start; i >= 0; i--) {
      const op = this.ops[i]!;
      if (op.kind === "deformation") {
        if (op.damageAt && op.damageAt(px, py, pz)) damage = true;
        this.tin.x = px; this.tin.y = py; this.tin.z = pz;
        const r = op.inverse(this.tin, this.tout);
        px = this.tout.x; py = this.tout.y; pz = this.tout.z;
        if (r.residual > out.maxResidual) out.maxResidual = r.residual;
        out.iterations += r.iterations;
        if (!r.converged) out.flags |= FLAG_NOT_CONVERGED;
        if (!Number.isFinite(pz)) { out.flags |= FLAG_INVALID; this.finish(out, AIR, -1, SOURCE_NONE, false); return; }
      } else if (op.kind === "transformation") {
        const t = this.tCount++;
        this.tIdx[t] = i;
        this.tPos[3 * t] = px; this.tPos[3 * t + 1] = py; this.tPos[3 * t + 2] = pz;
      } else {
        if (this.hist) { this.hist[3 * i] = px; this.hist[3 * i + 1] = py; this.hist[3 * i + 2] = pz; }
        const L = op.classify(px, py, pz);
        if (L >= 0) {
          if (op.mode === "onlap") {
            const saved = this.tCount;
            this.walk(i - 1, px, py, pz, damage, out);
            this.tCount = saved;
            if (out.materialId !== AIR) return;
          }
          this.finish(out, op.materialOf(L), L, i, damage);
          return;
        }
        if (L === -2 && op.mode === "erode") { this.finish(out, AIR, -1, SOURCE_NONE, false); return; }
        if (L === -1) {
          // Below the deposition base: older history decides. If the older history is empty there
          // (e.g. a syncline below the erosion surface), the deposit fills it with its lowest layer,
          // so the true lower boundary is min(erosion surface, palaeo-surface).
          const saved = this.tCount;
          this.walk(i - 1, px, py, pz, damage, out);
          this.tCount = saved;
          if (out.materialId === AIR) this.finish(out, op.materialOf(0), 0, i, damage);
          return;
        }
      }
      if (this.hist) { this.hist[3 * i] = px; this.hist[3 * i + 1] = py; this.hist[3 * i + 2] = pz; }
    }
    this.finish(out, BASEMENT, -1, SOURCE_NONE, damage);
  }
}
