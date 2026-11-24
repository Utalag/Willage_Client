import { DEG, type Vec3 } from "../../../core/math/vec3";
import type { DeformationOperation, FaultEvent, InverseResult, ValidationResult } from "../types";

/**
 * FaultOperation (algorithmVersion 1) – planar fault with rigid hanging-wall translation.
 *   Y up, strike θ measured in the XZ plane from +X towards +Z.
 *   strike  s = (cos θ, 0, sin θ)
 *   down-dip u = (sin θ cos δ, −sin δ, −cos θ cos δ)
 *   normal  n = (sin θ sin δ, cos δ, −cos θ sin δ)       (n·s = n·u = 0, n_y ≥ 0)
 *   side(p) = n·(p − p0);  hanging wall: side > 0
 *   slip    d = D_dip·u + D_strike·s   (lies in the plane → side is preserved)
 *   forward: p' = p + d if side(p) > 0, else p
 *   inverse: p  = p' − d if side(p') > 0, else p'   (exact, because side(p+d) = side(p))
 */
export class FaultOperation implements DeformationOperation {
  readonly kind = "deformation" as const;
  readonly id: string;
  readonly n: Vec3;
  readonly slip: Vec3;
  private readonly p0: Vec3;
  private readonly half: number;
  private readonly errors: string[] = [];

  constructor(ev: FaultEvent) {
    const p = ev.params;
    this.id = ev.id;
    const th = p.strikeDeg * DEG;
    const de = Math.min(90, Math.max(1, p.dipDeg)) * DEG;
    if (p.dipDeg < 1 || p.dipDeg > 90) this.errors.push("Sklon zlomu musí být v intervalu 1–90°.");
    const s = { x: Math.cos(th), y: 0, z: Math.sin(th) };
    const u = { x: Math.sin(th) * Math.cos(de), y: -Math.sin(de), z: -Math.cos(th) * Math.cos(de) };
    this.n = { x: Math.sin(th) * Math.sin(de), y: Math.cos(de), z: -Math.cos(th) * Math.sin(de) };
    let dd = 0, ds = 0;
    const D = p.displacement;
    switch (p.faultType) {
      case "normal": dd = D; break;
      case "reverse": dd = -D; break;
      case "strike-slip": ds = D; break;
      case "oblique": dd = D * Math.sin(p.rakeDeg * DEG); ds = D * Math.cos(p.rakeDeg * DEG); break;
    }
    this.slip = { x: dd * u.x + ds * s.x, y: dd * u.y + ds * s.y, z: dd * u.z + ds * s.z };
    this.p0 = { x: p.x, y: p.y, z: p.z };
    this.half = Math.max(0, p.damageWidth) / 2;
  }
  /** Signed distance to the fault plane. */
  side(x: number, y: number, z: number): number {
    return this.n.x * (x - this.p0.x) + this.n.y * (y - this.p0.y) + this.n.z * (z - this.p0.z);
  }
  forward(p: Vec3, out: Vec3): void {
    const hw = this.side(p.x, p.y, p.z) > 0;
    out.x = p.x + (hw ? this.slip.x : 0);
    out.y = p.y + (hw ? this.slip.y : 0);
    out.z = p.z + (hw ? this.slip.z : 0);
  }
  inverse(p: Vec3, out: Vec3): InverseResult {
    const hw = this.side(p.x, p.y, p.z) > 0;
    out.x = p.x - (hw ? this.slip.x : 0);
    out.y = p.y - (hw ? this.slip.y : 0);
    out.z = p.z - (hw ? this.slip.z : 0);
    return { iterations: 0, residual: 0, converged: true };
  }
  isInvertible() {
    return this.errors.length === 0;
  }
  validate(): ValidationResult {
    return { valid: this.errors.length === 0, errors: [...this.errors], warnings: [] };
  }
  /** Piecewise identity; undefined on the plane itself (discontinuity) – reported as identity. */
  evaluateJacobian(_p: Vec3, out: Float64Array): number {
    out.set([1, 0, 0, 0, 1, 0, 0, 0, 1]);
    return 1;
  }
  damageAt(x: number, y: number, z: number): boolean {
    return this.half > 0 && Math.abs(this.side(x, y, z)) < this.half;
  }
}
