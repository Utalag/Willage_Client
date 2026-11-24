import { fbm2 } from "../../../core/deterministic/noise";
import { deriveSeed } from "../../../core/deterministic/hash";
import { DEG, smoothstep, type Vec3 } from "../../../core/math/vec3";
import type { DeformationOperation, FoldEvent, InverseResult, OpContext, ValidationResult } from "../types";

/** Max fold limb slope A·|k| (≈ 50°). Amplitude is clamped to it. */
export const FOLD_MAX_SLOPE = 1.2;
/** Max vertical strain |∂y'/∂y − 1| allowed by the depth gradient. */
export const FOLD_MAX_VSTRAIN = 0.8;
export const FOLD_INVERSE_TOL = 1e-9;
export const FOLD_INVERSE_MAX_ITER = 40;

/**
 * FoldingOperation (algorithmVersion 1) – vertical-shear fold (Y up, X/Z horizontal).
 *   k       = (kx, kz) = (2π/λ)(cos α, sin α)   (snapped to the period on periodic axes)
 *   F(x,z)  = A·W(x,z)·sin(kx x + kz z + φ + I·π·N(x,z))
 *   g(y)    = exp(γ (y − yRef))              (γ = 0 → g ≡ 1)
 *   forward: (x, y, z) → (x, y + F(x,z)·g(y), z)
 *   inverse: γ = 0 → y = y' − F(x,z)  (analytic, exact)
 *            γ ≠ 0 → Newton on y + F g(y) = y', tol 1e-9, ≤ 40 it, bisection fallback
 *   det J   = 1 + F·γ·g(y) > 0  ⇐  |A|·|γ|·g_max ≤ 0.8
 * Columns move only vertically → no lateral overlap in 3D; det J > 0 → no order reversal.
 */
export class FoldingOperation implements DeformationOperation {
  readonly kind = "deformation" as const;
  readonly id: string;
  readonly A: number;
  readonly gamma: number;
  readonly kx: number;
  readonly kz: number;
  private readonly phase: number;
  private readonly nSeed: number;
  private readonly warnings: string[] = [];
  private readonly errors: string[] = [];

  constructor(private readonly ev: FoldEvent, private readonly ctx: OpContext) {
    const p = ev.params;
    this.id = ev.id;
    if (!(p.wavelength > 0)) this.errors.push("Vlnová délka musí být > 0.");
    const k = (2 * Math.PI) / Math.max(1e-3, p.wavelength);
    let kx = k * Math.cos(p.azimuthDeg * DEG);
    let kz = k * Math.sin(p.azimuthDeg * DEG);
    const snap = (kk: number, P: number) => (P > 0 ? (Math.round((kk * P) / (2 * Math.PI)) * 2 * Math.PI) / P : kk);
    if (ctx.periodX > 0 || ctx.periodZ > 0) {
      const sx = snap(kx, ctx.periodX), sz = snap(kz, ctx.periodZ);
      if (sx !== kx || sz !== kz) this.warnings.push("Vlnový vektor přichycen k periodě světa (toroidní svět).");
      kx = sx; kz = sz;
    }
    this.kx = kx; this.kz = kz;
    const kn = Math.hypot(kx, kz);
    this.phase = p.phaseDeg * DEG;
    this.nSeed = deriveSeed(ev.seed, 7) | 0;
    let A = p.amplitude * p.intensity;
    const aMax = kn > 0 ? FOLD_MAX_SLOPE / kn : Infinity;
    if (Math.abs(A) > aMax) {
      this.warnings.push(`Amplituda ${A.toFixed(2)} m omezena na ${aMax.toFixed(2)} m (max. sklon A·k = ${FOLD_MAX_SLOPE}).`);
      A = Math.sign(A) * aMax;
    }
    this.A = A;
    let g = p.depthGradient;
    const span = Math.max(Math.abs(ctx.yMax - p.yRef), Math.abs(ctx.yMin - p.yRef));
    let guard = 0;
    while (g !== 0 && Math.abs(A * g) * Math.exp(Math.abs(g) * span) > FOLD_MAX_VSTRAIN && guard++ < 60) g *= 0.5;
    if (g !== p.depthGradient) this.warnings.push(`Hloubkový gradient omezen na ${g.toExponential(2)} (Jacobian > 0).`);
    this.gamma = g;
  }

  private window(x: number, z: number): number {
    const e = this.ev.params.extent;
    if (e.radius <= 0) return 1;
    let dx = Math.abs(x - e.cx), dz = Math.abs(z - e.cz);
    if (this.ctx.periodX > 0) dx = Math.min(dx % this.ctx.periodX, this.ctx.periodX - (dx % this.ctx.periodX));
    if (this.ctx.periodZ > 0) dz = Math.min(dz % this.ctx.periodZ, this.ctx.periodZ - (dz % this.ctx.periodZ));
    return 1 - smoothstep(e.radius, e.radius + Math.max(1e-6, e.falloff), Math.hypot(dx, dz));
  }
  /** F(x,z) – column displacement before depth scaling. */
  F(x: number, z: number): number {
    const p = this.ev.params;
    const irr = p.irregularity
      ? p.irregularity * Math.PI * fbm2(x, z, this.nSeed, p.irregularityFrequency, 2, this.ctx.periodX, this.ctx.periodZ)
      : 0;
    return this.A * this.window(x, z) * Math.sin(this.kx * x + this.kz * z + this.phase + irr);
  }
  private g(y: number) {
    return this.gamma === 0 ? 1 : Math.exp(this.gamma * (y - this.ev.params.yRef));
  }

  forward(p: Vec3, out: Vec3): void {
    const F = this.F(p.x, p.z);
    out.x = p.x;
    out.z = p.z;
    out.y = p.y + F * this.g(p.y);
  }

  inverse(p: Vec3, out: Vec3): InverseResult {
    out.x = p.x;
    out.z = p.z;
    const F = this.F(p.x, p.z);
    if (this.gamma === 0) {
      out.y = p.y - F;
      return { iterations: 0, residual: 0, converged: true };
    }
    const target = p.y;
    const yr = this.ev.params.yRef;
    const h = (y: number) => y + F * Math.exp(this.gamma * (y - yr)) - target;
    let y = target - F * this.g(target);
    let it = 0;
    let r = h(y);
    while (Math.abs(r) > FOLD_INVERSE_TOL && it < FOLD_INVERSE_MAX_ITER) {
      y -= r / (1 + F * this.gamma * Math.exp(this.gamma * (y - yr)));
      r = h(y);
      it++;
    }
    if (Math.abs(r) > FOLD_INVERSE_TOL || !Number.isFinite(y)) {
      let lo = target - 4 * Math.abs(F) - 64, hi = target + 4 * Math.abs(F) + 64;
      for (let b = 0; b < 200 && hi - lo > FOLD_INVERSE_TOL; b++) {
        const m = 0.5 * (lo + hi);
        if (h(m) > 0) hi = m; else lo = m;
        it++;
      }
      y = 0.5 * (lo + hi);
      r = h(y);
    }
    out.y = y;
    return { iterations: it, residual: Math.abs(r), converged: Math.abs(r) <= 1e-6 };
  }

  isInvertible(): boolean {
    return this.errors.length === 0;
  }
  validate(): ValidationResult {
    return { valid: this.errors.length === 0, errors: [...this.errors], warnings: [...this.warnings] };
  }
  /** Row-major J = ∂(x',y',z')/∂(x,y,z); ∂F/∂x, ∂F/∂z by central differences (h = 1e-4 m). */
  evaluateJacobian(p: Vec3, out: Float64Array): number {
    const h = 1e-4;
    const g = this.g(p.y);
    const dFx = (this.F(p.x + h, p.z) - this.F(p.x - h, p.z)) / (2 * h);
    const dFz = (this.F(p.x, p.z + h) - this.F(p.x, p.z - h)) / (2 * h);
    const F = this.F(p.x, p.z);
    const d = 1 + F * this.gamma * g;
    out.set([1, 0, 0, dFx * g, d, dFz * g, 0, 0, 1]);
    return d;
  }
}
