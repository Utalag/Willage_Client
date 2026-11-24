/**
 * Culled-face voxel mesher: one merged mesh, a quad is emitted only between a visible cell
 * and a non-visible neighbour / volume boundary. Contains NO geological rules – it only
 * receives material IDs, a visibility LUT and a colour table.
 */
export interface MeshInput {
  nx: number; ny: number; nz: number; res: number;
  material: Uint8Array;
  /** value used for colouring (material id or event index) */
  colorKey: Uint8Array;
  /** 256-entry LUT: 1 = material visible */
  visible: Uint8Array;
  /** Optional presentation-only source/layer mask. No geological interpretation. */
  cellVisible?: Uint8Array;
  /** 256×3 RGB 0–1 */
  palette: Float32Array;
  /** -1 none, 0/1/2 axis; cells with centre > cutPos are hidden */
  cutAxis: number;
  cutPos: number;
  /** shrink faces to reveal individual cells */
  cellInset: number;
}
export interface MeshOutput { positions: Float32Array; normals: Float32Array; colors: Float32Array; indices: Uint32Array; faces: number; ms: number }

const FACES: { d: [number, number, number]; c: number[][]; shade: number }[] = [
  { d: [1, 0, 0], c: [[1, 0, 0], [1, 1, 0], [1, 1, 1], [1, 0, 1]], shade: 0.85 },
  { d: [-1, 0, 0], c: [[0, 0, 0], [0, 0, 1], [0, 1, 1], [0, 1, 0]], shade: 0.85 },
  { d: [0, 1, 0], c: [[0, 1, 0], [0, 1, 1], [1, 1, 1], [1, 1, 0]], shade: 0.72 },
  { d: [0, -1, 0], c: [[0, 0, 0], [1, 0, 0], [1, 0, 1], [0, 0, 1]], shade: 0.72 },
  { d: [0, 0, 1], c: [[0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1]], shade: 1 },
  { d: [0, 0, -1], c: [[0, 0, 0], [0, 1, 0], [1, 1, 0], [1, 0, 0]], shade: 0.55 },
];

export function buildCulledMesh(m: MeshInput): MeshOutput {
  const t0 = performance.now();
  const { nx, ny, nz, res } = m;
  const vis = (i: number, j: number, k: number) => {
    if (i < 0 || j < 0 || k < 0 || i >= nx || j >= ny || k >= nz) return false;
    if (m.cutAxis >= 0) {
      const c = ((m.cutAxis === 0 ? i : m.cutAxis === 1 ? j : k) + 0.5) * res;
      if (c > m.cutPos) return false;
    }
    const index = i + nx * (j + ny * k);
    const material = m.material[index];
    return material !== undefined && m.visible[material] === 1 && (!m.cellVisible || m.cellVisible[index] === 1);
  };
  // pass 1: count
  let faces = 0;
  for (let k = 0; k < nz; k++) for (let j = 0; j < ny; j++) for (let i = 0; i < nx; i++) {
    if (!vis(i, j, k)) continue;
    for (const f of FACES) if (!vis(i + f.d[0], j + f.d[1], k + f.d[2])) faces++;
  }
  const positions = new Float32Array(faces * 12), normals = new Float32Array(faces * 12), colors = new Float32Array(faces * 12);
  const indices = new Uint32Array(faces * 6);
  let q = 0;
  const ins = Math.min(0.45, Math.max(0, m.cellInset));
  for (let k = 0; k < nz; k++) for (let j = 0; j < ny; j++) for (let i = 0; i < nx; i++) {
    if (!vis(i, j, k)) continue;
    const key = m.colorKey[i + nx * (j + ny * k)]!;
    for (const f of FACES) {
      if (vis(i + f.d[0], j + f.d[1], k + f.d[2])) continue;
      for (let v = 0; v < 4; v++) {
        const c = f.c[v]!;
        const o = q * 12 + v * 3;
        for (let a = 0; a < 3; a++) {
          let t = c[a]!;
          if (f.d[a] === 0) t = t === 0 ? ins : 1 - ins; // shrink inside the face plane
          positions[o + a] = ([i, j, k][a]! + t) * res;
          normals[o + a] = f.d[a]!;
          colors[o + a] = m.palette[key * 3 + a]! * f.shade;
        }
      }
      const b = q * 4;
      indices.set([b, b + 1, b + 2, b, b + 2, b + 3], q * 6);
      q++;
    }
  }
  return { positions, normals, colors, indices, faces, ms: performance.now() - t0 };
}
