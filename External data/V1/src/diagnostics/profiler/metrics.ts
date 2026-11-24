import type { WorldConfig } from "../../core/coordinates/world";
import type { GeoOperation } from "../../geology/events/types";

export interface TransformMetrics {
  maxInverseError: number;
  maxDisplacement: number;
  minJacobianDet: number;
  maxStrain: number;
  checkedPoints: number;
}

/**
 * For every deformation op and a deterministic 9³ lattice of points p:
 *   inverse error = |forward(inverse(p)) − p|, displacement = |forward(p) − p|,
 *   det J and strain = max |J − I| entry.
 */
export function measureTransforms(ops: GeoOperation[], world: WorldConfig, n = 9): TransformMetrics {
  const a = { x: 0, y: 0, z: 0 }, b = { x: 0, y: 0, z: 0 }, c = { x: 0, y: 0, z: 0 };
  const J = new Float64Array(9);
  let maxErr = 0, maxDisp = 0, minDet = Infinity, maxStrain = 0, count = 0;
  for (const op of ops) {
    if (op.kind !== "deformation") continue;
    for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) for (let k = 0; k < n; k++) {
      a.x = ((i + 0.37) / n) * world.sizeX; a.y = ((j + 0.61) / n) * world.sizeY; a.z = ((k + 0.13) / n) * world.sizeZ;
      op.inverse(a, b);
      op.forward(b, c);
      maxErr = Math.max(maxErr, Math.hypot(c.x - a.x, c.y - a.y, c.z - a.z));
      op.forward(a, c);
      maxDisp = Math.max(maxDisp, Math.hypot(c.x - a.x, c.y - a.y, c.z - a.z));
      const d = op.evaluateJacobian(a, J);
      minDet = Math.min(minDet, d);
      for (let e = 0; e < 9; e++) maxStrain = Math.max(maxStrain, Math.abs(J[e]! - (e % 4 === 0 ? 1 : 0)));
      count++;
    }
  }
  return { maxInverseError: maxErr, maxDisplacement: maxDisp, minJacobianDet: count ? minDet : 1, maxStrain, checkedPoints: count };
}
