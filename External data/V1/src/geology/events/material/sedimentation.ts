import { fbm2 } from "../../../core/deterministic/noise";
import { deriveSeed } from "../../../core/deterministic/hash";
import {
  LAYER_ABOVE, LAYER_BELOW,
  type MaterialOperation, type OpContext, type SedimentationEvent, type ValidationResult,
} from "../types";

/**
 * SedimentationOperation (algorithmVersion 1).
 * Interface heights h_0 (base) … h_n (top) are analytic functions of horizontal (x, z):
 *   h_0     = yStart + R·N_h0(x,z)
 *   w_i     = t_i·S · max(0.05, (1 + V·N_l,i(x,z)) · L(x,z))       S = (yEnd-yStart)/Σt
 *   h_i     = max(h_{i-1}, h_0 + Σ_{j≤i} w_j + R·N_h,i(x,z))
 * N_l: low-frequency fbm (2 oct), N_h: high-frequency fbm (3 oct), L: local thickening.
 */
export class SedimentationOperation implements MaterialOperation {
  readonly kind = "material" as const;
  readonly id: string;
  readonly mode: "erode" | "onlap";
  private readonly n: number;
  private readonly nominal: Float64Array;
  private readonly mats: Uint8Array;
  private readonly seeds: Int32Array;
  private readonly iface: Float64Array;
  private cx = NaN;
  private cz = NaN;

  constructor(private readonly ev: SedimentationEvent, private readonly ctx: OpContext) {
    const p = ev.params;
    this.id = ev.id;
    this.mode = p.mode;
    this.n = p.layers.length;
    this.nominal = new Float64Array(this.n);
    this.mats = new Uint8Array(this.n);
    const sum = p.layers.reduce((s, l) => s + Math.max(0, l.thickness), 0) || 1;
    const scale = (p.yEnd - p.yStart) / sum;
    p.layers.forEach((l, i) => {
      this.nominal[i] = Math.max(0, l.thickness) * scale;
      this.mats[i] = l.materialId;
    });
    this.seeds = new Int32Array(2 * this.n + 1);
    for (let i = 0; i < this.seeds.length; i++) this.seeds[i] = deriveSeed(ev.seed, i + 1) | 0;
    this.iface = new Float64Array(this.n + 1);
  }

  private local(x: number, z: number): number {
    let f = 1;
    for (const l of this.ev.params.local) {
      const r2 = (x - l.x) ** 2 + (z - l.z) ** 2;
      f += l.factor * Math.exp(-r2 / Math.max(1e-6, l.radius * l.radius));
    }
    return f;
  }

  /** Interface heights at horizontal (x,z). Memoised on the last column – pure, so caching cannot change results. */
  interfaces(x: number, z: number): Float64Array {
    if (x === this.cx && z === this.cz) return this.iface;
    const p = this.ev.params;
    const { periodX: px, periodZ: py } = this.ctx;
    const base = p.yStart + p.roughness * fbm2(x, z, this.seeds[0]!, p.roughnessFrequency, 3, px, py);
    this.iface[0] = base;
    const L = this.local(x, z);
    let cum = 0;
    let prev = base;
    for (let i = 0; i < this.n; i++) {
      const m = Math.max(0.05, (1 + p.thicknessVariation * fbm2(x, z, this.seeds[1 + i]!, p.thicknessFrequency, 2, px, py)) * L);
      cum += this.nominal[i]! * m;
      const rough = p.roughness * fbm2(x, z, this.seeds[1 + this.n + i]!, p.roughnessFrequency, 3, px, py);
      const h = Math.max(prev, base + cum + rough);
      this.iface[i + 1] = h;
      prev = h;
    }
    this.cx = x;
    this.cz = z;
    return this.iface;
  }

  classify(x: number, y: number, z: number): number {
    const f = this.interfaces(x, z);
    if (y < f[0]!) return LAYER_BELOW;
    for (let i = 0; i < this.n; i++) if (y < f[i + 1]!) return i;
    return LAYER_ABOVE;
  }
  materialOf(layer: number): number {
    return this.mats[layer] ?? 0;
  }
  validate(): ValidationResult {
    const p = this.ev.params;
    const errors: string[] = [];
    const warnings: string[] = [];
    if (this.n < 1) errors.push("Sedimentace nemá žádnou vrstvu.");
    if (p.yEnd <= p.yStart) errors.push("yEnd musí být větší než yStart.");
    if (p.thicknessVariation < 0 || p.thicknessVariation > 0.9) warnings.push("thicknessVariation mimo 0–0.9.");
    for (const l of p.local) if (l.factor <= -0.95) warnings.push("Lokální faktor ≤ -0.95 je omezen minimem 5 % mocnosti.");
    return { valid: errors.length === 0, errors, warnings };
  }
}
