/** World / test-volume definition. Coordinates are continuous metres, independent of voxel size. */
export interface WorldConfig {
  /** horizontal */ sizeX: number;
  /** vertical (up) */ sizeY: number;
  /** horizontal */ sizeZ: number;
  /** Periodic (toroidal) wrapping in X/Z – noise + folds periodic, faults not (see docs). */
  periodicX: boolean;
  periodicZ: boolean;
}
export const DEFAULT_WORLD: WorldConfig = { sizeX: 64, sizeY: 64, sizeZ: 64, periodicX: false, periodicZ: false };
export const RESOLUTIONS = [2, 1, 0.5, 0.25] as const;
export const WORLD_SIZES = [64, 128] as const;

export function gridDims(world: WorldConfig, res: number) {
  return {
    nx: Math.max(1, Math.round(world.sizeX / res)),
    ny: Math.max(1, Math.round(world.sizeY / res)),
    nz: Math.max(1, Math.round(world.sizeZ / res)),
  };
}
/** Cell-centre sampling: cell i covers [i*res, (i+1)*res), sampled at (i+0.5)*res. */
export const cellCenter = (i: number, res: number) => (i + 0.5) * res;
export const wrapCoord = (v: number, period: number) => {
  const m = v % period;
  return m < 0 ? m + period : m;
};
