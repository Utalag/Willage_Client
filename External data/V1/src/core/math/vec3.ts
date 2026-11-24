/** Mutable 3D vector. Engine convention: Y up (gravity −Y), X and Z horizontal, metres. */
export interface Vec3 {
  x: number;
  y: number;
  z: number;
}
export const vec3 = (x = 0, y = 0, z = 0): Vec3 => ({ x, y, z });
export const dist3 = (a: Vec3, b: Vec3) => Math.hypot(a.x - b.x, a.y - b.y, a.z - b.z);
export const DEG = Math.PI / 180;
export const clamp = (v: number, lo: number, hi: number) => (v < lo ? lo : v > hi ? hi : v);
export const smoothstep = (e0: number, e1: number, x: number) => {
  const t = clamp((x - e0) / (e1 - e0), 0, 1);
  return t * t * (3 - 2 * t);
};
/** Determinant of a row-major 3x3 matrix. */
export function det3(m: Float64Array): number {
  return (
    m[0]! * (m[4]! * m[8]! - m[5]! * m[7]!) -
    m[1]! * (m[3]! * m[8]! - m[5]! * m[6]!) +
    m[2]! * (m[3]! * m[7]! - m[4]! * m[6]!)
  );
}
